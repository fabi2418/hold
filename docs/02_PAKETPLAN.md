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

## P8 · Sortieren und modulare Reiter (v1.1)
Aus der Iterationsliste hierher gezogen: Gruppen anlegen und löschen, Gruppen per Drag verschieben, Reiter frei konfigurierbar.

Grundsatzentscheidung: **Die Reihenfolge des `items`-Arrays in `library.json` IST die Ordnung.** Kein zusätzliches Ordnungsfeld, keine Formatänderung. Die Gruppenreihenfolge bleibt „erstes Auftreten".

Umfang:
- Zeile per Drag verschieben, innerhalb der Gruppe und über Gruppengrenzen (`group` wird gesetzt). Drop-Indikator zwischen den Zeilen.
- Ganze Gruppe per Drag verschieben; der zusammenhängende Block ihrer Einträge wandert geschlossen.
- Gruppe anlegen und löschen. ~~Löschen nur, wenn die Gruppe leer ist.~~ (Leer-Bedingung mit P9 entfallen.)
- Reiter anlegen, löschen und per Drag umsortieren. ~~Löschen nur, wenn der Reiter leer ist.~~ (Leer-Bedingung mit P9 entfallen.)
- ⌘1–n folgt der Reiterreihenfolge; ab dem 10. Reiter kein Kürzel mehr.
- Bei aktiver Suche kein Drag: die flache Trefferliste hat keine gültige Zielposition.
- Persistenz über `store.save()` wie bisher.

Folge der Grundsatzentscheidung: Eine Gruppe ohne Einträge existiert nur zur Laufzeit, weil das Format sie nicht abbilden kann. Ein leerer Reiter überlebt dagegen einen Neustart, weil `tabs` seit K3 gespeichert wird.

Abnahme:
- [ ] Zeile innerhalb der Gruppe und in eine andere Gruppe ziehen; nach Schließen und App-Neustart steht sie noch dort
- [ ] Ganze Gruppe verschieben; ihre Einträge bleiben zusammen und in gleicher Reihenfolge
- [ ] Gruppe anlegen, Zeile hineinziehen, leere Gruppe löschen (die Einschränkung auf leere Gruppen ist mit P9 entfallen)
- [ ] Reiter anlegen, umsortieren, leeren Reiter löschen (die Einschränkung auf leere Reiter ist mit P9 entfallen)
- [ ] ⌘1–n trifft nach dem Umsortieren den jeweils richtigen Reiter; der 10. Reiter hat kein Kürzel
- [ ] Bei aktiver Suche startet kein Drag

## P9 · Löschen ohne Leer-Bedingung (v1.1)
Hebt die „nur wenn leer"-Regel aus P8 auf: Zeilen, Gruppen und Reiter sind jederzeit löschbar, abgesichert durch ein einstufiges Undo.

Umfang:
- Einzelne Zeile löschen, gleich ob aus dem Seed oder neu. Bedienung: Auswahl + ⌫, und ein Löschen-Knopf, der bei Hover auf der Zeile erscheint.
- Gruppe löschen, auch mit Einträgen; alle Einträge der Gruppe im aktiven Reiter gehen mit.
- Reiter löschen, auch mit Einträgen; alle seine Einträge gehen mit. Auch der letzte Reiter ist löschbar.
- Leerer Zustand: 0 Reiter und 0 Einträge sind gültig. Das Overlay zeigt dann nur Suchzeile, „+" und Fußleiste. `activeTab` ist `""`.
- Undo: Das letzte Löschen ist per ⌘Z rückgängig zu machen, inklusive ursprünglicher Position und Reiter-Index. Eine Ebene, kein Stack; jede andere Aktion verwirft es. Bis dahin steht „Gelöscht · ⌘Z" in der Fußleiste.
- Kein Löschen bei aktiver Suche, bei fokussiertem Feld oder laufender Umbenennung.
- Persistenz über `store.save()`, auch beim Undo.

Abnahme:
- [ ] Zeile per ⌫ und per Hover-Knopf löschen; ⌘Z stellt sie an derselben Position wieder her
- [ ] Gruppe mit mehreren Einträgen löschen; ⌘Z bringt alle zurück, in gleicher Reihenfolge
- [ ] Reiter mit Einträgen löschen; ⌘Z setzt ihn an seinen alten Index zurück
- [ ] Alles löschen bis 0 Reiter: Overlay bleibt bedienbar, „+" legt einen neuen Reiter an, App-Neustart lädt den leeren Zustand
- [ ] Nach einer anderen Aktion (Auswahl, Kopieren, Suche) ist ⌘Z wirkungslos und der Fußzeilenhinweis weg
- [ ] Bei aktiver Suche, im Editierfeld und während einer Umbenennung löscht ⌫ nichts

## P7 · Release
Release-Build, README (Installation, Berechtigung, Bedienung), Tag v1.0, Re-Entry-Doku.
Abnahme:
- [ ] Frischer Klon → dokumentierte Schritte → laufende App
- [ ] Erfolgskriterium v1.0 mit Stoppuhr bestanden
