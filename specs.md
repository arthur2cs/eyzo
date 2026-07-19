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
- **Écrans** : 2x écran TFT SPI 2,4" ST7789V, résolution 240x320, couleur (RGB565)
- **Écran gauche / écran droit** : pilotés indépendamment, chacun peut afficher un contenu différent
- **Firmware ESP32** : pas encore développé — ce document définit le protocole de communication qu'il devra implémenter

## 3. Design / UI

- **Thème** : dark mode uniquement (pas de light mode), noir dominant / texte blanc
- **Style** : minimaliste, sobre, épuré — pas de couleurs superflues dans l'UI de l'app (les sélecteurs de couleur pour le contenu envoyé aux lunettes restent en couleur, eux)
- **Icône app** : panda mignon (asset fourni par l'utilisateur, à intégrer dans `assets/icon/`)
- **Typographie** : simple, lisible, cohérente avec un look tech sobre

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
- Sélection de l'écran cible : gauche / droit / les deux (contenu identique ou indépendant sur chaque écran)
- Réglages disponibles :
  - **Vitesse de défilement** (slider)
  - **Couleur du texte et couleur de fond** (color picker, rendu RGB565 sur les écrans)
  - **Police et taille de caractère** (liste de polices bitmap embarquées côté firmware, sélection par id)
  - **Direction / mode** : défilement gauche→droite, droite→gauche, statique, clignotant
- **Aperçu** dans l'app avant envoi (simulateur d'écran 240x320 miniature)
- Bouton "Envoyer" + bouton "Ajouter aux favoris"

### 4.3 Animations prédéfinies

- Bibliothèque d'animations intégrées à l'app (ex: cœur qui bat, yeux, smiley, etc.)
- Sélection de l'écran cible (gauche / droit / les deux)
- Aperçu animé avant envoi

### 4.4 Import d'image / GIF

- Import depuis la galerie du téléphone (image fixe ou GIF animé)
- Redimensionnement/conversion automatique vers la résolution de travail (voir §4.5) avant transfert
- Aperçu (recadrage si nécessaire) avant envoi
- Sélection de l'écran cible

### 4.5 Éditeur pixel-art

- Grille de dessin en **basse résolution** (ex: 32x42 ou 64x64, configurable) — l'app fait l'**upscale** (nearest-neighbor) pour remplir l'écran 240x320 réel, à la fois pour l'aperçu app et pour le rendu final sur les lunettes
- Outils : pixel, ligne, remplissage (bucket), gomme, palette de couleurs
- Gestion multi-frames : ajouter / dupliquer / supprimer une frame, réglage du délai entre frames (animation image par image)
- Aperçu animé en direct dans l'app
- Sauvegarde en favoris, envoi vers écran gauche / droit / les deux

### 4.6 Favoris & historique

- Bibliothèque locale de contenus sauvegardés (textes, animations importées/dessinées, images)
- Réutilisation en un tap (renvoyer, dupliquer, éditer, supprimer)
- Stockage **local uniquement** sur le téléphone (pas de compte, pas de cloud) — base de données locale embarquée (ex: Hive)

### 4.7 Paramètres

- Gestion de l'appareil appairé (info, oublier, reconnecter)
- À propos / version de l'app

## 5. Architecture applicative (écrans Flutter)

1. **Accueil / Dashboard** — statut de connexion, batterie, accès rapide aux 4 modes de contenu, dernier contenu envoyé
2. **Connexion** — scan BLE, appairage, gestion de l'appareil
3. **Texte** — composition + réglages + aperçu + envoi
4. **Animations** — bibliothèque de presets + aperçu + envoi
5. **Import** — sélection galerie + aperçu/recadrage + envoi
6. **Éditeur pixel-art** — canvas, outils, gestion de frames, aperçu, envoi
7. **Favoris / Historique** — liste, actions rapides
8. **Paramètres**

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
| 1 | `SCREEN` | Écran cible : `0x00` gauche, `0x01` droit, `0x02` les deux |
| 2 | `SEQ` | Index du chunk courant (uint16 LE) |
| 2 | `TOTAL` | Nombre total de chunks pour ce contenu (uint16 LE) |
| 2 | `LEN` | Longueur du payload dans ce chunk (uint16 LE) |
| N | `PAYLOAD` | Données (voir formats par commande) |
| 1 | `CHK` | Checksum (XOR ou CRC8 des octets précédents) |

