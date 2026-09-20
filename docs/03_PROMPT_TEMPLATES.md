# 03 · Prompt-Templates

Platzhalter in [ ] ausfüllen. Templates 1 und 2 gehen an Claude Code im Repo, 3 und 4 in dieses Projekt.

## 1 · Paket-Auftrag (an Claude Code)
```
Lies CLAUDE.md, docs/01_REQUIREMENTS.md und docs/02_PAKETPLAN.md.
Setze ausschließlich Paket [P?] um. Kein Vorgriff, keine Refactorings außerhalb des Pakets.
Liefere vollständige Dateien. Führe Build und Tests aus und nenne das Ergebnis.
Gehe danach die Abnahme-Checkliste von [P?] selbst durch und markiere je Punkt: erfüllt / offen / von Fabian manuell zu testen.
Neue Swift-Konstrukte beim ersten Auftreten kurz mit C-Referenz erklären.
Kein Commit ohne meine Freigabe.
```

## 2 · Bugfix-Auftrag (an Claude Code)
```
Bug in Paket [P?]: [Beobachtung, exakte Schritte zur Reproduktion, erwartet vs. tatsächlich, ggf. Fehlermeldung/Log].
Erst Root Cause benennen, dann minimalen Fix als vollständige Datei(en), dann welcher Abnahme-Punkt erneut zu testen ist.
Keine Beifang-Änderungen.
```

## 3 · Review (in dieses Projekt, mit Diff/Datei)
```
review Paket [P?]. Prüfe gegen 01_REQUIREMENTS.md ([betroffene M-Punkte]) und die Abnahme-Checkliste.
Priorisierte Problemliste (Korrektheit > Robustheit > Stil), je Punkt ein Satz Begründung. Kein Rewrite.
[Code/Diff einfügen]
```

## 4 · Abschluss / Re-Entry (in dieses Projekt, am Session-Ende)
```
Abschluss. Erzeuge den Re-Entry-Prompt: abgenommene Pakete, aktuelles Paket mit Stand je Checklisten-Punkt, offene Bugs, nächster konkreter Schritt, geänderte Dateien seit letzter Freigabe.
```

## 5 · Session-Start (in dieses Projekt)
```
sprint Session-Ziel: [z. B. "P0 abgenommen"]. Hier der letzte Re-Entry-Prompt: [einfügen].
Formuliere daraus den ersten Paket-Auftrag für Claude Code.
```
