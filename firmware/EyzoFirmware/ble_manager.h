#pragma once

// Serveur BLE (NimBLE) : expose le service/caractéristiques Eyzo (voir
// protocol.h et specs.md §6), réassemble les trames chunkées reçues sur la
// caractéristique Commande et les transmet à DisplayManager, et gère le
// cycle de vie "enceinte Bluetooth" décrit en specs.md §4.1 :
//   - 1ère connexion jamais faite -> acceptée et mémorisée automatiquement
//     (NVS via Preferences).
//   - Appareil déjà mémorisé -> reconnexion automatique (le firmware
//     advertise en continu quand non connecté, l'app se connecte par
//     adresse ; voir autoReconnectProvider côté Flutter).
//   - Appareil inconnu qui tente de se connecter -> rejeté, SAUF pendant la
//     fenêtre d'appairage ouverte par un appui long sur le bouton
//     (voir button_manager.h), auquel cas il devient le nouvel appareil
//     mémorisé (remplace le précédent — modèle "un seul propriétaire").
namespace BleManager {

void begin();

// A appeler à chaque tour de loop() principal (gère l'expiration de la
// fenêtre d'appairage).
void loop();

// A appeler depuis le callback d'appui long du bouton.
void enterPairingMode();

}  // namespace BleManager
