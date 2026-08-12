#include "ble_manager.h"

#include <NimBLEDevice.h>
#include <Preferences.h>
#include <esp_heap_caps.h>
#include <string.h>
#include <zlib_turbo.h>

#include "config.h"
#include "display_manager.h"
#include "protocol.h"

namespace BleManager {
namespace {

NimBLEServer *pServer = nullptr;
NimBLECharacteristic *pCommandChar = nullptr;
NimBLECharacteristic *pEventChar = nullptr;

Preferences prefs;
const char *PREFS_NAMESPACE = "eyzo";
const char *PREFS_KEY_BONDED_ADDR = "bondedAddr";

// Adresse MAC (en minuscules, format "aa:bb:cc:dd:ee:ff") du téléphone
// mémorisé — persistée en NVS. Vide si aucune connexion n'a jamais eu lieu
// (voir "gestion de la première connexion", specs.md §4.1).
String s_bondedAddress;

bool s_connected = false;
uint16_t s_currentConnHandle = 0xFFFF;

bool s_pairingMode = false;
uint32_t s_pairingUntilMs = 0;

// --- Réassemblage des trames chunkées (voir protocol.h / specs.md §6.2) ---
// Un seul transfert à la fois : l'app attend chaque écriture BLE avant
// d'envoyer le chunk suivant (voir _writeChunks dans eyzo_ble_service.dart),
// pas besoin de gérer plusieurs flux en parallèle.
// Alloué en PSRAM (voir begin()) : MAX_PAYLOAD_SIZE (~250 Ko, voir config.h)
// ne tiendrait pas dans la SRAM interne aux côtés du reste (pile NimBLE,
// frames d'animation déjà en PSRAM, etc.).
uint8_t *s_reassemblyBuffer = nullptr;
uint32_t s_bufLen = 0;
uint16_t s_expectedSeq = 0;
uint16_t s_expectedTotal = 0;
uint8_t s_currentCmd = 0;
uint8_t s_currentScreen = 0;
bool s_reassemblyActive = false;

// Buffer de sortie pour la décompression zlib des payloads pixels (voir
// protocol.h : PIXEL_FORMAT_ZLIB, resolvePixels() ci-dessous). Alloué en
// PSRAM à la taille max d'un payload (comme s_reassemblyBuffer) : un texte
// défilant décompressé peut aller jusqu'à MAX_PAYLOAD_SIZE.
uint8_t *s_decompressBuffer = nullptr;

// Instance réutilisée à chaque décompression (voir decompressPixels()) :
// son état interne (~6,7 Ko, tables de Huffman incluses, voir zlib_turbo.h
// `zt_state`) DOIT rester statique et non sur la pile. Placée en variable
// locale, elle déborderait la pile de la tâche hôte NimBLE (qui exécute
// onWrite() -> dispatch() -> ... -> decompressPixels(), avec un budget de
// pile bien plus restreint que ça) et plantait l'ESP32 en cours de
// réception — vu côté téléphone comme une déconnexion BLE brutale
// (Android : "133 GATT_ERROR"). Un seul transfert à la fois (voir plus
// haut), donc pas de risque de réentrance sur cette instance partagée.
zlib_turbo s_zlibTurbo;

// --- Helpers bas niveau ---

uint16_t readU16LE(const uint8_t *p) { return (uint16_t)p[0] | ((uint16_t)p[1] << 8); }

uint8_t xorChecksum(const uint8_t *data, size_t len) {
  uint8_t chk = 0;
  for (size_t i = 0; i < len; i++) chk ^= data[i];
  return chk;
}

void sendEvent(uint8_t evt, const uint8_t *payload, uint8_t len) {
  if (!pEventChar || !s_connected) return;
  uint8_t frame[3 + 16];  // SOF+EVT+LEN + payload (largement assez pour nos events) + CHK
  if (len > 16) len = 16;
  uint8_t idx = 0;
  frame[idx++] = EyzoProtocol::START_OF_FRAME;
  frame[idx++] = evt;
  frame[idx++] = len;
  for (uint8_t i = 0; i < len; i++) frame[idx++] = payload[i];
  frame[idx] = xorChecksum(frame, idx);
  idx++;
  pEventChar->notify(frame, idx);
}

void sendAck(uint8_t cmd, uint8_t screen) {
  uint8_t payload[2] = {cmd, screen};
  sendEvent(EyzoProtocol::EVT_ACK, payload, sizeof(payload));
}

void sendNack(uint8_t cmd, uint8_t screen, uint8_t errorCode) {
  uint8_t payload[3] = {cmd, screen, errorCode};
  sendEvent(EyzoProtocol::EVT_NACK, payload, sizeof(payload));
}

void sendStatus() {
  uint8_t payload[4] = {
      (uint8_t)(s_connected ? 1 : 0),
      1,  // écran gauche : pas de sonde matérielle, on suppose OK si le firmware tourne
      1,  // écran droit : idem
      (uint8_t)(s_pairingMode ? 1 : 0),
  };
  sendEvent(EyzoProtocol::EVT_STATUS, payload, sizeof(payload));
}

String loadBondedAddress() {
  prefs.begin(PREFS_NAMESPACE, true);
  String addr = prefs.getString(PREFS_KEY_BONDED_ADDR, "");
  prefs.end();
  return addr;
}

void saveBondedAddress(const String &addr) {
  prefs.begin(PREFS_NAMESPACE, false);
  prefs.putString(PREFS_KEY_BONDED_ADDR, addr);
  prefs.end();
}

void resetReassembly() {
  s_bufLen = 0;
  s_expectedSeq = 0;
  s_reassemblyActive = false;
}

// Décompresse un payload pixels zlib (RFC1950, produit par ZLibEncoder côté
// app, voir packet_builder.dart) dans s_decompressBuffer. `expectedLen` est
// toujours connu à l'avance (déduit de width*height*2), donc sert à la fois
// de taille de buffer de sortie et de vérification d'intégrité : on exige
// une correspondance exacte plutôt que de faire confiance au seul code
// retour de la lib (voir bitbank2/zlib_turbo, dont le code succès ne
// garantit pas à lui seul que le flux décompressé fait la taille attendue).
bool decompressPixels(const uint8_t *src, uint32_t srcLen, uint32_t expectedLen,
                       const uint8_t **outPixels, uint32_t *outLen) {
  if (!s_decompressBuffer || expectedLen == 0 || expectedLen > MAX_PAYLOAD_SIZE) return false;

  s_zlibTurbo.inflate_init(s_decompressBuffer, (int)expectedLen);
  int rc = s_zlibTurbo.inflate(const_cast<uint8_t *>(src), (int)srcLen);
  if (rc != ZT_SUCCESS || (uint32_t)s_zlibTurbo.outSize() != expectedLen) return false;

  *outPixels = s_decompressBuffer;
  *outLen = expectedLen;
  return true;
}

// Résout le couple (format, data) d'un payload SET_TEXT/SET_STATIC_IMAGE/
// SET_ANIMATION_FRAME (voir protocol.h) en pixels RGB565 bruts exploitables
// par DisplayManager, décompressant au besoin. Envoie le NACK approprié et
// renvoie false en cas d'échec (format inconnu, longueur brute incohérente
// avec width*height, décompression invalide).
bool resolvePixels(uint8_t cmd, uint8_t screen, uint8_t format, const uint8_t *data,
                    uint32_t dataLen, uint32_t expectedLen, const uint8_t **outPixels,
                    uint32_t *outLen) {
  if (format == EyzoProtocol::PIXEL_FORMAT_RAW) {
    if (dataLen != expectedLen) {
      sendNack(cmd, screen, EyzoProtocol::ERR_OVERFLOW);
      return false;
    }
    *outPixels = data;
    *outLen = dataLen;
    return true;
  }
  if (format == EyzoProtocol::PIXEL_FORMAT_ZLIB) {
    if (!decompressPixels(data, dataLen, expectedLen, outPixels, outLen)) {
      sendNack(cmd, screen, EyzoProtocol::ERR_DECOMPRESS);
      return false;
    }
    return true;
  }
  sendNack(cmd, screen, EyzoProtocol::ERR_UNKNOWN_CMD);
  return false;
}

void dispatch(uint8_t cmd, uint8_t screen, const uint8_t *payload, uint32_t len) {
  switch (cmd) {
    case EyzoProtocol::CMD_SET_TEXT: {
      // Bitmap déjà rendu côté app (voir protocol.h) : direction, vitesse,
      // couleur de fond, largeur/hauteur, format puis pixels RGB565
      // (bruts ou compressés zlib selon `format`).
      if (len < 8) {
        sendNack(cmd, screen, EyzoProtocol::ERR_OVERFLOW);
        return;
      }
      uint8_t direction = payload[0];
      uint8_t speed = payload[1];
      uint16_t colorBg = readU16LE(&payload[2]);
      uint16_t bitmapWidth = readU16LE(&payload[4]);
      uint8_t bitmapHeight = payload[6];
      uint8_t format = payload[7];
      if (bitmapHeight != SCREEN_H) {
        sendNack(cmd, screen, EyzoProtocol::ERR_OVERFLOW);
        return;
      }
      const uint8_t *pixels;
      uint32_t pixelLen;
      uint32_t expectedLen = (uint32_t)bitmapWidth * bitmapHeight * 2;
      if (!resolvePixels(cmd, screen, format, &payload[8], len - 8, expectedLen, &pixels,
                          &pixelLen)) {
        return;
      }
      DisplayManager::setText(screen, direction, speed, colorBg, bitmapWidth, pixels, pixelLen);
      break;
    }
    case EyzoProtocol::CMD_SET_STATIC_IMAGE: {
      if (len < 9) {
        sendNack(cmd, screen, EyzoProtocol::ERR_OVERFLOW);
        return;
      }
      uint8_t width = payload[0];
      uint8_t height = payload[1];
      uint8_t format = payload[2];
      // payload[3]=frame_index, payload[4]=total_frames, payload[5..6]=frame_delay_ms :
      // non utilisés pour une image statique (voir specs.md §6.3).
      uint16_t dataLen = readU16LE(&payload[7]);
      if (len < (uint32_t)(9 + dataLen)) {
        sendNack(cmd, screen, EyzoProtocol::ERR_OVERFLOW);
        return;
      }
      const uint8_t *pixels;
      uint32_t pixelLen;
      uint32_t expectedLen = (uint32_t)width * height * 2;
      if (!resolvePixels(cmd, screen, format, &payload[9], dataLen, expectedLen, &pixels,
                          &pixelLen)) {
        return;
      }
      DisplayManager::setStaticImage(screen, width, height, pixels, (uint16_t)pixelLen);
      break;
    }
    case EyzoProtocol::CMD_SET_ANIMATION_FRAME: {
      if (len < 9) {
        sendNack(cmd, screen, EyzoProtocol::ERR_OVERFLOW);
        return;
      }
      uint8_t width = payload[0];
      uint8_t height = payload[1];
      uint8_t format = payload[2];
      uint8_t frameIndex = payload[3];
      uint8_t totalFrames = payload[4];
      uint16_t frameDelayMs = readU16LE(&payload[5]);
      uint16_t dataLen = readU16LE(&payload[7]);
      if (len < (uint32_t)(9 + dataLen)) {
        sendNack(cmd, screen, EyzoProtocol::ERR_OVERFLOW);
        return;
      }
      const uint8_t *pixels;
      uint32_t pixelLen;
      uint32_t expectedLen = (uint32_t)width * height * 2;
      if (!resolvePixels(cmd, screen, format, &payload[9], dataLen, expectedLen, &pixels,
                          &pixelLen)) {
        return;
      }
      DisplayManager::setAnimationFrame(screen, width, height, frameIndex, totalFrames,
                                         frameDelayMs, pixels, (uint16_t)pixelLen);
      break;
    }
    case EyzoProtocol::CMD_CLEAR_SCREEN:
      DisplayManager::clearScreen(screen);
      break;
    case EyzoProtocol::CMD_PING:
      break;  // l'ACK générique ci-dessous suffit comme keep-alive
    case EyzoProtocol::CMD_GET_STATUS:
      sendStatus();
      break;
    default:
      sendNack(cmd, screen, EyzoProtocol::ERR_UNKNOWN_CMD);
      return;
  }
}

void handleIncomingChunk(const uint8_t *data, size_t len) {
  if (len < (size_t)EyzoProtocol::HEADER_LEN + 1) return;
  if (data[0] != EyzoProtocol::START_OF_FRAME) return;

  if (!s_reassemblyBuffer) {
    // Allocation PSRAM échouée au démarrage (voir begin()) : rien à faire.
    sendNack(data[1], data[2], EyzoProtocol::ERR_OVERFLOW);
    return;
  }

  uint8_t chk = xorChecksum(data, len - 1);
  if (chk != data[len - 1]) {
    sendNack(data[1], data[2], EyzoProtocol::ERR_CHECKSUM);
    resetReassembly();
    return;
  }

  uint8_t cmd = data[1];
  uint8_t screen = data[2];
  uint16_t seq = readU16LE(&data[3]);
  uint16_t total = readU16LE(&data[5]);
  uint16_t payloadLen = readU16LE(&data[7]);

  if (len != (size_t)EyzoProtocol::HEADER_LEN + payloadLen + 1 || total == 0) {
    sendNack(cmd, screen, EyzoProtocol::ERR_OVERFLOW);
    resetReassembly();
    return;
  }

  if (seq == 0) {
    resetReassembly();
    s_currentCmd = cmd;
    s_currentScreen = screen;
    s_expectedTotal = total;
    s_reassemblyActive = true;
  } else if (!s_reassemblyActive || cmd != s_currentCmd || screen != s_currentScreen ||
             seq != s_expectedSeq || total != s_expectedTotal) {
    sendNack(cmd, screen, EyzoProtocol::ERR_SEQ_MISMATCH);
    resetReassembly();
    return;
  }

  if (s_bufLen + payloadLen > MAX_PAYLOAD_SIZE) {
    sendNack(cmd, screen, EyzoProtocol::ERR_OVERFLOW);
    resetReassembly();
    return;
  }

  memcpy(s_reassemblyBuffer + s_bufLen, data + EyzoProtocol::HEADER_LEN, payloadLen);
  s_bufLen += payloadLen;
  s_expectedSeq = seq + 1;

  if (s_expectedSeq >= total) {
    dispatch(s_currentCmd, s_currentScreen, s_reassemblyBuffer, s_bufLen);
    sendAck(s_currentCmd, s_currentScreen);
    resetReassembly();
  }
}

void exitPairingMode() {
  if (!s_pairingMode) return;
  s_pairingMode = false;
  uint8_t off = 0;
  sendEvent(EyzoProtocol::EVT_PAIRING, &off, 1);
  if (!s_connected) DisplayManager::showDisconnected();
}

// --- Callbacks NimBLE ---

class CommandCallbacks : public NimBLECharacteristicCallbacks {
  void onWrite(NimBLECharacteristic *pChar, NimBLEConnInfo &connInfo) override {
    (void)connInfo;
    NimBLEAttValue val = pChar->getValue();
    handleIncomingChunk((const uint8_t *)val.data(), val.size());
  }
};

class ServerCallbacks : public NimBLEServerCallbacks {
  void onConnect(NimBLEServer *server, NimBLEConnInfo &connInfo) override {
    String addr = connInfo.getAddress().toString().c_str();

    if (s_bondedAddress.length() == 0) {
      // Première connexion jamais faite (specs.md §4.1) : acceptée et
      // mémorisée automatiquement, sans besoin d'appui long.
      s_bondedAddress = addr;
      saveBondedAddress(s_bondedAddress);
    } else if (addr != s_bondedAddress) {
      if (s_pairingMode) {
        // Nouvel appareil pendant la fenêtre d'appairage : il remplace
        // l'appareil mémorisé (un seul "propriétaire" à la fois, comme une
        // enceinte Bluetooth classique).
        s_bondedAddress = addr;
        saveBondedAddress(s_bondedAddress);
        exitPairingMode();
      } else {
        // Appareil inconnu hors fenêtre d'appairage : rejeté. Il reste
        // visible au scan (contrainte BLE : on ne peut pas se rendre
        // invisible sans filtrage au niveau liaison), mais ne peut pas se
        // connecter tant que le bouton n'a pas été appuyé longuement.
        server->disconnect(connInfo.getConnHandle());
        return;
      }
    }

    s_connected = true;
    s_currentConnHandle = connInfo.getConnHandle();
    NimBLEDevice::getAdvertising()->stop();
    DisplayManager::showConnected();
  }

