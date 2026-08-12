#include "button_manager.h"

#include <Arduino.h>

#include "config.h"

namespace ButtonManager {

namespace {
void (*s_onLongPress)() = nullptr;

int s_stableState = HIGH;   // état "debouncé" retenu
int s_lastReading = HIGH;   // dernière lecture brute
uint32_t s_lastChangeMs = 0;
uint32_t s_pressStartMs = 0;
bool s_longPressFired = false;
}  // namespace

void begin() {
  pinMode(PIN_BUTTON, INPUT_PULLUP);
  s_stableState = digitalRead(PIN_BUTTON);
  s_lastReading = s_stableState;
}

void onLongPress(void (*callback)()) { s_onLongPress = callback; }

void loop() {
  int reading = digitalRead(PIN_BUTTON);

  if (reading != s_lastReading) {
    s_lastReading = reading;
    s_lastChangeMs = millis();
  }

  if ((millis() - s_lastChangeMs) > BUTTON_DEBOUNCE_MS && reading != s_stableState) {
    s_stableState = reading;
    if (s_stableState == LOW) {
      // Front descendant stable : début d'appui.
      s_pressStartMs = millis();
      s_longPressFired = false;
    }
  }

  if (s_stableState == LOW && !s_longPressFired &&
      (millis() - s_pressStartMs) >= BUTTON_LONG_PRESS_MS) {
    s_longPressFired = true;
    if (s_onLongPress) s_onLongPress();
  }
}

}  // namespace ButtonManager
