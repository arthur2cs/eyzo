#include "display_manager.h"

#include <Adafruit_GFX.h>
#include <Adafruit_ST7735.h>
#include <SPI.h>
#include <esp_heap_caps.h>

#include "config.h"
#include "protocol.h"

// Notes d'implémentation importantes (voir specs.md §6.3 et les modèles Dart
// correspondants) :
//
// - Les champs scalaires de l'en-tête/payload (SEQ, TOTAL, LEN, color_fg,
//   color_bg, text_len, pixel_len, frame_delay_ms) sont encodés en
//   little-endian par l'app (voir `_uint16le()` dans packet_builder.dart).
//   Le décodage LE est fait par ble_manager.cpp AVANT d'appeler ce module.
//
// - Le TABLEAU DE PIXELS `pixelsRgb565` est en revanche encodé en BIG-endian
//   par pixel (voir `PixelFrame.getPixel/setPixel` dans pixel_animation.dart :
//   `pixelsRgb565[i] << 8 | pixelsRgb565[i+1]`). C'est ce module qui décode
//   les pixels, dans upscaleNearestToCanvas() ci-dessous — ne pas confondre
//   les deux endianness.

namespace DisplayManager {
namespace {

// --- Écrans physiques (bus SPI partagé, CS/RST séparés, voir config.h) ---
Adafruit_ST7735 tftLeft(PIN_TFT_CS_LEFT, PIN_TFT_DC, PIN_TFT_RST_LEFT);
Adafruit_ST7735 tftRight(PIN_TFT_CS_RIGHT, PIN_TFT_DC, PIN_TFT_RST_RIGHT);

// Framebuffers en mémoire : on dessine dans le canvas puis on blitte d'un
// coup sur l'écran (évite le scintillement d'un dessin direct incrémental).
GFXcanvas16 canvasLeft(SCREEN_W, SCREEN_H);
GFXcanvas16 canvasRight(SCREEN_W, SCREEN_H);

enum class Mode : uint8_t { None, Text, StaticImage, Animation };

// Animation reçue et décodée en une seule commande (SET_ANIMATION, voir
// protocol.h) : toutes les frames arrivent concaténées dans un seul payload
// (mieux compressible côté app — zlib peut référencer les frames voisines,
// souvent très similaires d'une frame à l'autre, voir packet_builder.dart),
// stockées ici dans un unique buffer PSRAM contigu plutôt que N buffers
// séparés. Comme la mise à jour de ce player est désormais atomique (voir
// applyAnimationToChannel : reset() puis réaffectation de tous les champs
// se font en une seule fois, jamais visibles à moitié faits par la tâche
// loop() qui ne fait que lire), l'ancienne animation continue de tourner
// normalement pendant toute la durée de réception de la nouvelle — plus
// besoin d'écran noir/gel intermédiaire.
struct AnimationPlayer {
  uint8_t *combinedFrames = nullptr;  // frames concaténées, RGB565 big-endian
  uint8_t frameWidth = 0, frameHeight = 0;
  uint8_t frameCount = 0;
  uint8_t currentFrame = 0;
  uint16_t frameDelayMs = 120;
  uint32_t lastFrameMs = 0;

  // Vrai une fois combinedFrames entièrement rempli et prêt à être joué —
  // seul champ lu par updateAnimationChannel (tâche loop(), cœur 1) pendant
  // qu'applyAnimationToChannel (tâche BLE, cœur 0) répare ce player ; mis à
  // `false` en tout premier par reset() et à `true` en tout dernier, pour
  // qu'il ne soit jamais observé dans un état à moitié reconstruit.
  volatile bool ready = false;

  const uint8_t *frameAt(uint8_t index) const {
    if (!combinedFrames) return nullptr;
    const uint32_t frameBytes = (uint32_t)frameWidth * frameHeight * 2;
    return combinedFrames + (uint32_t)index * frameBytes;
  }

  void reset() {
    ready = false;
    if (combinedFrames) {
      heap_caps_free(combinedFrames);
      combinedFrames = nullptr;
    }
    frameWidth = 0;
    frameHeight = 0;
    frameCount = 0;
    currentFrame = 0;
    lastFrameMs = 0;
  }
};

struct ScreenChannel {
  Mode mode = Mode::None;

