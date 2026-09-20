import AppKit
import Combine
import Foundation
import os

private let log = Logger(subsystem: "com.fabi2418.cheatsheet", category: "overlay")

/// Zustand des Overlays: aktiver Reiter, Suchtext, Auswahl, Kopier-Feedback,
/// Fokus. Die Rechenarbeit liegt in OverlayList, hier steht die Zustandsfuehrung.
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
    /// Zuletzt kopierter Eintrag; treibt das Feedback nach SCR-04.
    /// Wird durch die naechste Aktion geloescht, nicht durch einen Timer.
    @Published private(set) var copiedItemID: UUID?

    /// Wo der Fokus gerade liegt; die View meldet es hierher zurueck.
    /// Bewusst NICHT @Published: gesetzt wird es aus einem onChange, also
    /// mitten im SwiftUI-Update-Zyklus — ein objectWillChange von dort wird
    /// verworfen. Gelesen wird es nur vom Key-Monitor, nie von der View.
    var focusedField: OverlayFocus?
    /// Wird hochgezaehlt, wenn der Fokus programmatisch gesetzt werden soll.
    @Published private(set) var focusRequest: Int = 0
    @Published private(set) var requestedFocus: OverlayFocus?

    let store: LibraryStore

    /// Injizierbar, damit Tests nicht in die echte Zwischenablage schreiben.
    var writeToPasteboard: (String) -> Bool = OverlayViewModel.writeToSystemPasteboard

    /// Verschachtelte ObservableObjects leiten nicht von selbst weiter: ohne
    /// das erfaehrt die View nichts von Aenderungen an store.items.
    private var storeObserver: AnyCancellable?

    init(store: LibraryStore) {
        self.store = store
        storeObserver = store.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
        }
    }

    /// Liest den aktuellen Stand aus dem Store. Ein Binding darf nicht auf
    /// einem eingefangenen Schnappschuss arbeiten, der sich nie aktualisiert.
    func item(id: UUID) -> LibraryItem? {
        store.items.first { $0.id == id }
    }

    var isSearching: Bool { OverlayList.isSearching(query) }
    var isEditingRow: Bool { focusedField?.isRowField ?? false }

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

    // MARK: - Fokus

    private func requestFocus(_ focus: OverlayFocus?) {
        requestedFocus = focus
        focusRequest += 1
    }

    /// esc-Leiter nach M6: Zeilenfeld verlassen, sonst Suche leeren,
    /// sonst Panel schliessen.
    func escapeAction() -> EscapeAction {
        if isEditingRow { return .leaveField }
        if isSearching { return .clearSearch }
        return .closePanel
    }

    /// esc in einem Zeilenfeld: Feld verlassen, Panel bleibt offen (SCR-03).
    /// Die Auswahl bleibt, wo sie ist.
    func leaveField() {
        focusedField = .search
        requestFocus(.search)
    }

    /// Beim Oeffnen: Auswahl auf Zeile 1, Suche leer, Fokus ins Suchfeld.
    func prepareForOpen() {
        clearCopyFeedback()
        query = ""
        selection = 0
        requestFocus(.search)
    }

    // MARK: - Editieren (M9)

    func update(itemID: UUID, desc: String? = nil, label: String? = nil) {
        guard let index = store.items.firstIndex(where: { $0.id == itemID }) else { return }
        if let desc { store.items[index].desc = desc }
        if let label { store.items[index].label = label }
    }

    /// Neue leere Zeile am Ende der letzten Gruppe des aktiven Reiters (SCR-05).
    /// Ein leerer Reiter bekommt die Gruppe "Allgemein".
    @discardableResult
    func addEntry() -> LibraryItem {
        clearCopyFeedback()
        if isSearching { query = "" }
        let group = store.groups(in: activeTab).last?.name ?? "Allgemein"
        let item = LibraryItem(cat: activeTab, group: group, label: "", desc: "")
        store.items.append(item)
        selection = LibraryStore.clamp(rows.count - 1, count: rows.count)
        requestFocus(.description(item.id))
        log.info("Neuer Eintrag in Reiter \(self.activeTab, privacy: .public), Gruppe \(group, privacy: .public)")
        return item
    }

    // MARK: - Persistenz (M10)

    /// Spaetestens beim Schliessen des Overlays. Der isLoaded-Schutz aus P1
    /// bleibt: nach einem fehlgeschlagenen Laden wird nicht geschrieben.
    @discardableResult
    func save() -> Bool {
        do {
            try store.save()
            return true
        } catch {
            log.error("Speichern fehlgeschlagen: \(error.localizedDescription, privacy: .public)")
            return false
        }
    }

    // MARK: - Kopieren (M8)

    /// Kopiert die aktuelle Auswahl. Ohne sichtbare Zeile passiert nichts.
    @discardableResult
    func copySelection() -> Bool {
        guard let item = selectedItem else { return false }
        return copy(item)
    }

    /// Schreibt `label` in die Zwischenablage. Eine leere Zeile und ein
    /// fehlgeschlagener Write liefern false — geworfen wird nie.
    @discardableResult
    func copy(_ item: LibraryItem) -> Bool {
        guard !item.label.isEmpty else { return false }
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
