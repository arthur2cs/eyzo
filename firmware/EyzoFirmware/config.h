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

// Taille max d'un payload réassemblé (avant compression), voir
// ble_manager.cpp — deux buffers de cette taille sont alloués en PSRAM
// (réassemblage + décompression, voir begin()), pas de quoi tenir dans la
// SRAM interne. Doit couvrir le plus gros cas d'usage app : une animation
// complète (SET_ANIMATION, voir protocol.h) envoyée en un seul bloc,
// frame_count x width x height x 2 octets — jusqu'à ~1,2 Mo pour la
// résolution de travail native (160x128) au nombre de frames par défaut de
// l'app (30, voir image_conversion.dart), avec de la marge. Une image
// plein écran (~41 Ko) ou un bitmap de texte défilant tiennent très
// largement dedans. 2 x cette taille (~3 Mo) laisse une marge confortable
// sur les 8 Mo de PSRAM du XIAO ESP32S3 pour le reste (animations déjà
// affichées sur les 2 écrans, canevas, pile BLE).
#define MAX_PAYLOAD_SIZE 1500000UL

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
