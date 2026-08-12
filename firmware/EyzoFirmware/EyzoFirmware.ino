// Firmware ESP32-S3 pour les lunettes connectées Eyzo.
// Voir firmware/README.md pour l'installation Arduino IDE et le schéma de
// brochage, et specs.md (racine du projet) pour le contrat applicatif
// complet (app Flutter <-> firmware).
//
// Comportement "enceinte Bluetooth" (specs.md §4.1) :
//   - 1ère mise en route (aucun appareil mémorisé) -> accepte et mémorise le
//     premier téléphone qui se connecte.
//   - Appareil déjà mémorisé -> reconnexion automatique au démarrage et à
//     toute coupure.
//   - Appui LONG sur le bouton -> ouvre une fenêtre de 60s pendant laquelle
//     un nouvel appareil peut s'appairer.

#include "ble_manager.h"
#include "button_manager.h"
#include "config.h"
#include "display_manager.h"
#include "protocol.h"

void handleLongPress() {
  Serial.println("[BOUTON] Appui long détecté");
  Serial.println("[BLE] Passage en mode appairage");

  BleManager::enterPairingMode();
}

void setup() {
  Serial.begin(115200);

  // Attend au maximum 5 secondes que le port série USB soit ouvert.
  unsigned long serialStart = millis();

  while (!Serial && millis() - serialStart < 5000) {
    delay(10);
  }

  delay(500);

  Serial.println();
  Serial.println("================================");
  Serial.println("       DEMARRAGE EYZO");
  Serial.println("================================");

  Serial.println("[DISPLAY] Initialisation...");
  DisplayManager::begin();
  Serial.println("[DISPLAY] Initialisation terminée");

  Serial.println("[DISPLAY] Affichage de l'écran de démarrage...");
  DisplayManager::showBoot();
  Serial.println("[DISPLAY] Écran de démarrage affiché");

  Serial.println("[BOUTON] Initialisation...");
  ButtonManager::begin();
  ButtonManager::onLongPress(handleLongPress);
  Serial.println("[BOUTON] Initialisation terminée");

  Serial.println("[BLE] Initialisation...");
  BleManager::begin();
  Serial.println("[BLE] Initialisation terminée");

  Serial.println("================================");
  Serial.println("        EYZO EST PRÊT");
  Serial.println("================================");
}

void loop() {
  ButtonManager::loop();
  BleManager::loop();
  DisplayManager::loop();

  // Message toutes les secondes pour vérifier que le programme
  // fonctionne toujours et ne s'est pas bloqué.
  static unsigned long lastSerialMessage = 0;

  if (millis() - lastSerialMessage >= 1000) {
    lastSerialMessage = millis();
    Serial.println("[SYSTEME] Firmware en fonctionnement");
  }
}
