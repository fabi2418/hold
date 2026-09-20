# 02 · Paketplan — Reihenfolge fix, ein Paket pro Auftrag

Regel: Ein Paket gilt als fertig, wenn jede Checkbox der Abnahme von Fabian manuell bestätigt wurde. Erst dann Freigabe für Commit und nächstes Paket. P0 zuerst — es enthält das einzige Risiko, das das Projekt kippen kann.

## P0 · Walking Skeleton (Risiko-Check)
Repo + XcodeGen-Setup, Menu-Bar-App ohne Dock-Icon, CGEvent-Tap auf flagsChanged, 0,6-s-Timer, leeres NSPanel, Accessibility-Prompt.
Abnahme:
- [ ] `xcodegen generate` und Debug-Build laufen fehlerfrei auf Fabians MacBook
- [ ] Erststart zeigt den Accessibility-System-Prompt; nach Erteilen funktioniert der Tap ohne Neustart oder mit klarer Anweisung
- [ ] ⌘ allein 0,6 s halten → leeres Panel erscheint; loslassen → verschwindet
- [ ] ⌘C, ⌘Tab, ⌘Space öffnen das Panel NICHT und funktionieren systemweit normal
- [ ] Menu-Bar-Menü: Overlay öffnen (Test), Berechtigungsstatus, Beenden

## P1 · Datenmodell + Persistenz
LibraryItem/LibraryStore (Codable, ObservableObject), JSON-Datei mit atomarem Write, Seed-Library aus dem Prototyp, Unit-Tests für Laden/Speichern/Filter/Gruppierung.
Abnahme:
- [ ] `xcodebuild test` grün; Tests decken Filter (label/desc/cat), Gruppen-Reihenfolge, Index-Klemmung ab
- [ ] Erststart erzeugt `library.json` mit Seed; manueller Edit der Datei erscheint nach App-Neustart

## P2 · Overlay-UI statisch
SwiftUI-View nach Prototyp: Suchfeldzeile, 4 Reiter mit Zähler + ⌘-Badges, Kopfzeile, Gruppen, Zeilen (Beschreibung/Command/Copy-Button), Footer. Noch ohne Suche/Tastatur.
Abnahme:
- [ ] Seite an Seite mit dem Artifact: Layout, Abstände, Farben erkennbar gleich (helles Panel, Monospace-Commands)
- [ ] Alle 4 Reiter per Klick wechselbar, Gruppen korrekt, lange Texte mit Ellipsis

## P3 · Suche + Tastaturnavigation
Globale Suche mit Badges und Empty State; ↑↓ mit Mitscrollen, Start bei Zeile 1, ⌘1–4, ←→ zyklisch, esc-Verhalten in Feldern.
Abnahme:
- [ ] Jede Zeile der M6/M7-Anforderungen einzeln durchgetestet (Checkliste aus 01_REQUIREMENTS.md abhaken)
- [ ] Suche tippen → Badges; leeren → vorheriger Reiter, Auswahl Zeile 1; Fantasie-Query → „Nichts gefunden."

## P4 · Kopieren + Feedback
NSPasteboard-Write, Button-Feedback, Status „Kopiert", Fehlerpfad ohne Crash.
Abnahme:
- [ ] ⌘C und Klick kopieren die Auswahl; Einfügen in TextEdit zeigt exakt `label`
- [ ] Feedback verschwindet bei nächster Aktion; ⌘C im Suchfeld mit markiertem Text kopiert den Text (nativ)

## P5 · Editieren + Eintrag anlegen
Inline-Edit beider Felder mit Speichern, „Eintrag hinzufügen" nach SCR-05 mit Direktfokus.
Abnahme:
- [ ] Edit → Overlay schließen → neu öffnen → Änderung da; App-Neustart → Änderung da
- [ ] Neuer Eintrag landet in der letzten Gruppe des aktiven Reiters, leerer Reiter nutzt „Allgemein"

## P6 · Politur (KANN-Features nach Zeitlage)
Haltedauer-Setting, Start bei Login, Panel auf Screen mit Mauszeiger, App-Icon.
Abnahme: je umgesetztem Punkt ein manueller Test; nichts davon blockiert v1.0.

## P7 · Release
Release-Build, README (Installation, Berechtigung, Bedienung), Tag v1.0, Re-Entry-Doku.
Abnahme:
- [ ] Frischer Klon → dokumentierte Schritte → laufende App
- [ ] Erfolgskriterium v1.0 mit Stoppuhr bestanden
