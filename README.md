# Loki

Eine quelloffene macOS-Menüleisten-App mit einer Sammlung **harmloser, vollständig reversibler** Streiche — von Rickrolls beim Surfen bis zu täuschend echten (aber gefälschten) System-Screens. Gesteuert über ein verstecktes Overlay per globalem Hotkey.

> Mac-first (Swift + AppleScript). Der Name „Loki“ ist plattform-neutral gewählt — eine spätere Windows-/Linux-Variante ist als Ziel vorgesehen.

---

## ⚠️ Einverständnis & verantwortungsvolle Nutzung

**Setze Loki ausschließlich auf Geräten ein, die dir gehören oder für die du die ausdrückliche Erlaubnis der besitzenden Person hast.**

- Alle Streiche sind **reversibel und nicht-destruktiv** — kein Datenverlust.
- **Kein** Abgreifen von Passwörtern, Daten oder Tastatureingaben. Keine heimliche Persistenz.
- Die **Panik-Taste `⌃⌥⌘P`** stoppt jederzeit alles und stellt den Originalzustand wieder her.
- Beim ersten Start musst du diesen Bedingungen aktiv zustimmen.

Heimliche Überwachung oder Streiche ohne Einverständnis sind nicht der Zweck dieses Projekts und können je nach Land rechtswidrig sein. Nutze es mit gesundem Menschenverstand und Respekt.

---

## Bauen

Voraussetzung: macOS 14+, Xcode (für die XCTest-Toolchain).

```bash
# Bauen & testen (Tests brauchen die Xcode-Toolchain)
swift build
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test

# Fertiges Loki.app erzeugen (Menüleisten-App, kein Dock-Icon)
./scripts/build-app.sh release
open build/Loki.app
```

### Gatekeeper-Hinweis
Die App ist nur ad-hoc signiert (nicht via Apple Developer ID notarisiert). Beim ersten Öffnen ggf.:

```bash
xattr -dr com.apple.quarantine build/Loki.app   # oder: Rechtsklick > Öffnen
```

---

## Benutzung

1. `Loki.app` starten — sie erscheint als Masken-Symbol in der Menüleiste.
2. Beim ersten Start dem Einverständnis zustimmen.
3. Overlay öffnen mit **`⌃⌥⌘L`** (oder Menüleisten-Icon → „Steuerung öffnen“).
4. Streich an-/ausschalten. Reversible Streiche zeigen einen Stopp-Knopf.
5. **`⌃⌥⌘P`** = PANIK: stoppt alles und stellt den Originalzustand wieder her.

### Berechtigungen
Beim ersten Auslösen fragt macOS nach Berechtigungen unter *Systemeinstellungen → Datenschutz & Sicherheit*:

| Berechtigung        | Wofür                                              |
|---------------------|----------------------------------------------------|
| Automatisierung     | Browser/Systemfunktionen via AppleScript steuern   |
| Bedienungshilfen    | Maus-/Tastatursimulation (für einige Streiche)     |
| Bildschirmaufnahme  | nur für den Wallpaper-Screenshot-Streich           |

---

## Modi (orchestrierte Abläufe)

Im Tab **Modi** startest du kuratierte „Flows", die mehrere Streiche zeitlich
gestaffelt zusammenspielen — und sich am Ende **immer selbst auflösen**:

| Modus | Tier | Was passiert |
|---|---|---|
| Kleine Spielereien | 1 (Sanft) | Sounds → Sprachausgabe → Rickroll → Auflösung |
| Irgendwas stimmt nicht | 2 (Unheimlich) | Fake-Mitteilungen, Geister-Sounds, Maus-Drift, Flackern, Rickroll → Auflösung |
| Die Heimsuchung | 3 (Heimsuchung) | **Companion** meldet sich in Notes, dann eskaliert alles → Auflösung |

Der `ModeRunner` erzwingt einen Reveal am Ende jedes Modus; **Panik** stoppt
einen laufenden Modus jederzeit und setzt alles zurück.

## Sicherheit by design

- **Einwilligungs-Gate** beim ersten Start, danach **transparentes Rechte-Onboarding**.
- **Auto-Auflösung**: optionaler Timer (in Minuten), nach dem Loki von selbst „Das war Loki" zeigt und alles zurücksetzt.
- **Panik ⌃⌥⌘P** + reversible, nicht-destruktive Streiche; kein Daten-/Passwort-Abgriff.
- Der **Companion** ist eine lokale Skript-Engine (mit Einsteckpunkt für ein späteres lokales LLM) und bleibt im Einwilligungs-/Reveal-Modell — kein verdecktes Manipulieren.

## Streich-Katalog (32 Streiche)

Jeder Streich hat eigene Einstellungen (per Schieberegler/Auswahl/Textfeld im
Overlay) und ist reversibel oder ein harmloser Einmal-Effekt.