### 6.3 Commandes

| CMD | Nom | Description |
|---|---|---|
| `0x01` | `SET_TEXT` | Envoi d'un texte défilant (non chunké en général, texte court) |
| `0x02` | `SET_STATIC_IMAGE` | Envoi d'une image statique (chunké) |
| `0x03` | `SET_ANIMATION_FRAME` | Envoi d'une frame d'animation (chunké, répété par frame) |
| `0x04` | `CLEAR_SCREEN` | Efface l'écran cible |
| `0x05` | `PING` | Keep-alive |
| `0x06` | `GET_STATUS` | Demande de statut (batterie, connexion écrans) |

#### Payload `SET_TEXT`

| Octets | Champ |
|---|---|
| 1 | `font_id` |
| 1 | `size` |
| 2 | `color_fg` (RGB565 LE) |
| 2 | `color_bg` (RGB565 LE) |
| 1 | `speed` (niveau 1–10) |
| 1 | `direction` (0=gauche, 1=droite, 2=statique, 3=clignotant) |
| 2 | `text_len` (uint16 LE) |
| N | texte UTF-8 |

#### Payload `SET_STATIC_IMAGE` / `SET_ANIMATION_FRAME`

| Octets | Champ |
|---|---|
| 1 | `width` (résolution de travail, ex: ≤ 64) |
| 1 | `height` |
| 1 | `frame_index` (uniquement pour animation) |
| 1 | `total_frames` (uniquement pour animation) |
| 2 | `frame_delay_ms` (uniquement pour animation) |
| 2 | `pixel_len` |
| N | pixels RGB565 (row-major), répartis sur plusieurs chunks selon `SEQ`/`TOTAL` |

> Le firmware reçoit l'image en basse résolution (grille de l'éditeur) et effectue l'**upscale nearest-neighbor** vers les 240x320 réels de l'écran ST7789V, afin de limiter drastiquement le volume de données transmis en BLE (une image plein format 240x320 en RGB565 pèse ~150 Ko, ce qui est trop lourd pour une transmission fluide en BLE, surtout pour des animations multi-frames).

### 6.4 Batterie

- Le XIAO ESP32S3 n'a pas de fuel-gauge dédié, mais dispose d'un connecteur batterie LiPo + circuit de charge intégré. La lecture du niveau de batterie nécessite un pont diviseur de tension vers une broche ADC, câblé et calibré côté hardware/firmware.
- **À valider en phase de développement firmware** : si réalisable, exposer la valeur via le service Battery standard (`0x180F` / `0x2A19`). Sinon, l'app masque simplement l'indicateur de batterie et n'affiche que le statut de connexion.

## 7. Stack technique proposée (Flutter)

- **BLE** : `flutter_blue_plus` (scan, connexion, gestion MTU, write/notify)
- **State management** : Riverpod (proposition — à valider, ouvert à discussion)
- **Stockage local** : Hive (favoris, historique, animations custom)
- **Traitement image** : package `image` (redimensionnement, conversion RGB565), `image_picker` (import galerie/GIF)
- **Icône d'app** : `flutter_launcher_icons` avec l'asset panda fourni

## 8. Roadmap proposée

**Phase 1 — MVP**
- Connexion BLE (scan, appairage, reconnexion auto, statut de connexion)
- Texte défilant (réglages complets) + envoi
- Favoris (texte)

**Phase 2**
- Animations prédéfinies
- Import image/GIF

**Phase 3**
- Éditeur pixel-art (multi-frames)

**Phase 4**
- Batterie (si faisable matériellement)
- Polish UI, historique complet

## 9. Points ouverts / risques

- **UUID GATT** : valeurs d'exemple à figer définitivement avec le développement du firmware.
- **Débit BLE** : à mesurer en conditions réelles pour calibrer la résolution max de travail de l'éditeur/import (32x42, 64x64, ou plus) sans dégrader l'expérience (temps d'envoi trop long).
- **Lecture batterie** : dépend d'un ajout matériel (pont diviseur) sur le XIAO ESP32S3, non garanti par défaut.
- **Rendu texte sur écran** : le firmware devra embarquer les polices bitmap sélectionnables (font_id) — liste des polices à définir conjointement.
- **Deux écrans SPI simultanés** : sujet firmware/hardware (bus SPI partagé ou non), sans impact direct sur l'app tant que le contrat `SCREEN` (gauche/droit/les deux) est respecté.