  // --- texte défilant/statique/clignotant : bitmap RGB565 déjà rendu côté
  // app (voir protocol.h), le firmware ne fait plus de rendu de police ---
  uint8_t *textBitmap = nullptr;  // big-endian/pixel, largeur textBitmapWidth x SCREEN_H
  uint16_t textBitmapWidth = 0;
  uint16_t colorBg = 0x0000;
  uint8_t direction = EyzoProtocol::DIR_STATIC;
  uint32_t stepIntervalMs = 60;
  int32_t scrollX = 0;
  uint32_t lastTickMs = 0;
  bool blinkOn = true;
  uint32_t lastBlinkMs = 0;
  uint32_t blinkHalfPeriodMs = 500;
  bool needsRedraw = true;

  // --- image statique ---
  uint8_t imgWidth = 0, imgHeight = 0;
  uint8_t *staticPixels = nullptr;  // copie du payload (RGB565 big-endian/pixel)

  // --- animation ---
  AnimationPlayer anim;

  void freeStatic() {
    if (staticPixels) {
      free(staticPixels);
      staticPixels = nullptr;
    }
  }

  void freeTextBitmap() {
    if (textBitmap) {
      heap_caps_free(textBitmap);
      textBitmap = nullptr;
    }
  }
};

ScreenChannel s_left;
ScreenChannel s_right;

// Mode séquentiel (SET_TEXT, SCREEN_SEQUENTIAL uniquement) : les 2 écrans
// forment une bande virtuelle continue de largeur 2*SCREEN_W (voir
// specs.md §6.3). État dédié, exclusif des channels ci-dessus tant qu'actif.
struct SequentialState {
  bool active = false;
  uint8_t *textBitmap = nullptr;
  uint16_t textBitmapWidth = 0;
  uint16_t colorBg = 0x0000;
  uint8_t direction = EyzoProtocol::DIR_LEFTWARD;
  uint32_t stepIntervalMs = 60;
  int32_t virtualX = 0;
  uint32_t lastTickMs = 0;
  bool needsRedraw = true;

