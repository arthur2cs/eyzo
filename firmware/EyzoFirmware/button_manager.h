#pragma once

// Bouton poussoir unique (voir config.h PIN_BUTTON) : câblé entre le GPIO et
// la masse, lu en INPUT_PULLUP (repos = HIGH, appuyé = LOW).
// Un appui long (>= BUTTON_LONG_PRESS_MS) déclenche le callback enregistré
// via onLongPress() — utilisé par le firmware pour ouvrir le mode appairage
// (voir specs.md §4.1 et ble_manager.h).
namespace ButtonManager {

void begin();

// A appeler à chaque tour de loop() principal ; non bloquant.
void loop();

// Callback appelé une seule fois par appui long qualifié (pas de répétition
// tant que le bouton reste maintenu).
void onLongPress(void (*callback)());

}  // namespace ButtonManager
