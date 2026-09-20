# Hold

Ein Overlay für macOS, das die eigene Command- und Prompt-Library zeigt, solange man sie braucht.
⌘ allein 0,6 s halten öffnet das Panel, nochmal halten schließt es. Eine Zeile kopieren, fertig.

Kein Hotkey-Manager, kein Sync, keine Cloud — eine lokale JSON-Datei und ein Fenster.

## Installation

Die App ist nicht notariell beglaubigt (kein Apple-Developer-Programm). Sie wird lokal gebaut
und lokal signiert; ein fertiges Installationspaket gibt es nicht.

1. **Voraussetzungen**
   ```
   xcode-select --install
   brew install xcodegen
   ```
   Dazu Xcode 16 oder neuer und macOS 14 oder neuer.

2. **Bauen**
   ```
   git clone <repo-url> hold
   cd hold
   xcodegen generate
   xcodebuild -project Hold.xcodeproj -scheme Hold -configuration Release -derivedDataPath build build
   ```

3. **Installieren und starten**
   ```
   cp -R build/Build/Products/Release/Hold.app /Applications/
   open /Applications/Hold.app
   ```

Die App hat bewusst kein Dock-Icon (`LSUIElement`). Sie meldet sich nur mit einem ⌘-Symbol in der
Menüleiste.

## Signierung einrichten

