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
    @Published private(set) var activeTab: String
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

    /// Letzter Loeschvorgang fuer ⌘Z. Eine Ebene, kein Stack (P9).
    @Published private(set) var undoState: UndoState?

    /// Laeuft eine Umbenennung, und mit welchem Entwurfstext (K3).
    @Published private(set) var renaming: RenameTarget?
    @Published var renameDraft: String = ""

    init(store: LibraryStore) {
        self.store = store
        self.activeTab = store.tabs.first ?? ""
        storeObserver = store.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
        }
    }

    var tabs: [String] { store.tabs }

    /// Liest den aktuellen Stand aus dem Store. Ein Binding darf nicht auf
    /// einem eingefangenen Schnappschuss arbeiten, der sich nie aktualisiert.
    func item(id: UUID) -> LibraryItem? {
        store.items.first { $0.id == id }
    }

    var isSearching: Bool { OverlayList.isSearching(query) }
    var isEditingRow: Bool { focusedField?.isRowField ?? false }
    var isRenaming: Bool { renaming != nil }
    /// Solange irgendein Textfeld ausser der Suche aktiv ist, ruhen ↑↓, ⌘1-4, ←→.
    var blocksNavigationKeys: Bool { isEditingRow || isRenaming }

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

    var canUndo: Bool { undoState != nil }

    /// Rechts in der Fussleiste: Kopier- und Loesch-Status verdraengen die
    /// Zeilenzahl, bis die naechste Aktion kommt.
    var statusText: String {
        if hasCopyFeedback { return "Kopiert" }
        if canUndo { return "Gelöscht · ⌘Z" }
        return "\(rows.count) Einträge"
    }

    // MARK: - Navigation

    /// Reiterwechsel setzt Auswahl auf Zeile 1 und leert die Suche (SCR-01b).
    func selectTab(_ tab: String) {
        guard store.tabs.contains(tab) else { return }
        clearCopyFeedback()
        query = ""
        activeTab = tab
        selection = 0
    }

    func cycleTab(by delta: Int) {
        selectTab(OverlayList.cycleTab(from: activeTab, by: delta, tabs: store.tabs))
    }

    func selectTab(number: Int) {
        let index = number - 1
        guard store.tabs.indices.contains(index) else { return }
        selectTab(store.tabs[index])
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
        if isRenaming { return .cancelRename }
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

    // MARK: - Loeschen und Undo (P9)

    /// Nur bei leerer Suche, ohne fokussiertes Zeilenfeld und ohne laufende
    /// Umbenennung. Das leere Suchfeld selbst zaehlt nicht als Feld: dort gibt
    /// es keinen Text, den ⌫ sonst loeschen koennte.
    var canDelete: Bool { query.isEmpty && !blocksNavigationKeys }

    private func rememberForUndo() {
        copiedItemID = nil
        undoState = UndoState(snapshot: store.snapshot(), activeTab: activeTab, selection: selection)
    }

    @discardableResult
    func deleteSelection() -> Bool {
        guard canDelete, let item = selectedItem else { return false }
        rememberForUndo()
        guard store.removeItem(id: item.id) else { undoState = nil; return false }
        selection = LibraryStore.clamp(selection, count: rows.count)
        save()
        log.info("Zeile gelöscht")
        return true
    }

    @discardableResult
    func deleteGroup(_ name: String) -> Bool {
        guard canReorder, !isRenaming else { return false }
        rememberForUndo()
        guard store.removeGroup(name, in: activeTab) else { undoState = nil; return false }
        selection = LibraryStore.clamp(selection, count: rows.count)
        save()
        log.info("Gruppe gelöscht")
        return true
    }

    @discardableResult
    func deleteTab(_ name: String) -> Bool {
        guard canReorder, !isRenaming else { return false }
        rememberForUndo()
        guard store.removeTab(name) else { undoState = nil; return false }
        if activeTab == name { activeTab = store.tabs.first ?? "" }
        selection = 0
        save()
        log.info("Reiter gelöscht")
        return true
    }

    /// ⌘Z: stellt den Zustand vor dem letzten Loeschen wieder her.
    @discardableResult
    func undoDelete() -> Bool {
        guard let state = undoState else { return false }
        store.restore(state.snapshot)
        activeTab = state.activeTab
        selection = LibraryStore.clamp(state.selection, count: rows.count)
        undoState = nil
        copiedItemID = nil
        save()
        log.info("Löschen rückgängig gemacht")
        return true
    }

    // MARK: - Sortieren und Struktur (P8)

    /// Bei aktiver Suche ist die Liste flach und hat keine gueltige
    /// Zielposition — dann wird nicht gezogen.
    var canReorder: Bool { !isSearching }

    func shortcut(for tab: String) -> Int? {
        guard let index = store.tabs.firstIndex(of: tab) else { return nil }
        return LibraryOrder.shortcut(forTabAt: index)
    }

    /// Seit P9 ohne Leer-Bedingung: geloescht werden darf jederzeit, solange
    /// nicht gesucht oder umbenannt wird.
    func canDeleteGroup(_ name: String) -> Bool { canReorder && !isRenaming }
    func canDeleteTab(_ name: String) -> Bool { canReorder && !isRenaming }

    func moveItem(id: UUID, to position: DropPosition) {
        guard canReorder else { return }
        clearCopyFeedback()
        store.moveItem(id: id, to: position, in: activeTab)
        save()
    }

    func moveGroup(_ group: String, before target: String?) {
        guard canReorder else { return }
        clearCopyFeedback()
        store.moveGroup(group, before: target, in: activeTab)
        save()
    }

    func moveTab(_ tab: String, before target: String?) {
        guard canReorder else { return }
        clearCopyFeedback()
        store.moveTab(tab, before: target)
        save()
    }

    /// Legt eine leere Gruppe mit eindeutigem Vorschlagsnamen an und startet
    /// sofort die Umbenennung.
    @discardableResult
    func addGroup() -> Bool {
        guard canReorder else { return false }
        let name = Self.uniqueName("Neue Gruppe", taken: store.groups(in: activeTab).map(\.name))
        guard store.addGroup(name, in: activeTab) else { return false }
        beginRename(.group(name))
        return true
    }

    @discardableResult
    func removeGroup(_ name: String) -> Bool {
        guard canReorder, store.removeGroup(name, in: activeTab) else { return false }
        save()
        return true
    }

    /// Legt einen leeren Reiter an, macht ihn aktiv und startet die Umbenennung.
    @discardableResult
    func addTab() -> Bool {
        guard canReorder else { return false }
        let name = Self.uniqueName("Neuer Reiter", taken: store.tabs)
        guard store.addTab(name) else {
            log.error("Reiter anlegen abgelehnt: \(name, privacy: .public)")
            return false
        }
        activeTab = name
        selection = 0
        save()
        beginRename(.tab(name))
        log.info("Reiter angelegt: \(name, privacy: .public), Umbenennung gestartet")
        return true
    }

    @discardableResult
    func removeTab(_ name: String) -> Bool {
        guard canReorder, canDeleteTab(name), store.removeTab(name) else { return false }
        if activeTab == name { activeTab = store.tabs.first ?? "" }
        selection = 0
        save()
        return true
    }

    /// "Neue Gruppe", "Neue Gruppe 2", ... — der erste freie Name.
    static func uniqueName(_ base: String, taken: [String]) -> String {
        guard taken.contains(base) else { return base }
        var counter = 2
        while taken.contains("\(base) \(counter)") { counter += 1 }
        return "\(base) \(counter)"
    }

    // MARK: - Umbenennen (K3)

    /// Startet die Umbenennung. Bei aktiver Suche und bei einem Reiter ohne
    /// Eintraege passiert nichts.
    @discardableResult
    func beginRename(_ target: RenameTarget) -> Bool {
        guard !isSearching else { return false }
        switch target {
        case .tab(let name):
            guard store.tabs.contains(name) else { return false }
            renameDraft = name
        case .group(let name):
            guard store.groups(in: activeTab).contains(where: { $0.name == name }) else { return false }
            renameDraft = name
        }
        renaming = target
        requestFocus(.rename)
        return true
    }

    /// esc: Entwurf verwerfen, alter Name bleibt stehen.
    func cancelRename() {
        guard isRenaming else { return }
        renaming = nil
        renameDraft = ""
        focusedField = .search
        requestFocus(.search)
    }

    /// Enter oder Blur. Abgelehnte Namen lassen den alten Namen stehen.
    @discardableResult
    func commitRename() -> Bool {
        guard let target = renaming else { return false }
        let name = renameDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        var accepted = false

        switch target {
        case .tab(let old):
            accepted = store.renameTab(from: old, to: name)
            if accepted, activeTab == old { activeTab = name }
        case .group(let old):
            accepted = store.renameGroup(in: activeTab, from: old, to: name)
        }

        renaming = nil
        renameDraft = ""
        focusedField = .search
        requestFocus(.search)
        if accepted { save() }
        log.info("Umbenennen \(accepted ? "übernommen" : "abgelehnt", privacy: .public)")
        return accepted
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
    func addEntry() -> LibraryItem? {
        guard !activeTab.isEmpty else { return nil }
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
        undoState = nil
        guard writeToPasteboard(item.label) else {
            copiedItemID = nil
            return false
        }
        copiedItemID = item.id
        return true
    }

    func clearCopyFeedback() {
        copiedItemID = nil
        undoState = nil
    }

    static func writeToSystemPasteboard(_ text: String) -> Bool {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        return pasteboard.setString(text, forType: .string)
    }
}
