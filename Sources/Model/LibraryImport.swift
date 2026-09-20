import Foundation

/// Ein Eintrag, wie er im Import-JSON steht: ohne id, die wird beim Merge
/// vergeben. LibraryItem selbst taugt nicht als Eingabetyp, weil sein
/// synthetisierter Decoder ein id-Feld verlangt.
struct ImportedItem: Decodable, Equatable {
    let cat: String
    let group: String
    let label: String
    let desc: String
}

/// Import aus der Zwischenablage (P10). Reine Funktionen, ohne AppKit und
/// ohne Zustand — die Merge-Regeln sind damit ohne laufende App testbar.
enum LibraryImport {
    struct Result: Equatable {
        let imported: Int
        let skipped: Int

        /// Text fuer die Fussleiste.
        var message: String { "\(imported) importiert, \(skipped) übersprungen" }
    }

    struct Merged: Equatable {
        let items: [LibraryItem]
        let tabs: [String]
        let result: Result
    }

    enum Failure: LocalizedError, Equatable {
        case invalidJSON

        var errorDescription: String? { "Import fehlgeschlagen" }
    }

    /// Ein Eintrag gilt als Duplikat, wenn Reiter und Command uebereinstimmen.
    private struct Key: Hashable {
        let cat: String
        let label: String
    }

    static func decode(_ text: String) throws -> [ImportedItem] {
        guard let data = text.data(using: .utf8) else { throw Failure.invalidJSON }
        do {
            return try JSONDecoder().decode([ImportedItem].self, from: data)
        } catch {
            throw Failure.invalidJSON
        }
    }

    /// Haengt neue Eintraege ans Array-Ende an — die Array-Reihenfolge ist die
    /// Ordnung (Entscheidung 1 in docs/05_RE_ENTRY.md). Ein unbekannter `cat`
    /// wird als neuer Reiter hinten ergaenzt.
    static func merge(_ incoming: [ImportedItem],
                      into items: [LibraryItem],
                      tabs: [String]) -> Merged {
        var items = items
        var tabs = tabs
        var seen = Set(items.map { Key(cat: $0.cat, label: $0.label) })
        var imported = 0
        var skipped = 0

        for entry in incoming {
            let key = Key(cat: entry.cat, label: entry.label)
            guard !seen.contains(key) else {
                skipped += 1
                continue
            }
            items.append(LibraryItem(cat: entry.cat,
                                     group: entry.group,
                                     label: entry.label,
                                     desc: entry.desc))
            seen.insert(key)
            if !tabs.contains(entry.cat) { tabs.append(entry.cat) }
            imported += 1
        }

        return Merged(items: items, tabs: tabs, result: Result(imported: imported, skipped: skipped))
    }
}
