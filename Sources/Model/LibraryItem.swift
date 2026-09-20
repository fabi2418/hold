import Foundation

/// Ein Eintrag der Library. Schema identisch zu Resources/seed.json.
struct LibraryItem: Codable, Identifiable, Equatable {
    var id: UUID
    var cat: String
    var group: String
    var label: String
    var desc: String

    init(id: UUID = UUID(), cat: String, group: String, label: String, desc: String) {
        self.id = id
        self.cat = cat
        self.group = group
        self.label = label
        self.desc = desc
    }

    /// Treffer für die globale Suche (M7): label, desc und cat, ohne Gross-/
    /// Kleinschreibung und ohne Diakritika.
    func matches(_ query: String) -> Bool {
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !needle.isEmpty else { return true }
        return [label, desc, cat].contains { field in
            field.range(of: needle, options: [.caseInsensitive, .diacriticInsensitive]) != nil
        }
    }
}