  void freeTextBitmap() {
    if (textBitmap) {
      heap_caps_free(textBitmap);
      textBitmap = nullptr;
    }
  }
};

SequentialState s_seq;

// --- Helpers ---

// Recalibrées en 2 segments (voir specs.md §6.3) : 1..5 reproduit la plage
// complète de l'ancien réglage (l'ancienne vitesse 10 devient la nouvelle
// vitesse 5), puis 5..10 continue d'accélérer au-delà, plus doucement.
// Miroir exact requis côté app dans glasses_timing.dart (scrollStepIntervalMs
// / blinkHalfPeriodMs) — voir la note en tête de ce fichier.
uint32_t stepIntervalFromSpeed(uint8_t speed) {
  uint8_t s = speed < 1 ? 1 : (speed > 10 ? 10 : speed);
  // vitesse 1 -> 60ms/px, vitesse 5 -> 10ms/px, vitesse 10 -> 5ms/px.
  if (s <= 5) return map(s, 1, 5, 60, 10);
  return map(s, 5, 10, 10, 5);
}

// Demi-période (allumé OU éteint) du mode clignotant, voir DIR_BLINK dans
// updateTextChannel(). Plancher volontairement plus prudent que le
// défilement (voir stepIntervalFromSpeed) pour rester dans un rythme de
// clignotement franc plutôt qu'un scintillement gênant/potentiellement
// inconfortable pour un écran porté près des yeux.
uint32_t blinkHalfPeriodFromSpeed(uint8_t speed) {
  uint8_t s = speed < 1 ? 1 : (speed > 10 ? 10 : speed);
  // vitesse 1 -> 600ms, vitesse 5 -> 200ms, vitesse 10 -> 150ms.
  if (s <= 5) return map(s, 1, 5, 600, 200);
  return map(s, 5, 10, 200, 150);
}

void blit(Adafruit_ST7735 &tft, GFXcanvas16 &canvas) {
  tft.drawRGBBitmap(0, 0, canvas.getBuffer(), SCREEN_W, SCREEN_H);
}

// Nearest-neighbor upscale depuis la résolution de travail (srcW x srcH,
// pixels RGB565 big-endian, voir note en tête de fichier) vers SCREEN_W x
// SCREEN_H, directement dans le canvas cible.
void upscaleNearestToCanvas(GFXcanvas16 &canvas, const uint8_t *pixelsBE, uint8_t srcW,
                             uint8_t srcH) {
  if (srcW == 0 || srcH == 0 || pixelsBE == nullptr) return;
  for (uint16_t y = 0; y < SCREEN_H; y++) {
    uint8_t sy = (uint16_t)((uint32_t)y * srcH / SCREEN_H);
    for (uint16_t x = 0; x < SCREEN_W; x++) {
      uint8_t sx = (uint16_t)((uint32_t)x * srcW / SCREEN_W);
      uint32_t si = ((uint32_t)sy * srcW + sx) * 2;
      uint16_t color = ((uint16_t)pixelsBE[si] << 8) | pixelsBE[si + 1];
      canvas.drawPixel(x, y, color);
    }
  }
}

// Copie la fenêtre [0, SCREEN_W) d'un bitmap RGB565 big-endian (largeur
// srcW, hauteur SCREEN_H, voir note en tête de fichier) dans canvas, le
// bitmap étant positionné à l'abscisse horizontale originX (peut être
// négatif ou dépasser SCREEN_W : la partie hors cadre est ignorée). Utilisé
// pour le texte (voir protocol.h : bitmap déjà rendu côté app, le firmware
// ne fait plus que le déplacer/afficher).
void blitBitmapWindow(GFXcanvas16 &canvas, const uint8_t *bitmapBE, uint16_t srcW,
                       int32_t originX) {
  if (bitmapBE == nullptr || srcW == 0) return;
  int32_t xStart = originX < 0 ? 0 : originX;
  int32_t xEnd = originX + (int32_t)srcW;
  if (xEnd > SCREEN_W) xEnd = SCREEN_W;
  if (xStart >= xEnd) return;
  for (uint16_t y = 0; y < SCREEN_H; y++) {
    for (int32_t x = xStart; x < xEnd; x++) {
      uint32_t sx = (uint32_t)(x - originX);
      uint32_t si = ((uint32_t)y * srcW + sx) * 2;
      uint16_t color = ((uint16_t)bitmapBE[si] << 8) | bitmapBE[si + 1];
      canvas.drawPixel(x, y, color);
    }
  }
}

// --- Rendu texte (channel indépendant gauche/droit) ---

void updateTextChannel(ScreenChannel &ch, Adafruit_ST7735 &tft, GFXcanvas16 &canvas) {
  uint32_t now = millis();

  if (ch.direction == EyzoProtocol::DIR_STATIC) {
    if (ch.needsRedraw) {
      // Bitmap statique = déjà plein écran (SCREEN_W x SCREEN_H), fond inclus.
      canvas.fillScreen(ch.colorBg);
      blitBitmapWindow(canvas, ch.textBitmap, ch.textBitmapWidth, 0);
      blit(tft, canvas);
      ch.needsRedraw = false;
    }
    return;
  }

  if (ch.direction == EyzoProtocol::DIR_BLINK) {
    if (ch.needsRedraw) {
      ch.blinkOn = true;
      ch.lastBlinkMs = now;
      ch.needsRedraw = false;
    } else if (now - ch.lastBlinkMs < ch.blinkHalfPeriodMs) {
      return;
    } else {
      ch.lastBlinkMs = now;
      ch.blinkOn = !ch.blinkOn;
    }
    canvas.fillScreen(ch.colorBg);
    if (ch.blinkOn) blitBitmapWindow(canvas, ch.textBitmap, ch.textBitmapWidth, 0);
    blit(tft, canvas);
    return;
  }

  // Défilement (0 = gauche, 1 = droite) — sens "intuitif" pour un écran seul :
  // direction=0 entre par la droite et sort par la gauche, direction=1 l'inverse.
  // Le bitmap ne contient que le texte (largeur ch.textBitmapWidth) : le
  // fond est repeint à chaque frame avant d'y positionner la fenêtre.
  if (ch.needsRedraw) {
    ch.scrollX =
        (ch.direction == EyzoProtocol::DIR_LEFTWARD) ? SCREEN_W : -(int32_t)ch.textBitmapWidth;
    ch.lastTickMs = now;
    ch.needsRedraw = false;
    canvas.fillScreen(ch.colorBg);
    blitBitmapWindow(canvas, ch.textBitmap, ch.textBitmapWidth, ch.scrollX);
    blit(tft, canvas);
    return;
  }
  if (now - ch.lastTickMs >= ch.stepIntervalMs) {
    ch.lastTickMs = now;
    if (ch.direction == EyzoProtocol::DIR_LEFTWARD) {
      ch.scrollX--;
      if (ch.scrollX < -(int32_t)ch.textBitmapWidth) ch.scrollX = SCREEN_W;
    } else {
      ch.scrollX++;
      if (ch.scrollX > SCREEN_W) ch.scrollX = -(int32_t)ch.textBitmapWidth;
    }
    canvas.fillScreen(ch.colorBg);
    blitBitmapWindow(canvas, ch.textBitmap, ch.textBitmapWidth, ch.scrollX);
    blit(tft, canvas);
  }
}

void updateAnimationChannel(ScreenChannel &ch, Adafruit_ST7735 &tft, GFXcanvas16 &canvas) {
  AnimationPlayer &a = ch.anim;
  // a.ready ne devient jamais vrai avant que frameCount/combinedFrames ne
  // soient valides (voir applyAnimationToChannel) : ce garde-fou suffit à
  // la fois à ne rien afficher tant qu'une animation n'est pas reçue en
  // entier et à éviter tout "% a.frameCount" avec frameCount == 0 (Guru
  // Meditation IntegerDivideByZero, déjà rencontré avec l'ancien design
  // frame-par-frame). L'ancienne animation reste affichée et continue de
  // tourner normalement pendant ce temps : rien ici ne touche `a` avant que
  // la nouvelle soit prête (voir commentaire sur AnimationPlayer).
  if (!a.ready || a.frameCount == 0) return;
  uint32_t now = millis();
  if (now - a.lastFrameMs < a.frameDelayMs) return;
  a.lastFrameMs = now;
  const uint8_t *frame = a.frameAt(a.currentFrame);
  if (frame) {
    upscaleNearestToCanvas(canvas, frame, a.frameWidth, a.frameHeight);
    blit(tft, canvas);
  }
  a.currentFrame = (a.currentFrame + 1) % a.frameCount;
}

void updateChannel(ScreenChannel &ch, Adafruit_ST7735 &tft, GFXcanvas16 &canvas) {
  switch (ch.mode) {
    case Mode::Text:
      updateTextChannel(ch, tft, canvas);
      break;
    case Mode::StaticImage:
      if (ch.needsRedraw) {
        upscaleNearestToCanvas(canvas, ch.staticPixels, ch.imgWidth, ch.imgHeight);
        blit(tft, canvas);
        ch.needsRedraw = false;
      }
      break;
    case Mode::Animation:
      updateAnimationChannel(ch, tft, canvas);
      break;
    case Mode::None:
    default:
      break;
  }
}

// --- Rendu séquentiel (2 écrans = 1 bande virtuelle, texte uniquement) ---

void redrawSequential() {
  canvasLeft.fillScreen(s_seq.colorBg);
  canvasRight.fillScreen(s_seq.colorBg);

  // canvasRight utilise virtualX tel quel, canvasLeft utilise virtualX -
  // SCREEN_W : l'écran Gauche affiche donc toujours la portion de bande
  // SCREEN_W "en avance" sur l'écran Droit, ce qui fait de lui le premier à
  // entrer et à sortir du texte (voir updateSequential()).
  blitBitmapWindow(canvasLeft, s_seq.textBitmap, s_seq.textBitmapWidth, s_seq.virtualX - SCREEN_W);
  blitBitmapWindow(canvasRight, s_seq.textBitmap, s_seq.textBitmapWidth, s_seq.virtualX);

  blit(tftLeft, canvasLeft);
  blit(tftRight, canvasRight);
}

void updateSequential() {
  uint32_t now = millis();
  if (s_seq.needsRedraw) {
    // Convention specs.md §6.3, alignée sur celle du défilement individuel
    // (updateTextChannel : leftward décroît, rightward croît) :
    //   direction=0 : le texte ENTRE par l'écran Gauche et SORT par le Droit
    //                 -> la position virtuelle décroît.
    //   direction=1 : le texte ENTRE par l'écran Droit et SORT par le Gauche
    //                 -> la position virtuelle croît.
    s_seq.virtualX = (s_seq.direction == EyzoProtocol::DIR_LEFTWARD)
                         ? (2 * SCREEN_W)
                         : -(int32_t)s_seq.textBitmapWidth;
    s_seq.lastTickMs = now;
    s_seq.needsRedraw = false;
    redrawSequential();
    return;
  }
  if (now - s_seq.lastTickMs >= s_seq.stepIntervalMs) {
    s_seq.lastTickMs = now;
    if (s_seq.direction == EyzoProtocol::DIR_LEFTWARD) {
      s_seq.virtualX--;
      if (s_seq.virtualX < -(int32_t)s_seq.textBitmapWidth) s_seq.virtualX = 2 * SCREEN_W;
    } else {
      s_seq.virtualX++;
      if (s_seq.virtualX > 2 * SCREEN_W) s_seq.virtualX = -(int32_t)s_seq.textBitmapWidth;
    }
    redrawSequential();
  }
}

// --- Messages d'état (boot / appairage / connexion), voir specs.md §4.1 ---

void drawStatusMessage(const char *msg, uint16_t color) {
  s_left.mode = Mode::None;
  s_right.mode = Mode::None;
  s_seq.active = false;

  canvasLeft.fillScreen(ST77XX_BLACK);
  canvasRight.fillScreen(ST77XX_BLACK);
  canvasLeft.setTextSize(1);
  canvasLeft.setTextColor(color);
  canvasRight.setTextSize(1);
  canvasRight.setTextColor(color);

  int16_t x1, y1;
  uint16_t w, h;
  canvasLeft.getTextBounds(msg, 0, 0, &x1, &y1, &w, &h);
  int32_t x = (SCREEN_W - (int32_t)w) / 2;
  int32_t y = (SCREEN_H - (int32_t)h) / 2 - y1;

  canvasLeft.setCursor(x, y);
  canvasLeft.print(msg);
  canvasRight.setCursor(x, y);
  canvasRight.print(msg);

  blit(tftLeft, canvasLeft);
  blit(tftRight, canvasRight);
}

void applyTextBitmapToChannel(ScreenChannel &ch, uint8_t direction, uint16_t colorBg,
                               uint32_t stepMs, uint32_t blinkHalfPeriodMs, uint16_t bitmapWidth,
                               const uint8_t *pixels, uint32_t pixelLen) {
  ch.anim.reset();
  ch.freeStatic();
  ch.freeTextBitmap();
  ch.textBitmap = (uint8_t *)heap_caps_malloc(pixelLen, MALLOC_CAP_SPIRAM);
  if (!ch.textBitmap) ch.textBitmap = (uint8_t *)malloc(pixelLen);  // repli SRAM
  if (!ch.textBitmap) {
    Serial.println("[Display] echec allocation bitmap texte");
    ch.mode = Mode::None;
    return;
  }
  memcpy(ch.textBitmap, pixels, pixelLen);
  ch.mode = Mode::Text;
  ch.direction = direction;
  ch.colorBg = colorBg;
  ch.stepIntervalMs = stepMs;
  ch.blinkHalfPeriodMs = blinkHalfPeriodMs;
  ch.textBitmapWidth = bitmapWidth;
  ch.needsRedraw = true;
  ch.blinkOn = true;
}

void applyStaticImageToChannel(ScreenChannel &ch, uint8_t width, uint8_t height,
                                const uint8_t *pixels, uint16_t pixelLen) {
  ch.anim.reset();
  ch.freeStatic();
  ch.freeTextBitmap();
  ch.staticPixels = (uint8_t *)malloc(pixelLen);
  if (!ch.staticPixels) {
    Serial.println("[Display] echec allocation image statique");
    ch.mode = Mode::None;
    return;
  }
  memcpy(ch.staticPixels, pixels, pixelLen);
  ch.imgWidth = width;
  ch.imgHeight = height;
  ch.mode = Mode::StaticImage;
  ch.needsRedraw = true;
}

void applyAnimationToChannel(ScreenChannel &ch, uint8_t width, uint8_t height,
                              uint8_t frameCount, uint16_t frameDelayMs, const uint8_t *pixels,
                              uint32_t pixelLen) {
  // Toute l'animation arrive déjà réassemblée et décompressée d'un bloc
  // (voir ble_manager.cpp) : on ne touche `ch.anim`/`ch.mode` qu'une fois
  // ici, jamais entre-temps pendant la réception BLE — l'ancienne animation
  // continue donc de tourner normalement sur cette voie jusqu'à cet instant
  // précis (voir commentaire sur AnimationPlayer).
  ch.anim.reset();  // ready=false en premier : plus rien affiché tant que le nouveau buffer n'est pas prêt
  ch.freeStatic();
  ch.freeTextBitmap();
  ch.mode = Mode::Animation;

  // Frames stockées en PSRAM à leur résolution de travail brute (pas
  // d'upscale ici) : l'upscale nearest-neighbor est refait à chaque
  // affichage dans upscaleNearestToCanvas(), ce qui coûte peu de CPU et
  // divise par ~4-16 la mémoire nécessaire pour stocker une animation
  // multi-frames (voir specs.md §6.3 / §9 sur le coût mémoire/BLE).
  uint8_t *buf = (uint8_t *)heap_caps_malloc(pixelLen, MALLOC_CAP_SPIRAM);
  if (!buf) buf = (uint8_t *)malloc(pixelLen);  // repli SRAM si PSRAM indisponible
  if (!buf) {
    Serial.println("[Display] echec allocation animation (memoire insuffisante)");
    ch.mode = Mode::None;
    return;
  }
  memcpy(buf, pixels, pixelLen);

  ch.anim.combinedFrames = buf;
  ch.anim.frameWidth = width;
  ch.anim.frameHeight = height;
  ch.anim.frameCount = frameCount;
  ch.anim.frameDelayMs = frameDelayMs == 0 ? 1 : frameDelayMs;
  ch.anim.currentFrame = 0;
  ch.anim.lastFrameMs = millis();
  ch.anim.ready = true;  // en dernier : voir commentaire sur AnimationPlayer::ready
}

}  // namespace

void begin() {
  // MISO non câblé/inutilisé : les écrans sont pilotés en écriture seule.
  SPI.begin(PIN_TFT_SCK, -1, PIN_TFT_MOSI, -1);

  tftLeft.initR(INITR_BLACKTAB);
  tftRight.initR(INITR_BLACKTAB);
  // Orientation paysage (voir specs.md §2). Si l'image apparaît tournée/
  // inversée une fois monté dans les lunettes, essayer setRotation(3).
  tftLeft.setRotation(1);
  tftRight.setRotation(1);

  canvasLeft.fillScreen(ST77XX_BLACK);
  canvasRight.fillScreen(ST77XX_BLACK);
  blit(tftLeft, canvasLeft);
  blit(tftRight, canvasRight);
}

void loop() {
  if (s_seq.active) {
    updateSequential();
  } else {
    updateChannel(s_left, tftLeft, canvasLeft);
    updateChannel(s_right, tftRight, canvasRight);
  }
}

void showBoot() { drawStatusMessage("EYZO", ST77XX_WHITE); }
void showDisconnected() { drawStatusMessage("Deconnecte", ST77XX_WHITE); }
void showConnected() { drawStatusMessage("Connecte", ST77XX_GREEN); }

void showPairing(uint32_t secondsLeft) {
  char buf[24];
  snprintf(buf, sizeof(buf), "Appairage %lus", (unsigned long)secondsLeft);
  drawStatusMessage(buf, ST77XX_YELLOW);
}

void clearScreen(uint8_t screenByte) {
  if (screenByte == EyzoProtocol::SCREEN_SEQUENTIAL) {
    s_seq.active = false;
    s_seq.freeTextBitmap();
  }

  if (screenByte == EyzoProtocol::SCREEN_LEFT || screenByte == EyzoProtocol::SCREEN_SIMULTANEOUS ||
      screenByte == EyzoProtocol::SCREEN_SEQUENTIAL) {
    s_left.mode = Mode::None;
    s_left.anim.reset();
    s_left.freeStatic();
    s_left.freeTextBitmap();
    canvasLeft.fillScreen(ST77XX_BLACK);
    blit(tftLeft, canvasLeft);
  }
  if (screenByte == EyzoProtocol::SCREEN_RIGHT || screenByte == EyzoProtocol::SCREEN_SIMULTANEOUS ||
      screenByte == EyzoProtocol::SCREEN_SEQUENTIAL) {
    s_right.mode = Mode::None;
    s_right.anim.reset();
    s_right.freeStatic();
    s_right.freeTextBitmap();
    canvasRight.fillScreen(ST77XX_BLACK);
    blit(tftRight, canvasRight);
  }
}

void setText(uint8_t screenByte, uint8_t direction, uint8_t speed, uint16_t colorBg,
             uint16_t bitmapWidth, const uint8_t *pixelsRgb565, uint32_t pixelLen) {
  uint32_t stepMs = stepIntervalFromSpeed(speed);
  uint32_t blinkMs = blinkHalfPeriodFromSpeed(speed);

  if (screenByte == EyzoProtocol::SCREEN_SEQUENTIAL) {
    if (direction == EyzoProtocol::DIR_STATIC || direction == EyzoProtocol::DIR_BLINK) {
      // specs.md §6.3 : sans effet particulier en statique/clignotant,
      // équivalent à Simultané dans ce cas.
      setText(EyzoProtocol::SCREEN_SIMULTANEOUS, direction, speed, colorBg, bitmapWidth,
              pixelsRgb565, pixelLen);
      return;
    }
    s_left.mode = Mode::None;
    s_left.anim.reset();
    s_left.freeStatic();
    s_left.freeTextBitmap();
    s_right.mode = Mode::None;
    s_right.anim.reset();
    s_right.freeStatic();
    s_right.freeTextBitmap();

    s_seq.freeTextBitmap();
    s_seq.textBitmap = (uint8_t *)heap_caps_malloc(pixelLen, MALLOC_CAP_SPIRAM);
    if (!s_seq.textBitmap) s_seq.textBitmap = (uint8_t *)malloc(pixelLen);  // repli SRAM
    if (!s_seq.textBitmap) {
      Serial.println("[Display] echec allocation bitmap texte (sequentiel)");
      s_seq.active = false;
      return;
    }
    memcpy(s_seq.textBitmap, pixelsRgb565, pixelLen);
    s_seq.active = true;
    s_seq.textBitmapWidth = bitmapWidth;
    s_seq.colorBg = colorBg;
    s_seq.direction = direction;
    s_seq.stepIntervalMs = stepMs;
    s_seq.needsRedraw = true;
    return;
  }

  s_seq.active = false;
  s_seq.freeTextBitmap();
  if (screenByte == EyzoProtocol::SCREEN_LEFT || screenByte == EyzoProtocol::SCREEN_SIMULTANEOUS) {
    applyTextBitmapToChannel(s_left, direction, colorBg, stepMs, blinkMs, bitmapWidth,
                              pixelsRgb565, pixelLen);
  }
  if (screenByte == EyzoProtocol::SCREEN_RIGHT || screenByte == EyzoProtocol::SCREEN_SIMULTANEOUS) {
    applyTextBitmapToChannel(s_right, direction, colorBg, stepMs, blinkMs, bitmapWidth,
                              pixelsRgb565, pixelLen);
  }
}

void setStaticImage(uint8_t screenByte, uint8_t width, uint8_t height,
                     const uint8_t *pixelsRgb565, uint16_t pixelLen) {
  s_seq.active = false;
  s_seq.freeTextBitmap();
  // Non exposé côté app pour cette commande (specs.md §6.3) : traité comme
  // Simultané par sécurité plutôt que de laisser un comportement non défini.
  if (screenByte == EyzoProtocol::SCREEN_SEQUENTIAL) screenByte = EyzoProtocol::SCREEN_SIMULTANEOUS;

  if (screenByte == EyzoProtocol::SCREEN_LEFT || screenByte == EyzoProtocol::SCREEN_SIMULTANEOUS)
    applyStaticImageToChannel(s_left, width, height, pixelsRgb565, pixelLen);
  if (screenByte == EyzoProtocol::SCREEN_RIGHT || screenByte == EyzoProtocol::SCREEN_SIMULTANEOUS)
    applyStaticImageToChannel(s_right, width, height, pixelsRgb565, pixelLen);
}

void setAnimation(uint8_t screenByte, uint8_t width, uint8_t height, uint8_t frameCount,
                   uint16_t frameDelayMs, const uint8_t *pixelsRgb565, uint32_t pixelLen) {
  s_seq.active = false;
  s_seq.freeTextBitmap();
  // Non exposé côté app pour cette commande (specs.md §6.3) : traité comme
  // Simultané par sécurité plutôt que de laisser un comportement non défini.
  if (screenByte == EyzoProtocol::SCREEN_SEQUENTIAL) screenByte = EyzoProtocol::SCREEN_SIMULTANEOUS;

  if (screenByte == EyzoProtocol::SCREEN_LEFT || screenByte == EyzoProtocol::SCREEN_SIMULTANEOUS)
    applyAnimationToChannel(s_left, width, height, frameCount, frameDelayMs, pixelsRgb565,
                             pixelLen);
  if (screenByte == EyzoProtocol::SCREEN_RIGHT || screenByte == EyzoProtocol::SCREEN_SIMULTANEOUS)
    applyAnimationToChannel(s_right, width, height, frameCount, frameDelayMs, pixelsRgb565,
                             pixelLen);
}

}  // namespace DisplayManager
