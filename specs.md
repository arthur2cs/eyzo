# Eyzo — Spécifications

Application Flutter (Android) permettant d'envoyer du texte défilant et des animations à des lunettes connectées custom, équipées d'un ESP32 et de 2 écrans LCD indépendants.

Ce document sert de contrat de référence pour le développement de l'app **et** du firmware ESP32 (protocole de communication).

---

## 1. Vue d'ensemble

- **Nom de l'application** : Eyzo
- **Icône** : panda mignon (fournie par l'utilisateur)
- **Plateforme cible** : Android (Flutter), version minimale API 26 (Android 8.0)
- **Objectif** : composer et envoyer, depuis le téléphone, du texte défilant, des animations ou des images vers les 2 écrans des lunettes, indépendamment l'un de l'autre.

## 2. Matériel cible

- **MCU** : Seeed Studio XIAO ESP32S3 (240 MHz, WiFi + BLE, Arduino/MicroPython)
- **Écrans** : 2x écran TFT SPI 1,77" ST7735S, résolution 128x160 (dalle native), montés en orientation **paysage** dans les lunettes → résolution effective 160x128, couleur (RGB565)
- **Écran gauche / écran droit** : pilotés indépendamment, chacun peut afficher un contenu différent
- **Firmware ESP32** : pas encore développé — ce document définit le protocole de communication qu'il devra implémenter

## 3. Design / UI

- **Thème** : dark mode uniquement (pas de light mode), noir dominant / texte blanc
- **Style** : minimaliste et sobre dans la structure, mais avec une touche kawaii assumée en clin d'œil à l'icône panda — typographie et boutons généreux/arrondis plutôt que stricts
- **Icône app** : panda mignon (asset fourni par l'utilisateur, à intégrer dans `assets/icon/`)
- **Palette inspirée du panda** :
  - Noir/blanc en base
  - Gris `#59595C` (tache "à lunettes" du panda) pour les bordures et éléments neutres
  - Rose `#FB7B77` (langue du panda) en accent vif, réservé à **exactement 3 usages** : le statut "connecté", l'indicateur de navigation (Accueil/Favoris/Paramètres) et le focus des champs de texte (bordure pendant la saisie, icône favoris une fois enregistré) — jamais dans les sélections/contrôles des pages (chips, segmented button, slider restent en blanc/noir neutre)
- **Typographie** : police arrondie et généreuse (Quicksand) pour un rendu plus doux/amical que la police système par défaut ; boutons avec padding et rayons de bordure généreux (20dp). Police embarquée localement dans `assets/fonts/` (aucun téléchargement au premier lancement)
- **Aperçu miroir** : les écrans de composition affichent les 2 verres côte à côte selon la convention "je vois ce que le porteur montre au public" — le verre **droit** du porteur est affiché à **gauche** dans l'app, le verre **gauche** du porteur à **droite** (vue miroir, comme se faire face)
- **Format des cadres d'aperçu** : dessinés au ratio **3:2** (plus large que haut) pour un rendu visuellement plus proche d'un vrai petit écran de lunettes que le ratio natif 5:4 du panneau ST7735S en orientation paysage (160x128) — un choix esthétique côté app, sans lien avec la résolution réelle des données envoyées (voir §6.3)

## 4. Fonctionnalités

### 4.1 Connexion aux lunettes (BLE)

- Protocole : **Bluetooth Low Energy (BLE)**
- Scan BLE avec liste des appareils détectés, appairage à un appareil "Eyzo Glasses"
- Mémorisation de l'appareil appairé (device id) + **reconnexion automatique** au lancement de l'app et en cas de coupure
- Écran/possibilité de "oublier l'appareil" pour ré-appairer
- **Indicateur de statut de connexion** visible en permanence (ex: bandeau ou icône dans l'AppBar) : connecté / déconnecté / en cours de connexion
- **Niveau de batterie des lunettes** affiché si disponible (voir §6.4 — dépend de la capacité matérielle du XIAO ESP32S3 à lire la tension batterie ; à valider côté firmware/hardware, non garanti par défaut)
- Permissions Android gérées au runtime :
  - Android 12+ (API 31+) : `BLUETOOTH_SCAN`, `BLUETOOTH_CONNECT`
  - Android 8–11 (API 26–30) : `BLUETOOTH`, `BLUETOOTH_ADMIN`, `ACCESS_FINE_LOCATION` (requis par le système pour le scan BLE)

### 4.2 Texte défilant

- Champ de saisie de texte, mode **"écrire puis envoyer"** (pas de live typing)
- Sélection de l'écran cible : **Gauche / Droit / Simultané / Séquentiel**
  - Gauche, Droit, Simultané : contenu identique ou indépendant sur chaque écran (comme pour les autres modes de contenu, voir §6.2)
  - **Séquentiel (texte uniquement)** : les 2 écrans forment une seule bande de défilement continue — le texte part d'un écran et continue sur l'autre. L'écran de départ dépend de la direction : en défilement "←" le texte entre par l'écran Gauche et sort par l'écran Droit ; en "→" c'est l'inverse (voir §6.3 pour le détail protocole). Sans effet particulier en mode statique/clignotant (équivalent à Simultané dans ce cas).
- Réglages disponibles :
  - **Vitesse** (slider, niveau 1–10) : pas de défilement en mode défilement, cadence de clignotement en mode clignotant (deux mappings distincts, voir §6.3 — sans effet en mode statique)
  - **Couleur du texte et couleur de fond** (color picker, rendu RGB565 sur les écrans)
  - **Police et taille de caractère** (liste de polices bitmap embarquées côté firmware, sélection par id)
  - **Direction / mode** : défilement gauche→droite, droite→gauche, statique, clignotant
- **Aperçu double-verre** dans l'app avant envoi, y compris pour le mode Séquentiel (simulateur des 2 écrans 160x128 miniatures, voir §3)
- Bouton "Envoyer" + bouton "Ajouter aux favoris"

### 4.3 Import d'image / GIF

- Import depuis la galerie du téléphone (image fixe ou GIF animé, y compris les GIF enregistrés depuis un clavier/une autre app dans la galerie)
- **Insertion directe depuis la banque de GIF du clavier** (Gboard, etc.) : un champ dédié reçoit le GIF choisi dans le clavier via le mécanisme Android `commitContent`, exposé côté Flutter par `contentInsertionConfiguration` sur `TextField`
  - Le clavier transmet soit les octets du GIF directement, soit une URI `content://` — dans ce second cas (le plus fréquent pour des GIF, plus volumineux), l'app lit l'URI via un petit pont natif Android (`MethodChannel` + `ContentResolver.openInputStream`, voir `MainActivity.kt`)
  - Ne nécessite ni compte, ni clé API, ni connexion Internet côté app (le clavier gère lui-même le téléchargement/cache du GIF)
  - ~~Recherche Tenor intégrée~~ abandonnée : Tenor n'accepte plus de nouveaux clients API depuis janvier 2026
- Redimensionnement/conversion automatique vers la résolution de travail (voir §4.4) avant transfert — jamais de déformation ; deux modes de cadrage au choix (**Remplir**, par défaut, ou **Image entière**), voir ci-dessous
- **Mode de cadrage** :
  - **Remplir** *(par défaut)* : la plus petite dimension colle aux bords de la grille, le surplus sur l'autre dimension est recadré (crop centré)
  - **Image entière** : l'image est incluse en entier, quitte à laisser des bandes noires (letterbox/pillarbox) sur les bords
- Aperçu double-verre avant envoi
- Sélection de l'écran cible

### 4.4 Éditeur pixel-art

- Grille de dessin en **basse résolution** (ex: 40x32 ou 80x64, configurable) — l'app fait l'**upscale** (nearest-neighbor) pour remplir l'écran 160x128 réel, à la fois pour l'aperçu app et pour le rendu final sur les lunettes
- Outils : pixel, ligne, remplissage (bucket), gomme, palette de couleurs
- Gestion multi-frames : ajouter / dupliquer / supprimer une frame, réglage du délai entre frames (animation image par image)
- Aperçu animé en direct dans l'app
- Sauvegarde en favoris, envoi vers écran gauche / droit / simultané

### 4.5 Favoris & historique

- Bibliothèque locale de contenus sauvegardés (textes, animations importées/dessinées, images)
- Réutilisation en un tap (renvoyer, dupliquer, éditer, supprimer)
- Stockage **local uniquement** sur le téléphone (pas de compte, pas de cloud) — base de données locale embarquée (ex: Hive)

### 4.6 Paramètres

- Gestion de l'appareil appairé (info, oublier, reconnecter)
- À propos / version de l'app

## 5. Architecture applicative (écrans Flutter)

1. **Accueil / Dashboard** — statut de connexion, batterie, accès rapide aux 3 modes de contenu
2. **Connexion** — scan BLE, appairage, gestion de l'appareil
3. **Texte** — composition + réglages + aperçu double-verre + envoi
4. **Import** — sélection galerie/GIF + aperçu/recadrage + envoi
5. **Éditeur pixel-art** — canvas, outils, gestion de frames, aperçu, envoi
6. **Favoris / Historique** — liste, actions rapides
7. **Paramètres**

## 6. Protocole de communication BLE (contrat App ↔ Firmware)

> Ce protocole est une **proposition** à valider/affiner avec le développement du firmware ESP32. Les UUID ci-dessous sont des exemples à figer définitivement en phase d'implémentation.

### 6.1 Services & caractéristiques GATT

| Élément | UUID (exemple) | Type | Description |
|---|---|---|---|
| Service Eyzo | `4e4a0001-6f61-4c1e-8c3a-4e4a656f7a30` | Service | Service principal de contrôle |
| Caractéristique Commande | `4e4a0002-6f61-4c1e-8c3a-4e4a656f7a30` | Write / Write No Response | Phone → ESP32, envoi des trames de commande (chunkées) |
| Caractéristique Événement | `4e4a0003-6f61-4c1e-8c3a-4e4a656f7a30` | Notify | ESP32 → Phone, ACK/NACK, erreurs, statut |
| Service Batterie | `0x180F` (standard BLE) | Service | Battery Service standard, si lecture batterie possible |
| Battery Level | `0x2A19` (standard BLE) | Read / Notify | Niveau de batterie en % |

- Négociation MTU côté app : demander un MTU élevé (jusqu'à 247–517 octets) pour limiter le nombre de paquets lors des transferts d'image/animation.

### 6.2 Format de trame (caractéristique Commande)

En-tête commun à chaque paquet (chunk) :

| Octets | Champ | Description |
|---|---|---|
| 1 | `SOF` | Marqueur de début, `0xAA` |
| 1 | `CMD` | Identifiant de commande (voir §6.3) |
| 1 | `SCREEN` | Écran cible : `0x00` gauche, `0x01` droit, `0x02` simultané, `0x03` séquentiel (texte uniquement, voir §6.3) |
| 2 | `SEQ` | Index du chunk courant (uint16 LE) |
| 2 | `TOTAL` | Nombre total de chunks pour ce contenu (uint16 LE) |
| 2 | `LEN` | Longueur du payload dans ce chunk (uint16 LE) |
| N | `PAYLOAD` | Données (voir formats par commande) |
| 1 | `CHK` | Checksum (XOR ou CRC8 des octets précédents) |

### 6.3 Commandes

| CMD | Nom | Description |
|---|---|---|
| `0x01` | `SET_TEXT` | Envoi d'un texte défilant, sous forme de bitmap déjà rendu côté app (chunké) |
| `0x02` | `SET_STATIC_IMAGE` | Envoi d'une image statique (chunké) |
| `0x03` | `SET_ANIMATION` | Envoi de l'animation complète — toutes les frames en une seule commande (chunké) |
| `0x04` | `CLEAR_SCREEN` | Efface l'écran cible |
| `0x05` | `PING` | Keep-alive |
| `0x06` | `GET_STATUS` | Demande de statut (batterie, connexion écrans) |

#### Payload `SET_TEXT`

Le texte est rendu **côté app** en bitmap RGB565, avec la police/taille/couleur
exactement telles que dans l'aperçu de composition (voir
`text_bitmap_renderer.dart`) : le firmware ne rend plus aucune police
lui-même, il se contente d'afficher/défiler ce bitmap tel quel. Ceci élimine
l'écart entre l'aperçu app et le rendu réel sur les lunettes (police interne
ESP32 différente, mapping de taille grossier).

| Octets | Champ |
|---|---|
| 1 | `direction` (0=gauche, 1=droite, 2=statique, 3=clignotant) |
| 1 | `speed` (niveau 1–10) |
| 2 | `color_bg` (RGB565 LE) |
| 2 | `width` (uint16 LE) |
| 1 | `height` (toujours égal à la hauteur native de l'écran, 128) |
| 2 | `gap_native_px` (uint16 LE) — écart inter-écran en pixels natifs, uniquement significatif pour `SCREEN = 0x03` (séquentiel), ignoré sinon |
| 1 | `format` (0=brut, 1=compressé zlib — voir "Compression" ci-dessous) |
| N | pixels RGB565 big-endian, row-major (`width * height * 2` octets si `format=0` ; sinon flux zlib de ces mêmes octets) |

- `direction` statique/clignotant : bitmap **plein écran** (`width` = 160,
  `height` = 128), fond déjà peint dedans — le firmware l'affiche/le masque
  tel quel (clignotement) sans autre calcul. `speed` pilote la cadence de
  clignotement (`blinkHalfPeriodFromSpeed()` dans display_manager.cpp) — un
  mapping différent de celui du défilement (`stepIntervalFromSpeed()`),
  reproduit à l'identique côté app dans `glasses_timing.dart` pour que
  l'aperçu et l'affichage réel restent synchronisés. Sans effet en mode
  statique.
- `direction` défilement : bitmap resserré sur le texte seul (`width` =
  largeur réelle du texte rendu, `height` = 128) — le firmware repeint le
  fond avec `color_bg` à chaque pas et y positionne une fenêtre glissante du
  bitmap (translation pure, pas de nouveau rendu de police), exactement comme
  il le faisait déjà pour le défilement du texte natif.
- Un bitmap de texte peut peser nettement plus qu'une image plein écran pour
  un message long à grande taille de police (limite : voir `maxPayloadSize`
  côté app / `MAX_PAYLOAD_SIZE` côté firmware, ~1,5 Mo — dimensionnée pour
  couvrir le plus gros cas d'usage réel, une animation complète envoyée en
  un seul bloc via `SET_ANIMATION`, mesurée **avant** compression) — l'app
  rejette l'envoi avant transmission si ce plafond est dépassé plutôt que de
  laisser un transfert BLE de plusieurs minutes.

**Mode séquentiel (`SCREEN = 0x03`, `SET_TEXT` uniquement)** : les 2 écrans sont traités par le firmware comme une seule bande de défilement continue (largeur virtuelle = 2x la largeur d'un écran + `gap_native_px`), au lieu de dupliquer le même texte sur chaque écran indépendamment. L'écran de départ dépend du champ `direction` de ce même payload :
- `direction = 0` (défilement ←) : le texte entre par l'écran **Gauche** et sort par l'écran **Droit**.
- `direction = 1` (défilement →) : le texte entre par l'écran **Droit** et sort par l'écran **Gauche**.
- `direction = 2` (statique) ou `3` (clignotant) : pas de déplacement possible entre écrans — le firmware doit traiter `SCREEN = 0x03` comme équivalent à `0x02` (simultané) dans ce cas.
- `gap_native_px` élargit la bande virtuelle de cet écart : le texte est invisible le temps de le traverser (à la même vitesse en pixels natifs/seconde que le défilement), exactement comme dans l'aperçu (`SequentialTextPreview`/`_nativeGapPx`) — les 2 restent ainsi synchronisés, l'écart réglé par l'utilisateur (`interLensGapProvider`) n'étant plus une simulation purement visuelle côté app.

`SCREEN = 0x03` n'est pas utilisé par `SET_STATIC_IMAGE` / `SET_ANIMATION` (non exposé côté app pour ces commandes) ; comportement non défini si reçu par le firmware pour ces commandes.

#### Payload `SET_STATIC_IMAGE`

| Octets | Champ |
|---|---|
| 1 | `width` (résolution de travail, ex: ≤ 64) |
| 1 | `height` |
| 1 | `format` (0=brut, 1=compressé zlib — voir "Compression" ci-dessous) |
| 2 | `data_len` (longueur de `data` **telle que transmise**, donc après compression si `format=1`) |
| N | `data` : pixels RGB565 (row-major) si `format=0` ; sinon flux zlib de ces mêmes octets — répartis sur plusieurs chunks selon `SEQ`/`TOTAL` |

#### Payload `SET_ANIMATION`

Toute l'animation part en **une seule commande** (plus un envoi par frame
comme avant) : les frames sont concaténées puis compressées **ensemble**
avant l'envoi, voir "Compression" ci-dessous.

| Octets | Champ |
|---|---|
| 1 | `width` (résolution de travail, ex: ≤ 64) |
| 1 | `height` |
| 1 | `frame_count` |
| 2 | `frame_delay_ms` (uniforme pour toute l'animation) |
| 1 | `format` (0=brut, 1=compressé zlib — voir "Compression" ci-dessous) |
| N | `data` : `frame_count` frames RGB565 (row-major) concaténées dans l'ordre si `format=0` ; sinon flux zlib de ces mêmes octets — répartis sur plusieurs chunks selon `SEQ`/`TOTAL` |

#### Compression (`format`, `SET_TEXT`/`SET_STATIC_IMAGE`/`SET_ANIMATION`)

Les pixels RGB565 peuvent être envoyés compressés en **zlib/deflate
(RFC1950)** plutôt que bruts, pour réduire le nombre de chunks BLE à
transmettre (le débit BLE, pas le rendu, domine le temps d'envoi pour un
message un peu long — voir §9). Le champ `format` (0=brut, 1=zlib) précède
les pixels dans chaque payload concerné ; la taille décompressée attendue
n'est jamais retransmise séparément, elle se déduit toujours des champs déjà
présents dans le même payload (`width * height * 2`, ou `width * height * 2
* frame_count` pour `SET_ANIMATION`).

- **App** (`packet_builder.dart`) : compression avec `package:archive`
  (`ZLibEncoder`) ; n'est utilisée que si elle réduit effectivement la taille
  transmise, sinon repli sur `format=0` (brut) — jamais de régression de
  taille pour un contenu peu compressible (ex. image très texturée/bruitée).
- **Firmware** (`ble_manager.cpp`) : décompression avec la lib `zlib_turbo`
  (voir `firmware/README.md`) avant transmission à `display_manager.cpp`, qui
  ne voit donc jamais de données compressées. Rejet (`NACK`, `ERR_DECOMPRESS`)
  si la décompression échoue ou ne produit pas exactement la taille attendue.
- Le gain est le plus net sur les bitmaps de texte (fond uni + quelques
  glyphes) mais reste généralement positif sur les images/GIFs importés
  (résolution de travail réduite, palettes limitées, voir §4.5).
- **`SET_ANIMATION` spécifiquement** : compresser toutes les frames en un
  seul flux (plutôt qu'indépendamment frame par frame comme avant) laisse
  zlib référencer les frames voisines dans sa fenêtre de compression — très
  efficace quand des frames consécutives se ressemblent (fond fixe, petite
  partie qui bouge, cas fréquent pour un GIF/sticker importé), ce qu'une
  compression par frame ne peut jamais exploiter. Une seule commande BLE
  pour toute l'animation réduit aussi d'autant le nombre d'allers-retours
  BLE (un accusé applicatif au lieu d'un par frame, voir §6.2).

> Le firmware reçoit l'image en basse résolution (grille de l'éditeur) et effectue l'**upscale nearest-neighbor** vers les 160x128 réels de l'écran ST7735S (orientation paysage), afin de limiter le volume de données transmis en BLE (une image plein format 160x128 en RGB565 pèse ~40 Ko, ce qui reste lourd pour une transmission fluide en BLE, surtout pour des animations multi-frames).

### 6.4 Batterie

- Le XIAO ESP32S3 n'a pas de fuel-gauge dédié, mais dispose d'un connecteur batterie LiPo + circuit de charge intégré. La lecture du niveau de batterie nécessite un pont diviseur de tension vers une broche ADC, câblé et calibré côté hardware/firmware.
- **À valider en phase de développement firmware** : si réalisable, exposer la valeur via le service Battery standard (`0x180F` / `0x2A19`). Sinon, l'app masque simplement l'indicateur de batterie et n'affiche que le statut de connexion.

## 7. Stack technique proposée (Flutter)

- **BLE** : `flutter_blue_plus` (scan, connexion, gestion MTU, write/notify)
- **State management** : Riverpod (proposition — à valider, ouvert à discussion)
- **Stockage local** : Hive (favoris, historique, animations custom)
- **Traitement image** : package `image` (redimensionnement, conversion RGB565), `image_picker` (import galerie/GIF)
- **Banque de GIF externe** : insertion clavier via `contentInsertionConfiguration` (Flutter) + pont natif Android (`MethodChannel` Kotlin) pour la lecture des URI `content://`
- **Icône d'app** : `flutter_launcher_icons` avec l'asset panda fourni
- **Typographie** : police Quicksand embarquée localement (`assets/fonts/`, licence SIL OFL), déclarée nativement via `pubspec.yaml` — pas de dépendance réseau

## 8. Roadmap proposée

**Phase 1 — MVP**
- Connexion BLE (scan, appairage, reconnexion auto, statut de connexion)
- Texte défilant (réglages complets) + envoi
- Favoris (texte)

**Phase 2**
- Import image/GIF (galerie + banque externe)

**Phase 3**
- Éditeur pixel-art (multi-frames)

**Phase 4**
- Batterie (si faisable matériellement)
- Polish UI, historique complet

## 9. Points ouverts / risques

- **UUID GATT** : valeurs d'exemple à figer définitivement avec le développement du firmware.
- **Débit BLE** : à mesurer en conditions réelles pour calibrer la résolution max de travail de l'éditeur/import (40x32, 80x64, ou plus) sans dégrader l'expérience (temps d'envoi trop long).
- **Lecture batterie** : dépend d'un ajout matériel (pont diviseur) sur le XIAO ESP32S3, non garanti par défaut.
- **Rendu texte sur écran** : le texte est rendu en bitmap côté app (voir §6.3) plutôt que par des polices embarquées firmware — fidèle à l'aperçu par construction, au prix d'un payload BLE plus lourd pour les messages longs/grande taille de police en mode défilement (plafonné, voir `maxPayloadSize`).
- **Deux écrans SPI simultanés** : sujet firmware/hardware (bus SPI partagé ou non), sans impact direct sur l'app tant que le contrat `SCREEN` (gauche/droit/simultané/séquentiel) est respecté.
- **Mode séquentiel** : la convention départ/arrivée selon la direction (voir §6.3) est un choix documenté côté app, à valider/ajuster une fois le rendu réel testé sur le firmware — c'est le firmware qui implémente concrètement le rendu "bande continue" à travers les 2 écrans.
- **Insertion GIF clavier** : dépend du clavier utilisé (Gboard le supporte via `commitContent` ; certains claviers tiers peuvent ne pas l'implémenter, auquel cas seul l'import galerie reste disponible). Comportement à valider sur plusieurs claviers/appareils réels.
- **Refus ponctuel côté clavier** : le clavier peut, pour un GIF donné, décider lui-même (toast natif, hors contrôle de l'app) que l'insertion n'est pas supportée ici — la liste de types MIME acceptés a été élargie (`image/*` en plus des types explicites) pour limiter ces cas, mais un rejet natif du clavier ne peut pas toujours être intercepté côté app ; la galerie reste le filet de sécurité.
- **Résolution plein écran (160x128) en import** : disponible en option, mais une animation multi-frames à cette résolution peut représenter plusieurs centaines de Ko à transférer en BLE — à utiliser avec parcimonie tant que le débit réel n'est pas mesuré (voir point ci-dessus sur le débit BLE).
