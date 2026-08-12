#pragma once
#include <Arduino.h>

// Contrat BLE App <-> Firmware ESP32 — miroir de lib/core/ble/eyzo_protocol.dart
// et lib/core/ble/packet_builder.dart côté app Flutter (voir specs.md §6).
// Toute modification ICI doit être répercutée côté app, et inversement.
namespace EyzoProtocol {

// --- GATT ---
static const char *SERVICE_UUID = "4e4a0001-6f61-4c1e-8c3a-4e4a656f7a30";
static const char *COMMAND_CHAR_UUID = "4e4a0002-6f61-4c1e-8c3a-4e4a656f7a30";
static const char *EVENT_CHAR_UUID = "4e4a0003-6f61-4c1e-8c3a-4e4a656f7a30";

// Nom annoncé en BLE advertising. L'app ne filtre pas par nom (l'utilisateur
// choisit dans la liste scannée), mais specs.md §4.1 mentionne "Eyzo Glasses".
static const char *DEVICE_NAME = "Eyzo Glasses";

// --- Trame de commande (téléphone -> ESP32), voir specs.md §6.2 ---
// | SOF(1) | CMD(1) | SCREEN(1) | SEQ(2 LE) | TOTAL(2 LE) | LEN(2 LE) | PAYLOAD(LEN) | CHK(1) |
static const uint8_t START_OF_FRAME = 0xAA;
static const uint8_t HEADER_LEN = 9;  // tout sauf PAYLOAD et CHK

// Payload SET_TEXT — bitmap RGB565 déjà rendu côté app (police/taille/couleur
// fidèles à l'aperçu, voir text_bitmap_renderer.dart), le firmware se
// contente de l'afficher/défiler tel quel :
//   | direction(1) | speed(1) | color_bg(2 LE) | width(2 LE) | height(1) |
//   | format(1) | data (voir format ci-dessous) |
// - direction=statique/clignotant : bitmap plein écran (width=SCREEN_W,
//   height=SCREEN_H), fond déjà peint dedans.
// - direction=défilement : bitmap resserré sur le texte seul (width =
//   largeur du texte, height=SCREEN_H) ; color_bg sert à peindre le fond
//   autour à chaque pas de défilement.
//
// Payload SET_STATIC_IMAGE / SET_ANIMATION_FRAME :
//   | width(1) | height(1) | format(1) | frame_index(1) | total_frames(1) |
//   | frame_delay_ms(2 LE) | data_len(2 LE) | data (voir format ci-dessous) |
// (frame_index/total_frames/frame_delay_ms ignorés pour une image statique.)
//
// `format` (voir PIXEL_FORMAT_*, packet_builder.dart) : `data` contient soit
// les pixels RGB565 big-endian bruts (row-major, width*height*2 octets), soit
// ces mêmes pixels compressés zlib/deflate (RFC1950) — décompressés côté
// firmware avec la lib `zlib_turbo` (voir ble_manager.cpp et
// firmware/README.md) avant d'être transmis à DisplayManager. La taille
// décompressée attendue (width*height*2) est toujours déduite des champs
// width/height déjà présents dans le payload, jamais retransmise séparément.
static const uint8_t CMD_SET_TEXT = 0x01;
static const uint8_t CMD_SET_STATIC_IMAGE = 0x02;
static const uint8_t CMD_SET_ANIMATION_FRAME = 0x03;
static const uint8_t CMD_CLEAR_SCREEN = 0x04;
static const uint8_t CMD_PING = 0x05;
static const uint8_t CMD_GET_STATUS = 0x06;

static const uint8_t PIXEL_FORMAT_RAW = 0x00;
static const uint8_t PIXEL_FORMAT_ZLIB = 0x01;

static const uint8_t SCREEN_LEFT = 0x00;
static const uint8_t SCREEN_RIGHT = 0x01;
static const uint8_t SCREEN_SIMULTANEOUS = 0x02;
static const uint8_t SCREEN_SEQUENTIAL = 0x03;  // SET_TEXT uniquement

// direction (payload SET_TEXT)
static const uint8_t DIR_LEFTWARD = 0x00;
static const uint8_t DIR_RIGHTWARD = 0x01;
static const uint8_t DIR_STATIC = 0x02;
static const uint8_t DIR_BLINK = 0x03;

// --- Caractéristique Événement (ESP32 -> téléphone) ---
// Non figé côté app (voir _onEvent dans eyzo_ble_service.dart, marqué comme
// "à affiner avec le firmware") : ce format est une proposition firmware,
// symétrique à la trame de commande.
// | SOF(1)=0xAA | EVT(1) | LEN(1) | PAYLOAD(LEN) | CHK(1, XOR sur SOF..PAYLOAD) |
static const uint8_t EVT_ACK = 0x01;      // payload: cmd, screen
static const uint8_t EVT_NACK = 0x02;     // payload: cmd, screen, errorCode
static const uint8_t EVT_STATUS = 0x03;   // payload: connected, leftOk, rightOk, pairingMode
static const uint8_t EVT_PAIRING = 0x04;  // payload: active (0/1)

static const uint8_t ERR_CHECKSUM = 0x01;
static const uint8_t ERR_OVERFLOW = 0x02;
static const uint8_t ERR_UNKNOWN_CMD = 0x03;
static const uint8_t ERR_SEQ_MISMATCH = 0x04;
static const uint8_t ERR_DECOMPRESS = 0x05;  // format zlib annoncé mais décompression impossible/invalide

}  // namespace EyzoProtocol
