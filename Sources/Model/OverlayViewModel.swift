import Combine
import Foundation

/// Zustand des Overlays: aktiver Reiter, Suchtext, Auswahlindex.
/// Die Rechenarbeit liegt in OverlayList, hier steht nur die Zustandsfuehrung.
final class OverlayViewModel: ObservableObject {
    @Published var query: String = "" {
        didSet {
            guard query != oldValue else { return }
            selection = 0
        }
    }
    @Published private(set) var activeTab: String = LibraryStore.tabs[0]
    @Published private(set) var selection: Int = 0
    /// Wird beim Oeffnen hochgezaehlt, damit die View den Fokus neu setzt.
    @Published private(set) var focusRequest: Int = 0

    let store: LibraryStore

    init(store: LibraryStore) {
        self.store = store
    }

    var isSearching: Bool { OverlayList.isSearching(query) }

    var sections: [OverlaySection] {
        OverlayList.sections(store: store, tab: activeTab, query: query)
    }

    var entries: [OverlayEntry] { OverlayList.entries(sections) }

    var rows: [LibraryItem] {
        OverlayList.rows(store: store, tab: activeTab, query: query)
    }

    var selectedItem: LibraryItem? {
        let rows = rows
        guard rows.indices.contains(selection) else { return nil }
        return rows[selection]
    }

    /// Reiterwechsel setzt Auswahl auf Zeile 1 und leert die Suche (SCR-01b).
    func selectTab(_ tab: String) {
        guard LibraryStore.tabs.contains(tab) else { return }
        query = ""
        activeTab = tab
        selection = 0
    }

    func cycleTab(by delta: Int) {
        selectTab(OverlayList.cycleTab(from: activeTab, by: delta))
    }

    func selectTab(number: Int) {
        let index = number - 1
        guard LibraryStore.tabs.indices.contains(index) else { return }
        selectTab(LibraryStore.tabs[index])
    }

    func moveSelection(by delta: Int) {
        selection = OverlayList.move(selection, by: delta, count: rows.count)
    }

    func select(index: Int) {
        selection = LibraryStore.clamp(index, count: rows.count)
    }

    /// Leert die Suche und kehrt zum zuletzt aktiven Reiter zurueck (M7).
    func clearSearch() {
        query = ""
        selection = 0
    }

    /// Beim Oeffnen: Auswahl auf Zeile 1, Suche leer, Fokus ins Suchfeld.
    func prepareForOpen() {
        query = ""
        selection = 0
        focusRequest += 1
    }
}
