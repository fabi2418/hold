# 05 · Re-Entry — Stand nach P9

Für eine frische Session: Wo das Projekt steht, was fertig ist, was offen ist.

## Kurzfassung

**Hold** (bis P7: `Cheatsheet`) ist eine macOS-Menüleisten-App ohne Dock-Icon. ⌘ allein 0,6 s
halten schaltet ein Overlay um, das eine Command-Library in Reitern und Gruppen zeigt. Kopieren
ist die Hauptaktion; Editieren, Umbenennen, Sortieren und Löschen sind vollständig.

Alle MUSS-Anforderungen M1–M11 sind umgesetzt. **133 Unit-Tests, alle grün.**

## Stack

Swift 5, SwiftUI plus AppKit, macOS 14.0, XcodeGen (`project.yml`, kein eingechecktes `.xcodeproj`),
Signierung mit Apple Development, Team `9ZV3YZX4YG`, Bundle-ID `com.fabi2418.hold`.

```
xcodegen generate
xcodebuild -project Hold.xcodeproj -scheme Hold -configuration Debug -derivedDataPath build test
```

## Architektur in einem Absatz

`AppDelegate` hält `LibraryStore`, `OverlayViewModel`, `OverlayPanel` und `CmdHoldMonitor`.
Der Monitor besitzt den CGEvent-Tap und den Umschaltzustand; das Panel besitzt Fokus und
Tastenauswertung über einen lokalen `NSEvent`-Monitor; `OverlayViewModel` besitzt Reiter, Suche,
Auswahl, Fokusziel, Kopier-Feedback und Undo; `LibraryStore` besitzt Datei, Einträge und
Reiterliste; `LibraryOrder` und `OverlayList` sind zustandslose, reine Funktionen. Alles
Testbare liegt in `Sources/Model` — das Test-Target kompiliert genau diesen Ordner und startet
die App nie.

## Paketstand

| Paket | Commit | Inhalt |
|---|---|---|
| P0 | `90c65e1` | Walking Skeleton: Menüleiste, Event-Tap, leeres Panel |
| P1 | `774b0ea` | Datenmodell, JSON-Persistenz, Seed, atomarer Write |
| P2 + P3 | `0db5361` | Overlay-UI nach Prototyp, Suche, Tastaturnavigation |
| P4 | `ac06fac` | Kopieren via NSPasteboard, Feedback nach SCR-04 |
| P5 | `6ca3951` | Inline-Editieren, Eintrag anlegen |
| P6/K3 | `efed285` | Reiter und Gruppen umbenennen |
| P8 + P9 | `8831bb6` | Sortieren per Drag, modulare Reiter, Löschen mit Undo |
| P7 | offen | Release: Umbenennung auf Hold, README, Tag v1.0 |

## Was v1.1 gebracht hat (P8 und P9)

- **Sortieren per Drag:** Zeilen innerhalb und zwischen Gruppen, Gruppen als Block, Reiter
  untereinander. Drop-Indikator als 2-pt-Strich.
- **Modulare Reiter:** anlegen, löschen, umbenennen, umsortieren. ⌘-Kürzel folgen der Reihenfolge,
  ab dem 10. Reiter keins mehr.
- **Gruppen:** anlegen, löschen, umbenennen.
- **Löschen mit Undo:** Zeile per ⌫ oder Hover-Knopf, Gruppe und Reiter per ×, jeweils samt Inhalt.
  ⌘Z macht das letzte Löschen rückgängig, eine Ebene.
- **Leerer Zustand:** 0 Reiter und 0 Einträge sind gültig, `activeTab` ist dann `""`.

## Entscheidungen, die man kennen muss

1. **Die Reihenfolge des `items`-Arrays IST die Ordnung.** Kein Ordnungsfeld, keine
   Formatänderung. Gruppenreihenfolge = erstes Auftreten. Folge: Eine **leere Gruppe** kann nicht
   gespeichert werden und lebt nur zur Laufzeit (`LibraryStore.emptyGroups`). Ein leerer **Reiter**
   überlebt, weil `tabs` seit K3 im Format steht.
2. **Dateiformat** ist `{"tabs": [...], "items": [...]}`. Das alte flache Array wird beim Laden
   weiterhin akzeptiert; beim ersten Speichern wird konvertiert.
3. **Toggle statt Halten.** M1 wurde geändert: ⌘ loslassen tut nichts.
4. **Das Panel nimmt den Fokus.** Ohne Key-Window keine Texteingabe für Suche und Editieren.
   Beim Schließen geht der Fokus an die vorherige App zurück.
5. **esc-Leiter:** Umbenennung abbrechen → Zeilenfeld verlassen → Suche leeren → Panel schließen.
   Die Entscheidung steckt testbar in `OverlayViewModel.escapeAction()`.
6. **Undo ist ein Zustands-Schnappschuss**, keine Umkehrfunktion je Operation.
7. **Der Pasteboard-Zugriff ist eine injizierbare Closure**, damit Tests die Zwischenablage nicht
   überschreiben.

## Fallen, die schon zugeschnappt sind

- **Verschachtelte `ObservableObject`s leiten nicht weiter.** `OverlayViewModel` reicht
  `store.objectWillChange` von Hand durch. Ohne das zeichnet die View bei Datenänderungen nicht neu.
- **Aus einem `onChange` kein `@Published` schreiben.** Die Benachrichtigung verpufft mitten im
  Update-Zyklus. Deshalb ist `focusedField` bewusst **kein** `@Published`.
- **`strokeBorder` über einem leeren `.frame` ist für Klicks ein Loch.** Ohne `.contentShape` ist
  nur das gezeichnete Glyph treffbar.
- **`os.Logger` zensiert interpolierte Strings** zu `<private>`. Diagnosewerte brauchen
  `privacy: .public`.
- **`log` ist ein zsh-Builtin** — immer `/usr/bin/log` schreiben.
- **Ad-hoc-Signierung bricht die Accessibility-Freigabe** bei jedem Rebuild. Deshalb ein
  Development-Zertifikat statt `CODE_SIGN_IDENTITY: "-"`.

## Offene Punkte

**Aus P6 (KANN, nicht blockierend):**
- K1 Haltedauer 0,4–0,8 s einstellbar
- K2 Start bei Login (SMAppService)
- Panel auf dem Bildschirm mit dem Mauszeiger zentrieren (Edge Case aus 01)
- App-Icon

**Aus der Iterationsliste (`docs/01_REQUIREMENTS.md`):**
- Scan von `~/.claude/skills/*/SKILL.md` in den Claude-Reiter
- Einfügen statt nur Kopieren (⌘V simulieren)
- Export/Import der Library
- Sichtbarer Hinweis im Overlay, wenn `library.json` nicht geladen werden konnte
- Menü-Eintrag „Overlay öffnen (Test)" kollidiert mit dem Schließen bei Fokusverlust

**Bekannte Rauheiten:**
- Kein Auto-Scroll, wenn man beim Ziehen an den Rand der Liste kommt.
- Editieren während einer Suche kann die Zeile aus der Trefferliste fallen lassen, während man tippt.
- Zwei reine Diagnose-Logzeilen (esc-Pfad, Panel-Fokus) sind noch drin.

## Arbeitsweise in diesem Repo

Ein Paket pro Auftrag, Reihenfolge nach `docs/02_PAKETPLAN.md`, jedes Paket endet mit einer
Abnahme-Checkliste. Kein Commit ohne manuelle Abnahme. Bugs zuerst mit einem **roten Test**
belegen, dann fixen — so sind die beiden P5-Bugs und der P8-Bug gefunden worden.