**Browser**
- **Rickroll-Redirect** — leitet zufällige Tabs auf ein Video um (Wahrscheinlichkeit, Intervall, Ziel-URL, Browser).
- **Tab-Flut** — öffnet immer wieder Tabs mit zufälligen URLs (URLs, Anzahl, Intervall, Browser).
- **Auto-Neuladen** — lädt den aktiven Tab ständig neu (Intervall, Wahrscheinlichkeit).

**UI / Display**
- **Desktop-Icons verstecken** · **Bildschirm einfrieren** (Screenshot-als-Hintergrund) · **Hintergrundbild tauschen**
- **Bildschirm umdrehen**¹ · **Farben invertieren** · **Hell/Dunkel umschalten** (inkl. Flackern)
- **Dock-Chaos** (Position/Ausblenden/Riesen-Vergrößerung) · **Heiße Ecke** · **Riesen-Mauszeiger**
- **Zeitlupen-Animationen** · **Bildschirmschoner** · **App drängt sich vor**

**Audio & Stimme**
- **Zufällige Sprachausgabe** · **Lautstärke-Chaos** · **Sprechende Uhr** · **Geister-Sounds** · **Sprechende Zwischenablage**

**Tastatur & Maus**
- **Maus-Drift** · **Scroll-Richtung umkehren** · **Tastaturbelegung tauschen** · **Tasten-Wiederholung** · **Maus-Geschwindigkeit**

**Fake-System**
- **Fake-Benachrichtigungen** · **Fake-Systemdialog** · **Hacker-Terminal** · **Geister-Notiz** · **Geist im System (Companion)** · **Der Beobachter (Vision)** · **Auflösung**

> **Der Beobachter** reagiert live auf Aktivität („Beweg dich nicht weg", „Ich lese, was du tippst"). Alles ist **on-device & leichtgewichtig**: Maus-/App-/Tipp-Signale, optional lokale Apple-**Vision-OCR** (standardmäßig aus). **Nichts wird übertragen oder gespeichert**, die Tipp-Erkennung merkt nur *dass* getippt wird, **nie welche Taste** (kein Keylogger). Gedacht fürs höchste Tier (Modus „Die Heimsuchung").

¹ „Bildschirm umdrehen" benötigt [`displayplacer`](https://github.com/jakehilborn/displayplacer): `brew install displayplacer`.

> Hinweis: Einige `defaults`-basierte Streiche (Scroll-Richtung, Tasten-Wiederholung,
> Maus-Geschwindigkeit, Mauszeiger-Größe) greifen je nach macOS-Version erst nach
> erneuter An-/Abmeldung. „Fake-Systemdialog" und „Hacker-Terminal" fragen **keine**
> Eingaben ab — sie tun nichts mit dem, was getippt wird.

---

## Architektur

```
Sources/
  LokiCore/            # testbare Engine, Safety, Streich-Katalog (keine UI)
    Engine/            # PrankModule, PrankEngine, ScriptRunner, DefaultCatalog
    Safety/            # StateStore, ConsentStore, GlobalHotkey
    Pranks/            # je ein Streich-Modul (run/undo)
  Loki/                # SwiftUI-Menüleisten-App auf Basis von LokiCore
Tests/LokiCoreTests/   # Engine-/StateStore-Unit-Tests
scripts/build-app.sh   # wrappt das Binary in Loki.app (LSUIElement, Info.plist)
```

**Sicherheits-Kern:** Jeder zustandsändernde Streich sichert den Originalwert im
`StateStore` (auf Disk persistiert, übersteht Neustarts) und stellt ihn im
`undo` wieder her. `PanicManager`/Panik-Hotkey ruft `undo` für alle aktiven
Streiche auf — best-effort, ein Fehler blockiert die anderen nicht.

### Einen Streich hinzufügen
1. Neue Klasse in `Sources/LokiCore/Pranks/` anlegen, die `PrankModule` erfüllt.
2. In `DefaultCatalog.swift` (`allPranks()`) registrieren.
3. Einstellungen deklarativ über `var settings: [PrankSetting]` angeben — die UI
   baut die Controls automatisch. Werte im Code via `context.config` lesen.
4. Zustandsänderungen über `context.store.saveOriginal` / `consumeOriginal`
   sichern, damit Panik & Undo funktionieren.

---

## Roadmap

- **Phase 1:** Engine, Safety, Overlay, Starter-Streiche. ✅
- **Phase 2:** Einstellungs-Framework + Streiche mit Settings-UI & Suche. ✅
- **Phase 3:** Modi/Tiers + Companion, Auto-Auflösung, Rechte-Onboarding, neugestaltete UI. ✅
- **Phase 4 (später):** Scheduler (Zufall/Events), Fake-Vollbild-Screens (eigenes Fenster), optionales lokales LLM für den Companion, opt-in Remote-Steuerung — transparent, für die bespaßte Person sicht- und abschaltbar.

---

## Lizenz

MIT — siehe [LICENSE](LICENSE).