  void onDisconnect(NimBLEServer *server, NimBLEConnInfo &connInfo, int reason) override {
    (void)server;
    (void)connInfo;
    (void)reason;
    s_connected = false;
    s_currentConnHandle = 0xFFFF;
    resetReassembly();
    DisplayManager::showDisconnected();
    NimBLEDevice::getAdvertising()->start();
  }
};

CommandCallbacks s_commandCallbacks;
ServerCallbacks s_serverCallbacks;

}  // namespace

void begin() {
  s_bondedAddress = loadBondedAddress();

  // +ZLIB_TURBO_BUFFER_PADDING : le buffer de réassemblage peut contenir des
  // données compressées lues par zlib_turbo (voir decompressPixels() plus
  // haut), qui a besoin de quelques octets de marge en fin de buffer d'entrée
  // (voir config.h).
  s_reassemblyBuffer = (uint8_t *)heap_caps_malloc(MAX_PAYLOAD_SIZE + ZLIB_TURBO_BUFFER_PADDING,
                                                    MALLOC_CAP_SPIRAM);
  if (!s_reassemblyBuffer) {
    Serial.println("[BLE] ERREUR: allocation PSRAM du buffer de reassemblage echouee");
  }

  s_decompressBuffer = (uint8_t *)heap_caps_malloc(MAX_PAYLOAD_SIZE + ZLIB_TURBO_BUFFER_PADDING,
                                                    MALLOC_CAP_SPIRAM);
  if (!s_decompressBuffer) {
    Serial.println("[BLE] ERREUR: allocation PSRAM du buffer de decompression echouee");
  }

  NimBLEDevice::init(EyzoProtocol::DEVICE_NAME);
  NimBLEDevice::setMTU(247);

  pServer = NimBLEDevice::createServer();
  pServer->setCallbacks(&s_serverCallbacks);

  NimBLEService *pService = pServer->createService(EyzoProtocol::SERVICE_UUID);

  pCommandChar = pService->createCharacteristic(
      EyzoProtocol::COMMAND_CHAR_UUID, NIMBLE_PROPERTY::WRITE | NIMBLE_PROPERTY::WRITE_NR);
  pCommandChar->setCallbacks(&s_commandCallbacks);

  pEventChar = pService->createCharacteristic(EyzoProtocol::EVENT_CHAR_UUID,
                                               NIMBLE_PROPERTY::NOTIFY);

  pService->start();

  NimBLEAdvertising *pAdvertising = NimBLEDevice::getAdvertising();
  // Le paquet d'advertising primaire (31 octets max) est déjà presque plein
  // avec le seul service UUID 128 bits (~21 octets avec les flags) : sans
  // scan response, setName() échoue silencieusement à y faire tenir le nom
  // ("Eyzo Glasses", 12 car.) et l'appareil apparaît sans nom côté app
  // (juste adresse + RSSI). Le scan response a son propre budget de 31
  // octets séparé, largement suffisant pour le nom seul.
  pAdvertising->enableScanResponse(true);
  pAdvertising->addServiceUUID(EyzoProtocol::SERVICE_UUID);
  pAdvertising->setName(EyzoProtocol::DEVICE_NAME);
  pAdvertising->start();

  resetReassembly();
}

void loop() {
  if (s_pairingMode && millis() > s_pairingUntilMs) {
    exitPairingMode();
  }
}

void enterPairingMode() {
  s_pairingMode = true;
  s_pairingUntilMs = millis() + PAIRING_WINDOW_MS;
  DisplayManager::showPairing(PAIRING_WINDOW_MS / 1000);
  uint8_t on = 1;
  sendEvent(EyzoProtocol::EVT_PAIRING, &on, 1);

  if (s_connected && s_currentConnHandle != 0xFFFF && pServer) {
    // Libère la connexion en cours pour permettre à un nouvel appareil de
    // s'appairer à sa place (façon bouton "pairing" d'une enceinte Bluetooth).
    pServer->disconnect(s_currentConnHandle);
  }
  NimBLEDevice::getAdvertising()->start();
}

}  // namespace BleManager
