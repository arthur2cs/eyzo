#pragma once

// Brochage Seeed XIAO ESP32S3 — voir firmware/README.md pour le schéma complet.
// Bus SPI partagé (SCK/MOSI) entre les 2 écrans, CS et RST séparés par écran
// (le RST ne peut PAS être partagé : le reset matériel réinitialiserait aussi
// l'écran déjà configuré, voir la note dans display_manager.cpp).
#define PIN_TFT_SCK 7        // D8
#define PIN_TFT_MOSI 9       // D10
#define PIN_TFT_CS_LEFT 1    // D0
#define PIN_TFT_CS_RIGHT 2   // D1
#define PIN_TFT_DC 3         // D2 (partagé)
#define PIN_TFT_RST_LEFT 4   // D3
#define PIN_TFT_RST_RIGHT 5  // D4
#define PIN_BUTTON 6         // D5

// Résolution native du panneau ST7735S monté en paysage (voir specs.md §2).
#define SCREEN_W 160
#define SCREEN_H 128

// Bouton poussoir : appui long = mode appairage (voir specs.md §4.1).
#define BUTTON_DEBOUNCE_MS 30
#define BUTTON_LONG_PRESS_MS 800

// Fenêtre pendant laquelle un nouvel appareil (jamais connecté / oublié)
// peut s'appairer après un appui long. Passé ce délai, retour au mode
// "connexion automatique au dernier appareil connu uniquement".
#define PAIRING_WINDOW_MS 60000UL

// Nombre max de frames stockées pour une animation (mémoire allouée en PSRAM,
// voir README — "PSRAM: OPI PSRAM" à activer dans le menu Outils).
#define MAX_ANIMATION_FRAMES 64

// Taille max d'un payload réassemblé, voir ble_manager.cpp. Couvre une image
// plein écran (160x128 RGB565 ≈ 41 Ko) et les bitmaps de texte défilant
// envoyés par l'app (largeur variable selon la longueur du message et la
// taille de police, hauteur fixe SCREEN_H, voir text_bitmap_renderer.dart
// côté app) — buffer alloué en PSRAM (voir begin() dans ble_manager.cpp),
// pas de quoi tenir dans la SRAM interne.
#define MAX_PAYLOAD_SIZE 250000UL

// La lib zlib_turbo (voir ble_manager.cpp) fait des lectures/écritures non
// alignées par mots de 32 bits pour accélérer la décompression : ses buffers
// d'entrée ET de sortie doivent être alloués quelques octets plus grands que
// la taille utile réelle pour rester dans les clous côté allocation mémoire
// (voir bitbank2/zlib_turbo README, "input buffer and output buffer need to
// be allocated 4-8 bytes larger than needed"). Appliqué au buffer de
// réassemblage (entrée, potentiellement compressée) et au buffer de
// décompression (sortie), tous deux alloués en PSRAM, voir begin() dans
// ble_manager.cpp.
#define ZLIB_TURBO_BUFFER_PADDING 16UL

// Intervalle de clignotement pour le mode texte "clignotant" (direction=3).
// Non spécifié par le protocole (specs.md §6.3) : choix firmware.
#define BLINK_INTERVAL_MS 500
