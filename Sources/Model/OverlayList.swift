import Foundation

/// Eine Gruppe sichtbarer Eintraege. `name` ist nil, solange gesucht wird:
/// Treffer erscheinen als flache Liste ohne Gruppentitel (M7).
struct OverlaySection: Equatable, Identifiable {
    let name: String?
    let items: [LibraryItem]

    var id: String { name ?? "__suche__" }
}

/// Ein Element der gezeichneten Liste. `selectionIndex` ist die Position in der
/// flachen Auswahlliste und zaehlt Gruppentitel nicht mit.
enum OverlayEntry: Equatable, Identifiable {
    case group(String)
    case item(LibraryItem, selectionIndex: Int)

    var id: String {
        switch self {
        case .group(let name): return "group:\(name)"
        case .item(let item, _): return item.id.uuidString
        }
    }
}

/// Reine Auswahl- und Filterlogik, bewusst ohne SwiftUI und ohne Zustand,
/// damit sie ohne laufende App testbar bleibt.
enum OverlayList {
    static func isSearching(_ query: String) -> Bool {
        !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    static func sections(store: LibraryStore, tab: String, query: String) -> [OverlaySection] {
        guard isSearching(query) else {
            return store.groups(in: tab).map { OverlaySection(name: $0.name, items: $0.items) }
        }
        return [OverlaySection(name: nil, items: store.search(query))]
    }

    /// Die auswaehlbaren Zeilen in Anzeigereihenfolge, Gruppen aufgeloest.
    static func rows(store: LibraryStore, tab: String, query: String) -> [LibraryItem] {
        sections(store: store, tab: tab, query: query).flatMap(\.items)
    }

    static func entries(_ sections: [OverlaySection]) -> [OverlayEntry] {
        var result: [OverlayEntry] = []
        var index = 0
        for section in sections {
            if let name = section.name { result.append(.group(name)) }
            for item in section.items {
                result.append(.item(item, selectionIndex: index))
                index += 1
            }
        }
        return result
    }

    /// Verschiebt die Auswahl ueber Gruppengrenzen hinweg und klemmt an den Rand.
    static func move(_ index: Int, by delta: Int, count: Int) -> Int {
        LibraryStore.clamp(index + delta, count: count)
    }

    /// Reiterwechsel mit ←→: zyklisch in beide Richtungen (M6).
    static func cycleTab(from tab: String, by delta: Int) -> String {
        let tabs = LibraryStore.tabs
        guard let current = tabs.firstIndex(of: tab), !tabs.isEmpty else { return tab }
        let count = tabs.count
        let next = ((current + delta) % count + count) % count
        return tabs[next]
    }
}
