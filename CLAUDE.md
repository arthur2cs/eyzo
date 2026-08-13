# Eyzo

App Flutter de pilotage de lunettes connectées (texte défilant, images, animations) via BLE, avec firmware ESP32 associé (`firmware/EyzoFirmware/`). Voir `specs.md` pour le protocole et les spécifications détaillées.

## Convention L/R (porteur) vs gauche/droite (aperçu)

Le porteur des lunettes et la personne qui regarde l'aperçu dans l'app n'ont **pas la même perspective** :

- **L / R** : verre **Gauche**/**Droit** du **porteur** — la perspective du porteur, invariante (c'est aussi la convention protocole, voir `TargetScreen` dans `lib/models/target_screen.dart` et `SCREEN_LEFT`/`SCREEN_RIGHT` dans `firmware/EyzoFirmware/protocol.h`).
- **gauche / droite** : position à l'écran dans l'aperçu de l'app, en vue **miroir** ("je vois ce que le porteur montre au public", specs.md §3) — le verre **R** (droit du porteur) est dessiné à **gauche** de l'app, le verre **L** (gauche du porteur) à **droite**. Voir `DualLensRow` (`lib/widgets/dual_lens_row.dart`).

Dans l'app, les légendes sous les verres de l'aperçu affichent donc "L"/"R" (pas "Gauche"/"Droite") pour éviter toute ambiguïté entre les deux perspectives.

**En conversation** : "L"/"R" = perspective porteur ; "gauche"/"droite" = perspective de l'aperçu (viewer). Ne pas mélanger les deux sans préciser.
