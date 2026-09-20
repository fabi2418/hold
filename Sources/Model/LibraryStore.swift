import Combine
import Foundation

enum LibraryError: LocalizedError, Equatable {
    /// Die Seed-Datei fehlt im Bundle oder ist nicht lesbar.
    case seedUnavailable(String)
    /// Schreiben verweigert, weil das letzte Laden fehlschlug.
    case saveBlockedAfterFailedLoad

    var errorDescription: String? {
        switch self {
        case .seedUnavailable(let reason):
            return "Seed-Library nicht verfuegbar: \(reason)"
        case .saveBlockedAfterFailedLoad:
            return "Speichern abgelehnt: die Library wurde nie erfolgreich geladen."
        }
    }
}

/// Dateiformat ab K3: die Reiter-Reihenfolge muss mitgespeichert werden.
/// Aeltere Dateien sind ein blankes Array von Eintraegen und werden weiter
/// gelesen (siehe load()).
private struct LibraryFile: Codable {
    var tabs: [String]
    var items: [LibraryItem]
}

/// Laedt, haelt und speichert die Library (M10).
final class LibraryStore: ObservableObject {
    /// Ausgangsreihenfolge nach M4. Ab K3 nur noch der Startwert: die
    /// tatsaechliche Reihenfolge lebt in `tabs` und wird persistiert.
    static let defaultTabs = ["Git", "Claude", "Python", "zsh"]

    @Published var items: [LibraryItem] = []
    @Published private(set) var tabs: [String] = LibraryStore.defaultTabs

    /// Nur ein erfolgreicher load() setzt das Flag. Solange es false ist,
    /// verweigert save() den Write und schuetzt die Datei auf der Platte.
    private(set) var isLoaded = false

    let fileURL: URL
    private let seedURL: URL?

    init(fileURL: URL = LibraryStore.defaultFileURL,
         seedURL: URL? = Bundle.main.url(forResource: "seed", withExtension: "json")) {
        self.fileURL = fileURL
        self.seedURL = seedURL
    }

    /// ~/Library/Application Support/Cheatsheet/library.json
    static var defaultFileURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("Cheatsheet", isDirectory: true)
            .appendingPathComponent("library.json")
    }

    // MARK: - Persistenz

    /// Laedt die Library. Fehlt die Datei, wird sie zuvor aus dem Seed erzeugt.
    /// Wirft bei fehlendem Seed und bei kaputtem JSON; die vorhandene Datei
    /// bleibt in beiden Faellen unberuehrt.
    @discardableResult
    func load() throws -> Bool {
        var seeded = false
        if !FileManager.default.fileExists(atPath: fileURL.path) {
            try writeSeed()
            seeded = true
        }
        do {
            let data = try Data(contentsOf: fileURL)
            let decoder = JSONDecoder()
            if let file = try? decoder.decode(LibraryFile.self, from: data) {
                items = file.items
                tabs = file.tabs
            } else {
                // Altes Format: blankes Array, Reiter auf den Standard.
                items = try decoder.decode([LibraryItem].self, from: data)
                tabs = LibraryStore.defaultTabs
            }
        } catch {
            isLoaded = false
            throw error
        }
        isLoaded = true
        return seeded
    }

    func save() throws {
        guard isLoaded else { throw LibraryError.saveBlockedAfterFailedLoad }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try write(try encoder.encode(LibraryFile(tabs: tabs, items: items)))
    }

    private func writeSeed() throws {
        guard let seedURL else {
            throw LibraryError.seedUnavailable("seed.json liegt nicht im Bundle")
        }
        let data: Data
        do {
            data = try Data(contentsOf: seedURL)
        } catch {
            throw LibraryError.seedUnavailable("seed.json nicht lesbar (\(error.localizedDescription))")
        }
        try write(data)
    }

    /// Atomarer Write nach M10: schreibt in eine Temp-Datei und ersetzt erst
    /// danach das Ziel, damit ein Abbruch keine halbe Datei hinterlaesst.
    private func write(_ data: Data) throws {
        let directory = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try data.write(to: fileURL, options: .atomic)
    }

    // MARK: - Abfragen

    func items(in cat: String) -> [LibraryItem] {
        items.filter { $0.cat == cat }
    }

    /// Gruppen eines Reiters in der Reihenfolge ihres ersten Auftretens.
    func groups(in cat: String) -> [(name: String, items: [LibraryItem])] {
        var order: [String] = []
        var buckets: [String: [LibraryItem]] = [:]
        for item in items where item.cat == cat {
            if buckets[item.group] == nil { order.append(item.group) }
            buckets[item.group, default: []].append(item)
        }
        return order.map { (name: $0, items: buckets[$0] ?? []) }
    }

    /// Globale Suche ueber alle Reiter (M7). Leere Query liefert alle Eintraege.
    func search(_ query: String) -> [LibraryItem] {
        items.filter { $0.matches(query) }
    }

    /// Haelt einen Auswahl-Index im gueltigen Bereich (Edge Case aus 01_REQUIREMENTS.md).
    static func clamp(_ index: Int, count: Int) -> Int {
        guard count > 0 else { return 0 }
        return min(max(index, 0), count - 1)
    }

    // MARK: - Umbenennen (K3)

    /// Benennt einen Reiter um und zieht alle Eintraege mit.
    /// Abgelehnt werden: leerer Name, bereits vergebener Name, unbekannter
    /// Reiter und ein Reiter ohne Eintraege.
    @discardableResult
    func renameTab(from old: String, to new: String) -> Bool {
        let name = new.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return false }
        guard let index = tabs.firstIndex(of: old) else { return false }
        if name == old { return true }
        guard !tabs.contains(name) else { return false }
        guard !items(in: old).isEmpty else { return false }

        tabs[index] = name
        for position in items.indices where items[position].cat == old {
            items[position].cat = name
        }
        return true
    }

    /// Benennt eine Gruppe um, ausschliesslich innerhalb des angegebenen
    /// Reiters. Gleichnamige Gruppen anderer Reiter bleiben unberuehrt.
    @discardableResult
    func renameGroup(in tab: String, from old: String, to new: String) -> Bool {
        let name = new.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return false }
        let existing = groups(in: tab).map(\.name)
        guard existing.contains(old) else { return false }
        if name == old { return true }
        guard !existing.contains(name) else { return false }

        for position in items.indices where items[position].cat == tab && items[position].group == old {
            items[position].group = name
        }
        return true
    }
}
