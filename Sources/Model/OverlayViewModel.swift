import AppKit
import Combine
import Foundation

/// Zustand des Overlays: aktiver Reiter, Suchtext, Auswahlindex, Kopier-Feedback.
/// Die Rechenarbeit liegt in OverlayList, hier steht nur die Zustandsfuehrung.
final class OverlayViewModel: ObservableObject {
    @Published var query: String = "" {
        didSet {
            guard query != oldValue else { return }
            selection = 0
            copiedItemID = nil
        }
    }
    @Published private(set) var activeTab: String = LibraryStore.tabs[0]
    @Published private(set) var selection: Int = 0
    /// Wird beim Oeffnen hochgezaehlt, damit die View den Fokus neu setzt.
    @Published private(set) var focusRequest: Int = 0
    /// Zuletzt kopierter Eintrag; treibt das Feedback nach SCR-04.
    /// Wird durch die naechste Aktion geloescht, nicht durch einen Timer.
    @Published private(set) var copiedItemID: UUID?

    let store: LibraryStore

    /// Injizierbar, damit Tests nicht in die echte Zwischenablage schreiben.
    var writeToPasteboard: (String) -> Bool = OverlayViewModel.writeToSystemPasteboard

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

    var hasCopyFeedback: Bool { copiedItemID != nil }

    /// Rechts in der Fussleiste: Kopier-Status verdraengt die Zeilenzahl.
    var statusText: String {
        hasCopyFeedback ? "Kopiert" : "\(rows.count) Einträge"
    }

    // MARK: - Navigation

    /// Reiterwechsel setzt Auswahl auf Zeile 1 und leert die Suche (SCR-01b).
    func selectTab(_ tab: String) {
        guard LibraryStore.tabs.contains(tab) else { return }
        clearCopyFeedback()
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
        clearCopyFeedback()
        selection = OverlayList.move(selection, by: delta, count: rows.count)
    }

    func select(index: Int) {
        clearCopyFeedback()
        selection = LibraryStore.clamp(index, count: rows.count)
    }

    /// Leert die Suche und kehrt zum zuletzt aktiven Reiter zurueck (M7).
    func clearSearch() {
        clearCopyFeedback()
        query = ""
        selection = 0
    }

    /// Beim Oeffnen: Auswahl auf Zeile 1, Suche leer, Fokus ins Suchfeld.
    func prepareForOpen() {
        clearCopyFeedback()
        query = ""
        selection = 0
        focusRequest += 1
    }

    // MARK: - Kopieren (M8)

    /// Kopiert die aktuelle Auswahl. Ohne sichtbare Zeile passiert nichts.
    @discardableResult
    func copySelection() -> Bool {
        guard let item = selectedItem else { return false }
        return copy(item)
    }

    /// Schreibt `label` in die Zwischenablage. Ein fehlgeschlagener Write
    /// liefert false und setzt kein Feedback — geworfen wird nie.
    @discardableResult
    func copy(_ item: LibraryItem) -> Bool {
        guard writeToPasteboard(item.label) else {
            copiedItemID = nil
            return false
        }
        copiedItemID = item.id
        return true
    }

    func clearCopyFeedback() {
        copiedItemID = nil
    }

    static func writeToSystemPasteboard(_ text: String) -> Bool {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        return pasteboard.setString(text, forType: .string)
    }
}