Ohne weiteres Zutun signiert der Build **ad-hoc** („Sign to Run Locally"). Das baut und läuft,
hat aber einen Haken: Bei jedem Rebuild ändert sich der Code-Hash, und macOS behandelt die
Accessibility-Freigabe dann als veraltet — der Schalter steht auf „an", der Tap wird trotzdem nicht
erzeugt. Wer öfter baut, trägt deshalb eine eigene Team-ID ein.

1. **Team-ID auslesen.** Dafür braucht es ein Apple-Development-Zertifikat im Schlüsselbund; eine
   kostenlose Apple-ID genügt (Xcode → Settings → Accounts → Apple-ID hinzufügen →
   Manage Certificates → „+" → Apple Development).
   ```
   security find-certificate -c "Apple Development" -p | openssl x509 -noout -subject
   ```
   Ausgabe (gekürzt):
   ```
   subject=UID=…, CN=Apple Development: name@example.com (…), OU=ABCDE12345, O=…, C=US
   ```
   Die Team-ID ist der Wert hinter **`OU=`** — nicht der hinter `UID=` und nicht der in Klammern
   hinter dem `CN`.

2. **Lokale Konfiguration anlegen.** Die Datei liegt bewusst nicht im Repository und ist in
   `.gitignore` eingetragen:
   ```
   cat > Config/Signing.local.xcconfig <<'EOF'
   CODE_SIGN_STYLE = Automatic
   CODE_SIGN_IDENTITY = Apple Development
   DEVELOPMENT_TEAM = ABCDE12345
   EOF
   ```
   `ABCDE12345` durch die eigene ID aus Schritt 1 ersetzen.

3. **Neu erzeugen und bauen.**
   ```
   xcodegen generate
   xcodebuild -project Hold.xcodeproj -scheme Hold -configuration Release -derivedDataPath build build
   ```
   Kontrolle:
   ```
   codesign -dv --verbose=2 build/Build/Products/Release/Hold.app
   ```
   `TeamIdentifier` muss die eigene ID zeigen, nicht `not set`.

Wie das zusammenspielt: `Config/Signing.xcconfig` liegt im Repo und setzt die ad-hoc-Voreinstellung.
Seine letzte Zeile ist `#include? "Signing.local.xcconfig"` — das Fragezeichen macht den Include
optional, auf einem Rechner ohne diese Datei wird die Zeile stillschweigend übersprungen. Ist sie da,
überschreiben ihre Werte die Voreinstellung.

## Accessibility-Berechtigung erteilen

Hold hört das Halten der ⌘-Taste über einen CGEvent-Tap mit. Das verlangt die Berechtigung
**Bedienungshilfen**, sonst öffnet sich das Overlay nicht.

1. Beim ersten Start erscheint der System-Dialog. Auf „Systemeinstellungen öffnen" klicken.
2. Unter **Systemeinstellungen → Datenschutz & Sicherheit → Bedienungshilfen** den Schalter bei
   **Hold** einschalten.
3. Kein Neustart nötig: Die App prüft im Sekundentakt und installiert den Tap, sobald die
   Freigabe da ist.

Status prüfen: auf das ⌘-Symbol in der Menüleiste klicken. Die mittlere Zeile zeigt
`Bedienungshilfen: erteilt · Tap aktiv`. Steht dort `Tap inaktiv`, obwohl der Schalter an ist:
Eintrag in den Systemeinstellungen mit „−" entfernen und neu erteilen.

Events werden nie geschluckt — System-Shortcuts wie ⌘C, ⌘Tab und ⌘Space funktionieren unverändert.

## Bedienung

### Öffnen und schließen

| Aktion | Wirkung |
|---|---|
| ⌘ **allein** ≥ 0,6 s halten | Overlay öffnen bzw. schließen |
| ⌘ loslassen | nichts — das Panel bleibt offen |
| esc | Feld verlassen → Suche leeren → Panel schließen (in dieser Reihenfolge) |
| Klick außerhalb | Panel schließt |
| ⌘ + weitere Taste | schaltet **nicht** |

Beim Öffnen übernimmt das Panel den Tastaturfokus; beim Schließen geht er an die vorherige App zurück.

### Navigieren

| Taste | Wirkung |
|---|---|
| ↑ ↓ | Auswahl bewegen, über Gruppengrenzen hinweg |
| ← → | Reiter zyklisch wechseln |
| ⌘1 … ⌘9 | Reiter direkt; ab dem 10. Reiter gibt es kein Kürzel |
| Tippen | Suche über Beschreibung, Command und Reitername, live über alle Reiter |

Jeder Suchtreffer trägt links ein Badge mit seinem Reiter. Ohne Treffer erscheint „Nichts gefunden."
Suche leeren führt zurück zum vorherigen Reiter, Auswahl wieder auf Zeile 1.

### Kopieren

| Aktion | Wirkung |
|---|---|
| ⌘C oder ⌃C | kopiert den Command der Auswahl |
| Klick auf das Kopier-Icon | kopiert diese Zeile und wählt sie aus |

Der Button färbt sich blau mit Häkchen, in der Fußleiste steht „Kopiert" — bis zur nächsten Aktion.
⌘C mit markiertem Text in einem Eingabefeld kopiert wie gewohnt den markierten Text.

### Editieren

Beschreibung und Command sind direkt anklickbar und editierbar. Ein langer Command scrollt im
Fokus bis zum Zeilenende, in Ruhe wird er gekürzt. esc verlässt das Feld, ohne das Panel zu schließen.

„Eintrag hinzufügen" links unten legt eine leere Zeile am Ende der letzten Gruppe des aktiven
Reiters an, der Cursor steht sofort in der Beschreibung. Ein leerer Reiter nutzt die Gruppe „Allgemein".

### Umbenennen

**Doppelklick** auf einen Reiternamen oder einen Gruppentitel. Enter oder Klick nach außen
übernimmt, esc verwirft. Leere und bereits vergebene Namen werden abgelehnt, der alte Name bleibt.
Während einer Suche wird nicht umbenannt.

### Sortieren

Alles per Drag, ein blauer Strich zeigt die Einfügestelle:

- **Zeile** auf eine andere Zeile ziehen — innerhalb der Gruppe oder in eine andere Gruppe.
- **Zeile** auf einen Gruppentitel ziehen — ans Ende dieser Gruppe.
- **Gruppentitel** auf einen anderen ziehen — der ganze Block wandert mit.
- **Reiter** auf einen anderen ziehen — die ⌘-Kürzel folgen der neuen Reihenfolge.

Mit „+" rechts in der Reiterleiste entsteht ein neuer Reiter, mit „Gruppe hinzufügen" unter der
letzten Gruppe eine neue Gruppe. Beide starten direkt im Umbenennen-Modus.

Bei aktiver Suche ist kein Drag möglich — die flache Trefferliste hat keine gültige Zielposition.

### Löschen und rückgängig machen

| Aktion | Wirkung |
|---|---|
| ⌫ | löscht die ausgewählte Zeile |
| Mülleimer bei Hover auf einer Zeile | dasselbe |
| × am Gruppentitel | löscht die Gruppe samt ihrer Einträge |
| × am Reiter | löscht den Reiter samt allen Einträgen |
| **⌘Z** | macht das letzte Löschen rückgängig |

Nach dem Löschen steht „Gelöscht · ⌘Z" in der Fußleiste. Das Undo hat **eine** Ebene: Jede andere
Aktion — Auswahl, Kopieren, Suche, Sortieren — verwirft es.

Auch der letzte Reiter lässt sich löschen. Null Reiter sind ein gültiger Zustand; das Overlay zeigt
dann nur Suchzeile, „+" und Fußleiste.

Gelöscht wird nicht, solange etwas im Suchfeld steht, ein Eingabefeld den Fokus hat oder eine
Umbenennung läuft.

## Wo die Library liegt

```
~/Library/Application Support/Hold/library.json
```

Beim ersten Start wird sie aus der mitgelieferten `Resources/seed.json` erzeugt. Die Datei ist
lesbares JSON und darf von Hand bearbeitet werden — **bei geschlossener App**, denn Hold liest sie
nur beim Start und überschreibt sie beim Schließen des Overlays.

Ist die Datei beschädigt, startet Hold mit leerer Library und **schreibt nicht** — die Datei bleibt
unangetastet. Den Grund nennt das Log:

```
/usr/bin/log stream --predicate 'subsystem == "com.fabi2418.hold"' --info --style compact
```

`log` ist auch ein zsh-Builtin, deshalb der absolute Pfad.

### Bestehende library.json aus der Vorgängerversion übernehmen

Die App hieß bis v1.0 `Cheatsheet`; ihre Daten lagen entsprechend woanders. Vor dem ersten Start
von Hold:

```
mkdir -p ~/Library/Application\ Support/Hold
cp ~/Library/Application\ Support/Cheatsheet/library.json \
   ~/Library/Application\ Support/Hold/library.json
```

Danach Hold starten — die Einträge sind da, ein neuer Seed wird nicht geschrieben. Beide
Dateiformate werden gelesen: das alte flache Array ebenso wie das aktuelle Objekt aus `tabs` und
`items`. Beim ersten Speichern konvertiert Hold auf das aktuelle Format.

Der alte Ordner kann danach weg:
```
rm -r ~/Library/Application\ Support/Cheatsheet
```

> Mit dem Namen ändert sich auch die Bundle-ID. Die Accessibility-Freigabe der Vorgängerversion
> gilt deshalb **nicht** weiter und muss für Hold neu erteilt werden.

## Build aus dem Quellcode

```
xcodegen generate                                    # Hold.xcodeproj aus project.yml erzeugen
xcodebuild -project Hold.xcodeproj -scheme Hold \
  -configuration Debug -derivedDataPath build build  # Debug-Build
xcodebuild -project Hold.xcodeproj -scheme Hold \
  -configuration Debug -derivedDataPath build test   # Tests
open build/Build/Products/Debug/Hold.app
```

`Hold.xcodeproj` ist erzeugt und liegt bewusst nicht im Repository — maßgeblich ist `project.yml`.

### Aufbau

| Pfad | Inhalt |
|---|---|
| `Sources/App` | Einstieg und `AppDelegate`: Menüleisten-Item, Berechtigung, Verdrahtung |
| `Sources/HotkeyEngine` | `CmdHoldMonitor`: CGEvent-Tap, 0,6-s-Timer, Umschaltlogik |
| `Sources/Overlay` | `OverlayPanel` (NSPanel, Fokus, Tasten), `OverlayView` (SwiftUI), `Theme` |
| `Sources/Model` | `LibraryItem`, `LibraryStore` (Laden, Speichern, Umbenennen, Löschen), `LibraryOrder` (Sortierlogik), `OverlayViewModel` |
| `Tests` | 133 Unit-Tests auf `Sources/Model` |
| `Config/Signing.xcconfig` | Signierung, ad-hoc als Voreinstellung |
| `Resources/seed.json` | Start-Library |
| `docs/` | Anforderungen, Paketplan, Referenzen, Re-Entry |

Die gesamte Logik liegt bewusst im Model und ist ohne laufende App testbar; `Sources/Overlay` und
`Sources/App` enthalten nur Darstellung und Verdrahtung.
