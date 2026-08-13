#pragma once
#include <Arduino.h>

// Pilotage des 2 écrans ST7735S (voir specs.md §2, §4.2-§4.4, §6.3).
// Reçoit les commandes déjà décodées par ble_manager (payload d'un
// SET_TEXT/SET_STATIC_IMAGE/SET_ANIMATION complet, réassemblé) et gère
// le rendu (statique, défilement, clignotant, animation multi-frames,
// mode séquentiel 2 écrans en bande continue).
namespace DisplayManager {

void begin();

// A appeler à chaque tour de loop() principal : fait avancer les animations
// et défilements en cours (non bloquant, cadencé par millis()).
void loop();

// Écrans d'état (bouton/BLE), affichés directement sur les 2 dalles.
void showBoot();
void showPairing(uint32_t secondsLeft);
void showDisconnected();
void showConnected();

// screenByte : voir EyzoProtocol::SCREEN_* (0x00 gauche, 0x01 droit,
// 0x02 simultané, 0x03 séquentiel — texte uniquement).
void clearScreen(uint8_t screenByte);

// bitmapWidth/pixelsRgb565/pixelLen : bitmap RGB565 déjà rendu côté app (voir
// protocol.h) — hauteur toujours SCREEN_H, validée en amont par ble_manager.
// gapNativePx : écart inter-écran en pixels natifs, significatif seulement
// pour screenByte=SCREEN_SEQUENTIAL (voir protocol.h et
// sequential_text_preview.dart côté app).
void setText(uint8_t screenByte, uint8_t direction, uint8_t speed, uint16_t colorBg,
             uint16_t bitmapWidth, uint16_t gapNativePx, const uint8_t *pixelsRgb565,
             uint32_t pixelLen);

void setStaticImage(uint8_t screenByte, uint8_t width, uint8_t height,
                     const uint8_t *pixelsRgb565, uint16_t pixelLen);

// Toute l'animation en une fois (voir protocol.h : CMD_SET_ANIMATION) :
// pixelsRgb565 contient les frameCount frames concaténées (chacune
// width*height*2 octets), déjà décompressées si besoin par ble_manager.
void setAnimation(uint8_t screenByte, uint8_t width, uint8_t height, uint8_t frameCount,
                   uint16_t frameDelayMs, const uint8_t *pixelsRgb565, uint32_t pixelLen);

}  // namespace DisplayManager
