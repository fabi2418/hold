# 01 · Requirements — Cheatsheet Overlay v1.0

Abgeleitet aus dem Artifact-Prototyp und den SCR-Karten auf dem Miro-Board. Quelle bei Detailfragen: Prototyp https://claude.ai/artifact/JatsEaAAE3YxbgnGsDhktP · Miro https://miro.com/app/board/uXjVHky-9dQ=/

## Erfolgskriterium v1.0
Aus jedem Reiter lässt sich ein Eintrag in unter 2 Sekunden kopieren (⌘ halten → Panel bleibt offen → ggf. Reiter/↑↓ → ⌘C), und die Library übersteht einen App-Neustart unverändert.

## Screens/States (IDs wie auf dem Miro-Board)
| ID | Zustand | Kern |
|---|---|---|
| SCR-00 | Closed | App inaktiv, Menu-Bar-Icon, globaler ⌘-Listener (Toggle, siehe M1) |
| SCR-01 | Overlay Default | Reiter Git als Default beim Erststart der App, danach der zuletzt aktive Reiter der Sitzung; Auswahl Zeile 1, Suche leer, Gruppen sichtbar |
| SCR-01b | Tab-State | Claude/Python/zsh; Wechsel setzt Auswahl auf 1, leert Suche |
| SCR-02 | Suche global | Live-Filter über label/desc/cat, Badge je Treffer, keine Gruppen |
| SCR-02E | Suche leer | Meldung „Nichts gefunden.", Aktionen wirkungslos |
| SCR-03 | Inline-Edit | Fokus in Beschreibung/Command; esc/Blur zurück |
| SCR-04 | Kopiert | Clipboard-Write, Button gefüllt, Status „Kopiert" |
| SCR-05 | Neuer Eintrag | Leere Zeile am Ende der letzten Gruppe des aktiven Reiters |

## MUSS (v1.0)
- M1 ⌘ exakt allein ≥ 0,6 s gehalten schaltet das Overlay um (öffnen bzw. schließen); esc schließt ebenfalls. Loslassen von ⌘ ändert nichts. ⌘+weitere Taste (⌘C, ⌘Tab, …) schaltet NICHT; System-Shortcuts bleiben unberührt (Events nie schlucken).
  - Beim Öffnen übernimmt das Panel den Tastaturfokus (Key-Window, Fokus im Suchfeld); beim Schließen geht der Fokus an die zuvor aktive App zurück.
  - Geändert gegenüber v1.0-Entwurf: der Halte-Modus (Overlay nur sichtbar, solange ⌘ gedrückt ist) wurde zugunsten des Toggle-Modus ersetzt; das Panel ist nicht mehr `nonactivating`, weil Suche und Tastaturnavigation eine echte Texteingabe brauchen.
- M2 Menu-Bar-App ohne Dock-Icon; Menü mit mindestens: Overlay testweise öffnen, Berechtigungsstatus, Beenden. Die App aktiviert sich nur, solange das Overlay offen ist.
- M3 Accessibility-Berechtigung beim Start prüfen; fehlt sie: System-Prompt auslösen und Status sichtbar machen.
- M4 4 Reiter in fester Reihenfolge Git · Claude · Python · zsh, je mit Eintragszähler; Einträge in benannten Gruppen.
- M5 Zeile = Beschreibung (feste Breite, Ellipsis) + Command/Prompt (flexibel, Ellipsis, im Fokus bis Zeilenende scrollbar) + Copy-Button.
- M6 Tastatur: ↑↓ Auswahl über Gruppengrenzen mit Mitscrollen; Start immer Zeile 1; ⌘1–4 direkt; ←→ zyklisch (⌘1–4 und ←→ nur bei leerer Suche); ⌘C/⌃C kopiert Auswahl; esc leert die Suche, sonst schließt es das Panel, und verlässt ein Editierfeld.
- M7 Suche global über label/desc/cat mit Reiter-Badge je Treffer; leeren führt zurück; 0 Treffer zeigt SCR-02E.
- M8 Kopieren schreibt `label` via NSPasteboard; Feedback wie SCR-04; Fehler dürfen nie crashen.
- M9 Inline-Editieren beider Felder; „Eintrag hinzufügen" gemäß SCR-05, direkt fokussiert.
- M10 Persistenz als JSON unter `~/Library/Application Support/Cheatsheet/library.json`; Erststart mit Seed-Library (Inhalte aus dem Prototyp); Schreiben atomar; Änderungen speichern spätestens beim Schließen des Overlays.
- M11 Optik nah am Prototyp: helles macOS-Panel, Systemfont + Monospace für Commands, Akzentfarbe für aktiven Reiter/Auswahl/Feedback.

## KANN (v1.0, nur wenn Zeit)
- K1 Haltedauer (0,4–0,8 s) einstellbar.
- K2 Start bei Login (SMAppService).
- K3 Reiter/Gruppen umbenennen.

## Nicht-Ziele v1.0
- Kein Sync/iCloud, keine Multi-Device-Library.
- Kein Shortcut-Recorder pro Eintrag (bewusst entfernt — Library, nicht Hotkey-Manager).
- Kein Auto-Import von Claude-Skills.
- Keine Windows/Linux-Version, keine Sandbox/App-Store-Fassung (Event-Tap verträgt sich nicht mit Sandbox).

## Iterationsliste (v1.1-Kandidaten)
- Scan von `~/.claude/skills/*/SKILL.md` beim Start → Name + description automatisch in den Claude-Reiter (Frontmatter parsen; Duplikate per Name erkennen).
- Einfügen statt nur Kopieren (CGEvent ⌘V simulieren) — zusätzliche Berechtigungsfragen prüfen.
- Reiter frei konfigurierbar; Export/Import der Library.
- Sichtbarer Hinweis im Overlay, wenn `library.json` nicht geladen werden konnte (aktuell nur Log, Panel bleibt leer).
- Menü-Eintrag „Overlay öffnen (Test)" kollidiert mit dem Schließen bei Fokusverlust (Panel schließt und öffnet sofort wieder). Entfernen oder umbauen, wenn er nach P0 noch gebraucht wird.

## Edge Cases (aus den SCR-Karten)
- Auswahl-Index bei Filterwechsel auf gültigen Bereich klemmen; ⌘C ohne sichtbare Zeile: no-op.
- Sehr lange Texte: Ellipsis in Ruhe, horizontales Scrollen im Fokus.
- Leerer Reiter: Kopfzeile ohne Zeilen, „Eintrag hinzufügen" nutzt Gruppe „Allgemein".
- Zwei Bildschirme: Panel auf dem Screen mit Mauszeiger zentrieren.
- Berechtigung zur Laufzeit entzogen: Tap deaktiviert sich — Status in der Menu-Bar aktualisieren, kein Crash.
