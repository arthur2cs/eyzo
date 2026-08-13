/// Cadences d'animation calquées **exactement** sur le firmware (voir
/// display_manager.cpp) — l'aperçu app doit avancer au même rythme que les
/// lunettes pour montrer les mêmes lettres au même instant (voir specs.md
/// §4.2). Toute modification ICI doit être répercutée côté firmware, et
/// inversement.
library;

/// Miroir exact de `stepIntervalFromSpeed()` dans display_manager.cpp :
/// délai (ms) entre 2 pas de défilement d'1 pixel. Recalibré en 2 segments
/// (voir specs.md §6.3) — vitesse 1 -> 60 ms/px, vitesse 5 -> 10 ms/px
/// (l'ancienne vitesse 10 devient la nouvelle vitesse 5), vitesse 10 ->
/// 5 ms/px (continue d'accélérer au-delà, plus doucement). Reproduit à
/// l'identique l'arithmétique entière du `map()` Arduino (troncature vers
/// zéro, pas d'arrondi) : un calcul en flottant donnerait un résultat
/// différent d'1 ms à certaines vitesses, ce qui suffit à désynchroniser
/// visiblement l'aperçu des lunettes sur un défilement long.
int scrollStepIntervalMs(int speed) {
  final s = speed.clamp(1, 10);
  if (s <= 5) return (s - 1) * (10 - 60) ~/ (5 - 1) + 60;
  return (s - 5) * (5 - 10) ~/ (10 - 5) + 10;
}

/// Miroir exact de `blinkHalfPeriodFromSpeed()` dans display_manager.cpp :
/// durée (ms) d'une demi-période (allumé OU éteint) du mode clignotant.
/// Même principe de recalibration en 2 segments que [scrollStepIntervalMs]
/// — vitesse 1 -> 600 ms, vitesse 5 -> 200 ms, vitesse 10 -> 150 ms —, avec
/// un plancher volontairement plus prudent que le défilement pour rester
/// dans un rythme de clignotement franc plutôt qu'un scintillement gênant.
int blinkHalfPeriodMs(int speed) {
  final s = speed.clamp(1, 10);
  if (s <= 5) return (s - 1) * (200 - 600) ~/ (5 - 1) + 600;
  return (s - 5) * (150 - 200) ~/ (10 - 5) + 200;
}
