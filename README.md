# Enterprise Dokumentation: Unreal Engine Mobile/PC VR/XR Pixel Streaming Infrastruktur (Hybrid)

**Version:** 3.1.0  
**Plattform:** Ubuntu 24.04 LTS  
**Zielgruppe:** Intranet & Internet setup! High Level PC (NVIDIA / AMD GPU ! ) + Unreal Engine CAD Project --stream--> Server (LTS) Streaming Infrastruktur --stream--> Webbrowser
**Status:** Produktionsreif (Production Ready)

<video src="UEPS1.mp4" controls width="640" />

---

## Inhaltsverzeichnis

1. [Einleitung](#1-einleitung)
2. [Architektur-Übersicht](#2-architektur-übersicht)
3. [VR/XR Besonderheiten](#3-vrxr-besonderheiten)
4. [Voraussetzungen](#4-voraussetzungen)
5. [Installation (Das Setup-Skript)](#5-installation-das-setup-skript)
6. [Unreal Engine Projekt Konfiguration](#6-unreal-engine-projekt-konfiguration)
7. [Betrieb & Wartung](#7-betrieb--wartung)
8. [Sicherheit & Hardening](#8-sicherheit--hardening)
9. [Troubleshooting](#9-troubleshooting)
10. [Anhang: Bash Script](#10-anhang-bash-script)

---

## 1. Einleitung

Willkommen zur Dokumentation der **Unreal Engine Pixel Streaming Infrastruktur**. Dieses System ermöglicht es, hochqualitative 3D-Anwendungen (Simulationen, VR, XR) direkt im Webbrowser auszuführen, ohne dass die Endnutzer eine Software installieren müssen.

### Warum dieses System?

- **Für Einsteiger:** Du musst nur wenige Befehle eingeben. Das Skript erledigt den Rest.
- **Für Profis:** Das System folgt Best-Practices (Sicherheit, Isolation, SSL, Systemd).
- **Flexibilität:** Es unterstützt zwei Betriebsmodi (Cloud Rendering oder Hybrid) und kann sowohl normale Bildschirm-Anwendungen als auch VR/XR-Erlebnisse streamen.

### Ziel dieses Dokuments

Dieses Dokument dient als **README.md** für dein Projekt. Es erklärt nicht nur _wie_, sondern auch _warum_ bestimmte Schritte notwendig sind. Es ist so geschrieben, dass es von Auszubildenden verstanden, aber von IT-Administratoren abgenickt werden kann. **Bilingual: Deutsch / English.**

---

## 2. Architektur-Übersicht

Das System bietet zwei Betriebsmodi. Wähle den Modus, der zu deiner Hardware und deinem Use-Case passt.

### Modus 1: Cloud Rendering (Full Server)

_Die Unreal Engine läuft auf dem Server._

- **Voraussetzung:** Server muss eine **NVIDIA oder AMD GPU** haben.
- **Vorteil:** Beste Performance für Nutzer, keine lokale Hardware nötig, sicher (Code bleibt auf Server).
- **Nachteil:** Höhere Serverkosten (GPU-Instanzen sind teuer).
- **Geeignet für:** Öffentliche Angebote, VR/XR, hohe Sicherheitsanforderungen.

### Modus 2: Hybrid Rendering (Signaling Only)

_Die Unreal Engine läuft auf einem lokalen PC im Büro, der Server vermittelt nur._

- **Voraussetzung:** Server braucht **keine GPU**. Lokaler PC muss stark sein.
- **Vorteil:** Günstige Serverkosten, Nutzung vorhandener Büro-Hardware.
- **Nachteil:** Höhere Latenz, abhängig vom Büro-Upload, Firewall-Konfiguration im Büro nötig.
- **Geeignet für:** Interne Tests, Entwicklung, Demos mit geringer Nutzerzahl.

| Feature             | Modus 1 (Cloud)                 | Modus 2 (Hybrid)                     |
| :------------------ | :------------------------------ | :----------------------------------- |
| **GPU auf Server**  | ✅ NVIDIA/AMD erforderlich      | ❌ Nicht nötig                       |
| **Latenz**          | 🟢 Niedrig (Server nah am User) | 🟠 Hoch (Abhängig vom Büro-Internet) |
| **Kosten**          | 🔴 Hoch (GPU Miete)             | 🟢 Niedrig (Standard VPS)            |
| **VR Tauglichkeit** | ✅ Empfohlen                    | ⚠️ Nur bei sehr gutem Büro-Upload    |

---

## 3. VR/XR Besonderheiten

Dieses Setup unterstützt explizit **Virtual Reality (VR)** und **Extended Reality (XR)** über WebXR.

### Technische Anforderungen für VR

VR ist deutlich anspruchsvoller als normale Bildschirm-Anwendungen.

1. **Framerate:** Während 30-60 FPS für Bildschirme reichen, benötigt VR **mindestens 90 FPS**, um Übelkeit (Motion Sickness) zu vermeiden.
2. **Latenz:** Die Verzögerung zwischen Kopfbewegung und Bildänderung muss **unter 20-30ms** liegen.
3. **Bandbreite:** VR benötigt Stereo-Bilder (zwei Augen). Rechne mit **50-100 Mbps pro Nutzer**.
4. **GPU Last:** VR Rendering ist ca. 2x so teuer wie Flat-Screen Rendering.

### Empfehlung

- Für **VR-Projekte** wird dringend **Modus 1 (Cloud Rendering)** empfohlen, um Latenz zu minimieren.
- Stelle sicher, dass der Server-Standort geografisch nah an den Nutzern liegt (z.B. Server in Frankfurt für Nutzer in DACH).

---

## 4. Voraussetzungen

Bevor du startest, prüfe folgende Punkte:

### Hardware & Server

- [ ] **VPS / Server:** Ubuntu 24.04 LTS installiert.
- [ ] **GPU (für Modus 1):** NVIDIA oder AMD Karte installiert & Treiber vorbereitet (AMD: `mesa-vulkan-drivers` empfohlen).
- [ ] **RAM:** Mindestens 8 GB (besser 16 GB+).
- [ ] **CPU:** Mindestens 4 Kerne.

### Netzwerk & Domain

- [ ] **Domain:** Eine eigene Domain (z.B. `stream.deine-firma.de`).
- [ ] **DNS:** Ein **A-Record** zeigt auf die IP-Adresse des Servers.
- [ ] **Ports:** Die Ports **80 (HTTP)**, **443 (HTTPS)** und **22 (SSH)** müssen im Firewall-Panel des Hosters offen sein.

### Software (Lokal)

- [ ] **Unreal Engine:** Projekt muss gepackt sein (Linux Server Build für Modus 1, Windows/Linux Client für Modus 2).
- [ ] **SSH Client:** Zugriff auf den Server (z.B. Terminal, PuTTY, PowerShell).

---

## 5. Installation (Das Setup-Skript)

Wir verwenden ein automatisiertes Bash-Skript **[install_pixelstreaming.sh](./install_pixelstreaming.sh)**. Es installiert alle Abhängigkeiten (Nginx, Node.js, SSL), richtet die Benutzer ein und fragt bilingual (DE/EN) mit Validierung nach Modus, GPU-Typ, Binary-Name und VR-Support.

### Schritt 1: Skript erstellen

SSH zum Server:

```bash
nano install_pixelstreaming.sh
```

Kopiere aus **[install_pixelstreaming.sh](./install_pixelstreaming.sh)**. Speichere (`Ctrl+O`, Enter, `Ctrl+X`).

### Schritt 2: Ausführbar machen

```bash
chmod +x install_pixelstreaming.sh
```

### Schritt 3: Starten

```bash
sudo ./install_pixelstreaming.sh
```

### Schritt 4: Eingaben (bilingual, validiert)

1. Sprache: DE/EN
2. Domain
3. Email
4. Modus: 1 Cloud / 2 Hybrid
5. GPU (Cloud): 1 NVIDIA / 2 AMD / 3 CPU
6. Binary-Name (Cloud): z.B. `MeinProjekt.sh`
7. VR: 1 Nein / 2 Ja

### Schritt 5: Dateien hochladen

- Modus 1: UE-Build nach `/home/uestream/ue_gateway/Build/`
- Alle: SignalingWebServer nach `/home/uestream/ue_gateway/SignalingWebServer/`

---

## 6. Unreal Engine Projekt Konfiguration

### 6.1 Plugins

`Edit > Plugins`: Pixel Streaming, OpenXR/WebXR (VR).

### 6.2 Settings

| Einstellung       | Pfad                    | Wert |
| :---------------- | :---------------------- | :--- |
| Platforms → Linux | Server Target           |
| Virtual Reality   | OpenXR, Enable VR: True |
| Pixel Streaming   | bEnableWebXR: True      |
| Pixel Streaming   | H.264 Encoder           |

### 6.3 Launch Params

Flat: `-PixelStreamingURL=ws://domain:8888 -ForceRes=1920x1080 -Windowed`

VR: `-VR -PixelStreamingURL=ws://domain:8888 -PixelStreamingEncoderCodec=H264 -PixelStreamingBitrate=50000 -PixelStreamingFramerate=90 -UseVulkan`

---

## 7. Betrieb & Wartung

Status: `sudo systemctl status ue-signaling` / `ue-app`

Logs: `sudo journalctl -u ue-signaling -f`

Restart: `sudo systemctl restart ue-signaling nginx`

Updates: `sudo apt install unattended-upgrades && sudo dpkg-reconfigure unattended-upgrades`

---

## 8. Sicherheit & Hardening

- SSH: PasswordAuthentication no
- UFW: Only 80/443/22
- SSL: Auto Let's Encrypt
- User: uestream (non-root)
- Headers: Permissions-Policy for WebXR

---

## 9. Troubleshooting

| Problem         | Ursache        | Lösung                                                  |
| :-------------- | :------------- | :------------------------------------------------------ |
| 502 Bad Gateway | Signaling down | `systemctl status ue-signaling`                         |
| Schwarzes Bild  | GPU Driver     | NVIDIA: `nvidia-smi`, AMD: `vulkaninfo`                 |
| Timeout         | Firewall       | `ufw status`                                            |
| VR Button fehlt | Browser        | Chrome/Edge                                             |
| Hohe Latenz     | Location       | Server nah (Frankfurt)                                  |
| SSL Error       | DNS            | Warte 10min                                             |
| No Vulkan AMD   | Driver         | `apt install mesa-vulkan-drivers firmware-amd-graphics` |

---

## 10. Anhang: Bash Script

Siehe **[install_pixelstreaming.sh](./install_pixelstreaming.sh)** (bilingual, AMD-ready).

---

## Historie

| Version | Datum      | Autor       | Änderung                       |
| ------- | ---------- | ----------- | ------------------------------ |
| 1.0     | 05.03.2026 | Besem Maazi | Initial Projects               |
| 3.0     | 06.03.2026 | Besem Maazi | Pixel Streaming Base           |
| 3.1.0   | 06.03.2026 | Cline       | AMD, Bilingual DE/EN, UX, Link |

**Ende DE**
