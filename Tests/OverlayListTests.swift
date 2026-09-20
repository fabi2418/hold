import Combine
import XCTest

final class OverlayListTests: XCTestCase {
    private var tempDirectory: URL!
    private var store: LibraryStore!
    private var model: OverlayViewModel!

    private let sample = [
        LibraryItem(cat: "Git", group: "Status", label: "git status -sb", desc: "Kurzstatus"),
        LibraryItem(cat: "Git", group: "Status", label: "git log", desc: "Historie zeigen"),
        LibraryItem(cat: "Git", group: "Committen", label: "git commit -m", desc: "Änderung sichern"),
        LibraryItem(cat: "Claude", group: "Skills", label: "/graphify", desc: "Wissensgraph bauen"),
        LibraryItem(cat: "zsh", group: "Allgemein", label: "ls -la", desc: "Dateien mit Details"),
    ]

    override func setUpWithError() throws {
        tempDirectory = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("OverlayTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        store = LibraryStore(fileURL: tempDirectory.appendingPathComponent("library.json"), seedURL: nil)
        store.items = sample
        model = OverlayViewModel(store: store)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempDirectory)
    }

    // MARK: - isSearching

    func testLeereUndNurLeerzeichenQueryGiltNichtAlsSuche() {
        XCTAssertFalse(OverlayList.isSearching(""))
        XCTAssertFalse(OverlayList.isSearching("   "))
        XCTAssertTrue(OverlayList.isSearching("git"))
    }

    // MARK: - Sections

    func testOhneSucheGruppenMitTiteln() {
        let sections = OverlayList.sections(store: store, tab: "Git", query: "")
        XCTAssertEqual(sections.map(\.name), ["Status", "Committen"])
        XCTAssertEqual(sections.first?.items.count, 2)
    }

    func testMitSucheFlacheListeOhneGruppentitel() {
        let sections = OverlayList.sections(store: store, tab: "Git", query: "git")
        XCTAssertEqual(sections.count, 1)
        XCTAssertNil(sections.first?.name)
    }

    func testSucheGehtUeberAlleReiterHinweg() {
        let rows = OverlayList.rows(store: store, tab: "Git", query: "Dateien")
        XCTAssertEqual(rows.map(\.cat), ["zsh"])
    }

    func testSucheOhneTrefferLiefertLeereListe() {
        XCTAssertTrue(OverlayList.rows(store: store, tab: "Git", query: "xyzzy").isEmpty)
    }

    // MARK: - Entries

    func testEntriesZaehlenNurEintraegeFuerDieAuswahl() {
        let entries = OverlayList.entries(OverlayList.sections(store: store, tab: "Git", query: ""))
        let indices: [Int] = entries.compactMap { entry in
            if case .item(_, let index) = entry { return index }
            return nil
        }
        XCTAssertEqual(indices, [0, 1, 2])
        XCTAssertEqual(entries.count, 5) // 2 Gruppentitel + 3 Zeilen
    }

    func testEntriesBeiSucheOhneGruppentitel() {
        let entries = OverlayList.entries(OverlayList.sections(store: store, tab: "Git", query: "git"))
        XCTAssertFalse(entries.contains { if case .group = $0 { return true } else { return false } })
    }

    // MARK: - Auswahl bewegen

    func testMoveKlemmtAnBeidenRaendern() {
        XCTAssertEqual(OverlayList.move(0, by: -1, count: 3), 0)
        XCTAssertEqual(OverlayList.move(2, by: 1, count: 3), 2)
        XCTAssertEqual(OverlayList.move(0, by: 1, count: 3), 1)
    }

    func testMoveUeberGruppengrenzeHinweg() {
        // Index 1 ist die letzte Zeile der Gruppe "Status", 2 die erste von "Committen".
        XCTAssertEqual(OverlayList.move(1, by: 1, count: 3), 2)
    }

    func testMoveBeiLeererListe() {
        XCTAssertEqual(OverlayList.move(0, by: 1, count: 0), 0)
    }

    // MARK: - Reiter zyklisch

    func testCycleTabVorwaertsUndRueckwaertsZyklisch() {
        XCTAssertEqual(OverlayList.cycleTab(from: "Git", by: -1, tabs: LibraryStore.defaultTabs), "zsh")
        XCTAssertEqual(OverlayList.cycleTab(from: "zsh", by: 1, tabs: LibraryStore.defaultTabs), "Git")
        XCTAssertEqual(OverlayList.cycleTab(from: "Git", by: 1, tabs: LibraryStore.defaultTabs), "Claude")
    }

    func testCycleTabMitUnbekanntemReiterBleibtStehen() {
        XCTAssertEqual(OverlayList.cycleTab(from: "Rust", by: 1, tabs: LibraryStore.defaultTabs), "Rust")
    }

    // MARK: - ViewModel

    func testStartZustand() {
        XCTAssertEqual(model.activeTab, "Git")
        XCTAssertEqual(model.selection, 0)
        XCTAssertFalse(model.isSearching)
    }

    func testReiterwechselLeertSucheUndSetztAuswahlAufZeileEins() {
        model.query = "git"
        model.moveSelection(by: 2)
        model.selectTab("zsh")
        XCTAssertEqual(model.activeTab, "zsh")
        XCTAssertEqual(model.query, "")
        XCTAssertEqual(model.selection, 0)
    }

    func testJedeSuchaenderungSetztAuswahlAufZeileEins() {
        model.moveSelection(by: 2)
        XCTAssertEqual(model.selection, 2)
        model.query = "git"
        XCTAssertEqual(model.selection, 0)
    }

    func testSucheLeerenFuehrtZumVorherigenReiterZurueck() {
        model.selectTab("zsh")
        model.query = "git"
        XCTAssertEqual(model.rows.count, 3)
        model.clearSearch()
        XCTAssertEqual(model.activeTab, "zsh")
        XCTAssertEqual(model.rows.map(\.label), ["ls -la"])
        XCTAssertEqual(model.selection, 0)
    }

    func testAuswahlKlemmtWennTrefferlisteSchrumpft() {
        model.query = "git"
        model.moveSelection(by: 2)
        XCTAssertEqual(model.selection, 2)
        model.query = "git commit"
        XCTAssertEqual(model.rows.count, 1)
        XCTAssertEqual(model.selection, 0)
        model.moveSelection(by: 5)
        XCTAssertEqual(model.selection, 0)
    }

    func testSelectedItemFolgtDerAuswahl() {
        XCTAssertEqual(model.selectedItem?.label, "git status -sb")
        model.moveSelection(by: 1)
        XCTAssertEqual(model.selectedItem?.label, "git log")
    }

    func testSelectedItemIstNilOhneTreffer() {
        model.query = "xyzzy"
        XCTAssertNil(model.selectedItem)
    }

    func testReiterPerNummer() {
        model.selectTab(number: 4)
        XCTAssertEqual(model.activeTab, "zsh")
        model.selectTab(number: 9)
        XCTAssertEqual(model.activeTab, "zsh")
    }

    func testCycleTabUeberViewModelLeertSuche() {
        model.query = "git"
        model.cycleTab(by: 1)
        XCTAssertEqual(model.query, "")
        XCTAssertEqual(model.activeTab, "Claude")
    }

    func testOeffnenSetztSucheUndAuswahlZurueck() {
        model.query = "git"
        model.moveSelection(by: 2)
        model.prepareForOpen()
        XCTAssertEqual(model.query, "")
        XCTAssertEqual(model.selection, 0)
        XCTAssertEqual(model.focusRequest, 1)
    }
    // MARK: - Kopieren (M8)

    /// Faengt Pasteboard-Schreibzugriffe ab, damit Tests die echte
    /// Zwischenablage nicht anfassen.
    private final class PasteboardSpy {
        private(set) var written: [String] = []
        var succeeds = true

        func write(_ text: String) -> Bool {
            guard succeeds else { return false }
            written.append(text)
            return true
        }
    }

    func testKopierenSchreibtLabelUndSetztFeedback() {
        let spy = PasteboardSpy()
        model.writeToPasteboard = spy.write

        XCTAssertTrue(model.copySelection())
        XCTAssertEqual(spy.written, ["git status -sb"])
        XCTAssertEqual(model.copiedItemID, sample[0].id)
        XCTAssertTrue(model.hasCopyFeedback)
        XCTAssertEqual(model.statusText, "Kopiert")
    }

    func testKopierenEinerBestimmtenZeile() {
        let spy = PasteboardSpy()
        model.writeToPasteboard = spy.write

        XCTAssertTrue(model.copy(sample[4]))
        XCTAssertEqual(spy.written, ["ls -la"])
        XCTAssertEqual(model.copiedItemID, sample[4].id)
    }

    func testKopierenOhneSichtbareZeileIstNoOp() {
        let spy = PasteboardSpy()
        model.writeToPasteboard = spy.write
        model.query = "xyzzy"

        XCTAssertNil(model.selectedItem)
        XCTAssertFalse(model.copySelection())
        XCTAssertTrue(spy.written.isEmpty)
        XCTAssertFalse(model.hasCopyFeedback)
    }

    func testPasteboardFehlerSetztKeinFeedback() {
        let spy = PasteboardSpy()
        spy.succeeds = false
        model.writeToPasteboard = spy.write

        XCTAssertFalse(model.copySelection())
        XCTAssertNil(model.copiedItemID)
        XCTAssertFalse(model.hasCopyFeedback)
    }

    func testStatustextOhneFeedbackZeigtZeilenzahl() {
        XCTAssertEqual(model.statusText, "3 Einträge")
    }

    // MARK: - Feedback endet bei der naechsten Aktion

    private func kopiereZeileEins() {
        let spy = PasteboardSpy()
        model.writeToPasteboard = spy.write
        model.copySelection()
        XCTAssertTrue(model.hasCopyFeedback)
    }

    func testFeedbackEndetBeiAuswahlwechsel() {
        kopiereZeileEins()
        model.moveSelection(by: 1)
        XCTAssertFalse(model.hasCopyFeedback)
    }

    func testFeedbackEndetBeiReiterwechsel() {
        kopiereZeileEins()
        model.selectTab("zsh")
        XCTAssertFalse(model.hasCopyFeedback)
    }

    func testFeedbackEndetBeiSuchaenderung() {
        kopiereZeileEins()
        model.query = "git"
        XCTAssertFalse(model.hasCopyFeedback)
    }

    func testFeedbackEndetBeiKlickAufAndereZeile() {
        kopiereZeileEins()
        model.select(index: 2)
        XCTAssertFalse(model.hasCopyFeedback)
    }

    func testFeedbackEndetBeimOeffnen() {
        kopiereZeileEins()
        model.prepareForOpen()
        XCTAssertFalse(model.hasCopyFeedback)
    }

    func testKlickAufCopyButtonSetztAuswahlUndKopiert() {
        let spy = PasteboardSpy()
        model.writeToPasteboard = spy.write

        // wie der Button: erst Auswahl setzen, dann kopieren
        model.select(index: 2)
        XCTAssertTrue(model.copy(sample[2]))
        XCTAssertEqual(model.selection, 2)
        XCTAssertEqual(spy.written, ["git commit -m"])
        XCTAssertTrue(model.hasCopyFeedback)
    }

    // MARK: - Editieren (M9)

    func testEditierenAendertBeideFelder() {
        model.update(itemID: sample[0].id, desc: "Neuer Text")
        XCTAssertEqual(store.items[0].desc, "Neuer Text")
        XCTAssertEqual(store.items[0].label, "git status -sb")

        model.update(itemID: sample[0].id, label: "git status")
        XCTAssertEqual(store.items[0].label, "git status")
    }

    func testEditierenMitUnbekannterIdIstNoOp() {
        let vorher = store.items
        model.update(itemID: UUID(), desc: "egal")
        XCTAssertEqual(store.items, vorher)
    }

    func testEditierenLaesstAndereEintraegeUnberuehrt() {
        model.update(itemID: sample[2].id, desc: "Geändert", label: "git commit")
        XCTAssertEqual(store.items[2].desc, "Geändert")
        XCTAssertEqual(store.items[2].label, "git commit")
        XCTAssertEqual(store.items[0], sample[0])
        XCTAssertEqual(store.items[4], sample[4])
    }

    // MARK: - Eintrag anlegen (SCR-05)

    func testNeuerEintragLandetInLetzterGruppeDesAktivenReiters() {
        let neu = model.addEntry()!
        XCTAssertEqual(neu.cat, "Git")
        XCTAssertEqual(neu.group, "Committen")
        XCTAssertEqual(neu.desc, "")
        XCTAssertEqual(neu.label, "")

        let gruppen = model.sections
        XCTAssertEqual(gruppen.last?.name, "Committen")
        XCTAssertEqual(gruppen.last?.items.last?.id, neu.id)
    }

    func testNeuerEintragImLeerenReiterNutztAllgemein() {
        model.selectTab("Python")
        XCTAssertTrue(model.rows.isEmpty)

        let neu = model.addEntry()!
        XCTAssertEqual(neu.cat, "Python")
        XCTAssertEqual(neu.group, "Allgemein")
        XCTAssertEqual(model.sections.map(\.name), ["Allgemein"])
    }

    func testNeuerEintragIstDieLetzteZeileUndAusgewaehlt() {
        let neu = model.addEntry()!
        XCTAssertEqual(model.rows.count, 4)
        XCTAssertEqual(model.selection, 3)
        XCTAssertEqual(model.selectedItem?.id, neu.id)
    }

    func testNeuerEintragLeertDieSuche() {
        model.query = "git"
        XCTAssertTrue(model.isSearching)

        let neu = model.addEntry()!
        XCTAssertEqual(model.query, "")
        XCTAssertFalse(model.isSearching)
        XCTAssertEqual(neu.cat, "Git")
        XCTAssertEqual(model.selectedItem?.id, neu.id)
    }

    func testNeuerEintragFordertFokusInDerBeschreibung() {
        let vorher = model.focusRequest
        let neu = model.addEntry()!
        XCTAssertEqual(model.focusRequest, vorher + 1)
        XCTAssertEqual(model.requestedFocus, .description(neu.id))
    }

    func testKopierenEinerLeerenZeileIstNoOp() {
        let spy = PasteboardSpy()
        model.writeToPasteboard = spy.write
        let neu = model.addEntry()!

        XCTAssertFalse(model.copy(neu))
        XCTAssertFalse(model.copySelection())
        XCTAssertTrue(spy.written.isEmpty)
        XCTAssertFalse(model.hasCopyFeedback)
    }

    // MARK: - Fokus (SCR-03)

    func testZeilenfelderGeltenAlsEditieren() {
        XCTAssertFalse(model.isEditingRow)
        model.focusedField = .search
        XCTAssertFalse(model.isEditingRow)
        model.focusedField = .description(sample[0].id)
        XCTAssertTrue(model.isEditingRow)
        model.focusedField = .command(sample[0].id)
        XCTAssertTrue(model.isEditingRow)
    }

    func testFeldVerlassenFordertFokusImSuchfeld() {
        model.focusedField = .command(sample[0].id)
        let vorher = model.focusRequest
        model.leaveField()
        XCTAssertEqual(model.requestedFocus, .search)
        XCTAssertEqual(model.focusRequest, vorher + 1)
    }

    // MARK: - Persistenz (M10)

    func testSpeichernSchreibtAenderungInDieDatei() throws {
        let fileURL = tempDirectory.appendingPathComponent("persist.json")
        try JSONEncoder().encode(sample).write(to: fileURL)
        let persistent = LibraryStore(fileURL: fileURL, seedURL: nil)
        try persistent.load()
        let persistentModel = OverlayViewModel(store: persistent)

        persistentModel.update(itemID: sample[0].id, desc: "Editiert und gespeichert")
        persistentModel.addEntry()
        XCTAssertTrue(persistentModel.save())

        let reloaded = LibraryStore(fileURL: fileURL, seedURL: nil)
        try reloaded.load()
        XCTAssertEqual(reloaded.items.count, 6)
        XCTAssertEqual(reloaded.items.first?.desc, "Editiert und gespeichert")
    }

    func testSpeichernNachFehlgeschlagenemLadenWirdVerweigert() {
        // store wurde nie geladen, der isLoaded-Schutz aus P1 greift.
        XCTAssertFalse(model.save())
    }

    // MARK: - Beweis Root Cause P5-Bug

    /// Die View beobachtet OverlayViewModel. Aendert sich store.items, muss das
    /// beim ViewModel ankommen, sonst zeichnet die View nicht neu und das
    /// TextField liest weiter den alten Wert.
    func testStoreAenderungBenachrichtigtDasViewModel() {
        var benachrichtigungen = 0
        let abo = model.objectWillChange.sink { _ in benachrichtigungen += 1 }
        defer { abo.cancel() }

        model.update(itemID: sample[0].id, desc: "getippt")

        XCTAssertEqual(store.items[0].desc, "getippt", "Store wurde geschrieben")
        XCTAssertGreaterThan(benachrichtigungen, 0, "ViewModel meldet die Aenderung nicht weiter")
    }

    // MARK: - esc-Leiter (M6)

    func testEscapeSchliesstPanelImRuhezustand() {
        XCTAssertEqual(model.escapeAction(), .closePanel)
    }

    func testEscapeLeertZuerstDieSuche() {
        model.query = "git"
        XCTAssertEqual(model.escapeAction(), .clearSearch)
    }

    func testEscapeVerlaesstZuerstDasZeilenfeld() {
        model.focusedField = .description(sample[0].id)
        XCTAssertEqual(model.escapeAction(), .leaveField)

        // Auch bei gleichzeitig aktiver Suche gewinnt das Feld.
        model.query = "git"
        model.focusedField = .command(sample[0].id)
        XCTAssertEqual(model.escapeAction(), .leaveField)
    }

    func testEscapeImSuchfeldIstKeinFeldVerlassen() {
        model.focusedField = .search
        XCTAssertEqual(model.escapeAction(), .closePanel)
    }

    func testFeldVerlassenLaesstAuswahlStehenUndSetztZustandSofort() {
        model.moveSelection(by: 2)
        model.focusedField = .command(sample[2].id)

        model.leaveField()

        XCTAssertEqual(model.selection, 2, "Auswahl bleibt auf der Zeile")
        XCTAssertFalse(model.isEditingRow, "Zustand gilt sofort, nicht erst nach dem Neuzeichnen")
        XCTAssertEqual(model.escapeAction(), .closePanel, "zweites esc schliesst")
    }

    // MARK: - Umbenennen (K3)

    func testReiterUmbenennenZiehtAlleEintraegeMit() {
        XCTAssertTrue(store.renameTab(from: "Git", to: "Version Control"))
        XCTAssertEqual(store.tabs, ["Version Control", "Claude", "Python", "zsh"])
        XCTAssertEqual(store.items(in: "Version Control").count, 3)
        XCTAssertTrue(store.items(in: "Git").isEmpty)
        XCTAssertEqual(store.items(in: "zsh").count, 1, "andere Reiter unberührt")
    }

    func testReiterUmbenennenLehntDuplikatAb() {
        XCTAssertFalse(store.renameTab(from: "Git", to: "zsh"))
        XCTAssertEqual(store.tabs, LibraryStore.defaultTabs)
        XCTAssertEqual(store.items(in: "Git").count, 3)
    }

    func testReiterUmbenennenLehntLeerenNamenAb() {
        XCTAssertFalse(store.renameTab(from: "Git", to: ""))
        XCTAssertFalse(store.renameTab(from: "Git", to: "   "))
        XCTAssertEqual(store.tabs, LibraryStore.defaultTabs)
    }

    /// Mit P8 werden leere Reiter absichtlich angelegt, also muessen sie auch
    /// umbenennbar sein. Die K3-Einschraenkung ist dort entfallen.
    func testLeererReiterIstUmbenennbar() {
        XCTAssertTrue(store.items(in: "Python").isEmpty)
        XCTAssertTrue(store.renameTab(from: "Python", to: "Py"))
        XCTAssertEqual(store.tabs, ["Git", "Claude", "Py", "zsh"])
    }

    func testReiterUmbenennenSchneidetLeerzeichenAb() {
        XCTAssertTrue(store.renameTab(from: "Git", to: "  Repo  "))
        XCTAssertEqual(store.tabs.first, "Repo")
        XCTAssertEqual(store.items(in: "Repo").count, 3)
    }

    func testGruppeUmbenennenNurImAktivenReiter() {
        // "Status" gibt es in Git; in zsh wird absichtlich eine gleichnamige angelegt.
        store.items.append(LibraryItem(cat: "zsh", group: "Status", label: "uptime", desc: "Laufzeit"))

        XCTAssertTrue(store.renameGroup(in: "Git", from: "Status", to: "Zustand"))
        XCTAssertEqual(store.groups(in: "Git").map(\.name), ["Zustand", "Committen"])
        XCTAssertEqual(store.groups(in: "zsh").map(\.name), ["Allgemein", "Status"],
                       "gleichnamige Gruppe im anderen Reiter bleibt unberührt")
    }

    func testGruppeUmbenennenLehntDuplikatUndLeerAb() {
        XCTAssertFalse(store.renameGroup(in: "Git", from: "Status", to: "Committen"))
        XCTAssertFalse(store.renameGroup(in: "Git", from: "Status", to: " "))
        XCTAssertFalse(store.renameGroup(in: "Git", from: "Gibtsnicht", to: "Neu"))
        XCTAssertEqual(store.groups(in: "Git").map(\.name), ["Status", "Committen"])
    }

    func testGleicherNameIstEinAkzeptierterNoOp() {
        XCTAssertTrue(store.renameTab(from: "Git", to: "Git"))
        XCTAssertTrue(store.renameGroup(in: "Git", from: "Status", to: "Status"))
        XCTAssertEqual(store.tabs, LibraryStore.defaultTabs)
    }

    func testReiterReihenfolgeUeberlebtSpeichernUndLaden() throws {
        let fileURL = tempDirectory.appendingPathComponent("tabs.json")
        try JSONEncoder().encode(sample).write(to: fileURL)
        let persistent = LibraryStore(fileURL: fileURL, seedURL: nil)
        try persistent.load()
        XCTAssertEqual(persistent.tabs, LibraryStore.defaultTabs, "altes Array-Format wird gelesen")

        XCTAssertTrue(persistent.renameTab(from: "Git", to: "Repo"))
        try persistent.save()

        let reloaded = LibraryStore(fileURL: fileURL, seedURL: nil)
        try reloaded.load()
        XCTAssertEqual(reloaded.tabs, ["Repo", "Claude", "Python", "zsh"])
        XCTAssertEqual(reloaded.items(in: "Repo").count, 3)
    }

    // MARK: - Umbenennen ueber das ViewModel

    func testUmbenennenBeiAktiverSucheWirdAbgelehnt() {
        model.query = "git"
        XCTAssertFalse(model.beginRename(.tab("Git")))
        XCTAssertFalse(model.beginRename(.group("Status")))
        XCTAssertFalse(model.isRenaming)
    }

    func testBeginRenameSetztEntwurfUndFokus() {
        let vorher = model.focusRequest
        XCTAssertTrue(model.beginRename(.tab("Git")))
        XCTAssertEqual(model.renaming, .tab("Git"))
        XCTAssertEqual(model.renameDraft, "Git")
        XCTAssertEqual(model.requestedFocus, .rename)
        XCTAssertEqual(model.focusRequest, vorher + 1)
        XCTAssertTrue(model.blocksNavigationKeys)
    }

    func testAbbrechenLaesstAltenNamenStehen() {
        model.beginRename(.tab("Git"))
        model.renameDraft = "Etwas anderes"
        model.cancelRename()

        XCTAssertFalse(model.isRenaming)
        XCTAssertEqual(store.tabs, LibraryStore.defaultTabs)
        XCTAssertEqual(model.activeTab, "Git")
    }

    func testUebernehmenZiehtDenAktivenReiterNach() {
        model.beginRename(.tab("Git"))
        model.renameDraft = "Repo"
        XCTAssertTrue(model.commitRename())

        XCTAssertEqual(model.activeTab, "Repo")
        XCTAssertEqual(model.tabs.first, "Repo")
        XCTAssertFalse(model.isRenaming)
        XCTAssertEqual(model.rows.count, 3, "Zeilen des Reiters bleiben sichtbar")
    }

    func testAbgelehnteUebernahmeAendertNichts() {
        model.beginRename(.tab("Git"))
        model.renameDraft = "zsh"
        XCTAssertFalse(model.commitRename())

        XCTAssertEqual(store.tabs, LibraryStore.defaultTabs)
        XCTAssertEqual(model.activeTab, "Git")
        XCTAssertFalse(model.isRenaming)
    }

    func testEscapeBrichtZuerstDieUmbenennungAb() {
        model.query = ""
        model.beginRename(.group("Status"))
        XCTAssertEqual(model.escapeAction(), .cancelRename)

        model.cancelRename()
        XCTAssertEqual(model.escapeAction(), .closePanel)
    }

    // MARK: - Sortieren (P8)

    private var git: [LibraryItem] { store.items.filter { $0.cat == "Git" } }

    func testZeileInnerhalbDerGruppeVerschieben() {
        // Git/Status: [git status -sb, git log] → log vor status
        let log = sample[1]
        store.items = LibraryOrder.moveItem(store.items, id: log.id, to: .before(sample[0].id), in: "Git")

        XCTAssertEqual(git.map(\.label), ["git log", "git status -sb", "git commit -m"])
        XCTAssertEqual(git.map(\.group), ["Status", "Status", "Committen"])
    }

    func testZeileUeberGruppengrenzeVerschiebenSetztGroup() {
        store.items = LibraryOrder.moveItem(store.items, id: sample[0].id,
                                            to: .before(sample[2].id), in: "Git")

        XCTAssertEqual(git.map(\.label), ["git log", "git status -sb", "git commit -m"])
        XCTAssertEqual(store.items.first(where: { $0.id == sample[0].id })?.group, "Committen")
        XCTAssertEqual(store.groups(in: "Git").map(\.name), ["Status", "Committen"])
    }

    func testZeileAnsEndeEinerGruppeVerschieben() {
        store.items = LibraryOrder.moveItem(store.items, id: sample[0].id,
                                            to: .endOfGroup("Committen"), in: "Git")
        XCTAssertEqual(git.map(\.label), ["git log", "git commit -m", "git status -sb"])
        XCTAssertEqual(git.last?.group, "Committen")
    }

    func testZeileInNochLeereGruppeVerschieben() {
        XCTAssertTrue(store.addGroup("Neu", in: "Git"))
        store.items = LibraryOrder.moveItem(store.items, id: sample[0].id,
                                            to: .endOfGroup("Neu"), in: "Git")

        XCTAssertEqual(store.groups(in: "Git").map(\.name), ["Status", "Committen", "Neu"])
        XCTAssertEqual(store.groups(in: "Git").last?.items.map(\.label), ["git status -sb"])
    }

    func testVerschiebenLaesstAndereReiterUnberuehrt() {
        let vorher = store.items.filter { $0.cat != "Git" }
        store.items = LibraryOrder.moveItem(store.items, id: sample[0].id,
                                            to: .endOfGroup("Committen"), in: "Git")
        XCTAssertEqual(store.items.filter { $0.cat != "Git" }, vorher)
    }

    func testDropAufSichSelbstAendertNichts() {
        let vorher = store.items
        store.items = LibraryOrder.moveItem(store.items, id: sample[0].id,
                                            to: .before(sample[0].id), in: "Git")
        XCTAssertEqual(store.items, vorher)
    }

    // MARK: - Gruppe als Block verschieben

    func testGruppeWandertAlsBlock() {
        store.items = LibraryOrder.moveGroup(store.items, group: "Committen",
                                             before: "Status", in: "Git")
        XCTAssertEqual(git.map(\.label), ["git commit -m", "git status -sb", "git log"])
        XCTAssertEqual(store.groups(in: "Git").map(\.name), ["Committen", "Status"])
    }

    func testGruppeAnsEndeVerschieben() {
        store.items = LibraryOrder.moveGroup(store.items, group: "Status", before: nil, in: "Git")
        XCTAssertEqual(git.map(\.label), ["git commit -m", "git status -sb", "git log"])
        XCTAssertEqual(store.groups(in: "Git").first?.items.count, 1)
        XCTAssertEqual(store.groups(in: "Git").last?.items.map(\.label), ["git status -sb", "git log"],
                       "Reihenfolge im Block bleibt erhalten")
    }

    func testUnbekannteGruppeAendertNichts() {
        let vorher = store.items
        store.items = LibraryOrder.moveGroup(store.items, group: "Gibtsnicht", before: "Status", in: "Git")
        XCTAssertEqual(store.items, vorher)
    }

    // MARK: - Gruppen anlegen und loeschen

    func testLeereGruppeAnlegenUndLoeschen() {
        XCTAssertTrue(store.addGroup("Notizen", in: "Git"))
        XCTAssertEqual(store.groups(in: "Git").map(\.name), ["Status", "Committen", "Notizen"])
        XCTAssertTrue(store.groups(in: "Git").last?.items.isEmpty ?? false)

        XCTAssertTrue(store.removeGroup("Notizen", in: "Git"))
        XCTAssertEqual(store.groups(in: "Git").map(\.name), ["Status", "Committen"])
    }

    /// Mit P9 entfaellt die Leer-Bedingung: die Gruppe geht samt Eintraegen.
    func testNichtLeereGruppeIstLoeschbar() {
        XCTAssertTrue(store.removeGroup("Status", in: "Git"))
        XCTAssertEqual(store.groups(in: "Git").map(\.name), ["Committen"])
        XCTAssertEqual(store.items(in: "Git").map(\.label), ["git commit -m"])
    }

    func testGruppeAnlegenLehntLeerUndDuplikatAb() {
        XCTAssertFalse(store.addGroup("  ", in: "Git"))
        XCTAssertFalse(store.addGroup("Status", in: "Git"))
    }

    // MARK: - Reiter anlegen, loeschen, umsortieren

    func testLeerenReiterAnlegenUndLoeschen() {
        XCTAssertTrue(store.addTab("Docker"))
        XCTAssertEqual(store.tabs.last, "Docker")
        XCTAssertTrue(store.removeTab("Docker"))
        XCTAssertEqual(store.tabs, LibraryStore.defaultTabs)
    }

    /// Mit P9 entfaellt die Leer-Bedingung: der Reiter geht samt Eintraegen.
    func testNichtLeererReiterIstLoeschbar() {
        XCTAssertTrue(store.removeTab("Git"))
        XCTAssertEqual(store.tabs, ["Claude", "Python", "zsh"])
        XCTAssertTrue(store.items(in: "Git").isEmpty)
    }

    func testReiterAnlegenLehntLeerUndDuplikatAb() {
        XCTAssertFalse(store.addTab(" "))
        XCTAssertFalse(store.addTab("Git"))
    }

    func testReiterUmsortieren() {
        store.moveTab("zsh", before: "Git")
        XCTAssertEqual(store.tabs, ["zsh", "Git", "Claude", "Python"])

        store.moveTab("zsh", before: nil)
        XCTAssertEqual(store.tabs, ["Git", "Claude", "Python", "zsh"])
    }

    // MARK: - ⌘-Kuerzel

    func testKuerzelFolgenDerReihenfolge() {
        XCTAssertEqual(model.shortcut(for: "Git"), 1)
        XCTAssertEqual(model.shortcut(for: "zsh"), 4)

        store.moveTab("zsh", before: "Git")
        XCTAssertEqual(model.shortcut(for: "zsh"), 1)
        XCTAssertEqual(model.shortcut(for: "Git"), 2)
    }

    func testAbDemZehntenReiterKeinKuerzel() {
        for nummer in 5 ... 12 { XCTAssertTrue(store.addTab("Reiter \(nummer)")) }
        XCTAssertEqual(store.tabs.count, 12)

        XCTAssertEqual(LibraryOrder.shortcut(forTabAt: 8), 9)
        XCTAssertNil(LibraryOrder.shortcut(forTabAt: 9))
        XCTAssertEqual(model.shortcut(for: store.tabs[8]), 9)
        XCTAssertNil(model.shortcut(for: store.tabs[9]))
    }

    func testUnbekannterReiterHatKeinKuerzel() {
        XCTAssertNil(model.shortcut(for: "Gibtsnicht"))
    }

    // MARK: - Keine Umsortierung bei aktiver Suche

    func testBeiAktiverSucheWirdNichtSortiert() {
        model.query = "git"
        XCTAssertFalse(model.canReorder)

        let vorher = store.items
        model.moveItem(id: sample[0].id, to: .endOfGroup("Committen"))
        model.moveGroup("Status", before: nil)
        model.moveTab("zsh", before: "Git")
        XCTAssertEqual(store.items, vorher)
        XCTAssertEqual(store.tabs, LibraryStore.defaultTabs)
        XCTAssertFalse(model.addGroup())
        XCTAssertFalse(model.addTab())
    }

    // MARK: - Persistenz der Reihenfolge

    func testReihenfolgeUeberlebtSpeichernUndLaden() throws {
        let fileURL = tempDirectory.appendingPathComponent("order.json")
        try JSONEncoder().encode(sample).write(to: fileURL)
        let persistent = LibraryStore(fileURL: fileURL, seedURL: nil)
        try persistent.load()

        persistent.moveGroup("Committen", before: "Status", in: "Git")
        persistent.moveItem(id: sample[1].id, to: .endOfGroup("Committen"), in: "Git")
        persistent.moveTab("zsh", before: "Git")
        try persistent.save()

        let reloaded = LibraryStore(fileURL: fileURL, seedURL: nil)
        try reloaded.load()
        XCTAssertEqual(reloaded.tabs, ["zsh", "Git", "Claude", "Python"])
        XCTAssertEqual(reloaded.items.filter { $0.cat == "Git" }.map(\.label),
                       ["git commit -m", "git log", "git status -sb"])
        XCTAssertEqual(reloaded.groups(in: "Git").map(\.name), ["Committen", "Status"])
    }

    func testLeereGruppeUeberlebtDenNeustartNicht() throws {
        let fileURL = tempDirectory.appendingPathComponent("empty.json")
        try JSONEncoder().encode(sample).write(to: fileURL)
        let persistent = LibraryStore(fileURL: fileURL, seedURL: nil)
        try persistent.load()
        XCTAssertTrue(persistent.addGroup("Leer", in: "Git"))
        try persistent.save()

        let reloaded = LibraryStore(fileURL: fileURL, seedURL: nil)
        try reloaded.load()
        XCTAssertEqual(reloaded.groups(in: "Git").map(\.name), ["Status", "Committen"],
                       "Folge der Grundsatzentscheidung: das Format kennt keine leere Gruppe")
    }

    func testLeererReiterUeberlebtDenNeustart() throws {
        let fileURL = tempDirectory.appendingPathComponent("emptytab.json")
        try JSONEncoder().encode(sample).write(to: fileURL)
        let persistent = LibraryStore(fileURL: fileURL, seedURL: nil)
        try persistent.load()
        XCTAssertTrue(persistent.addTab("Docker"))
        try persistent.save()

        let reloaded = LibraryStore(fileURL: fileURL, seedURL: nil)
        try reloaded.load()
        XCTAssertEqual(reloaded.tabs, ["Git", "Claude", "Python", "zsh", "Docker"])
    }

    // MARK: - Beweis Root Cause P8-Bug (Plus in der Reiterleiste)

    /// Prueft den gesamten Modellpfad hinter dem Plus-Knopf. Ist der gruen,
    /// liegt der Fehler nicht im Model, sondern in der View.
    func testAddTabLegtReiterAnUndStartetUmbenennung() {
        let vorher = store.tabs

        XCTAssertTrue(model.addTab(), "addTab meldet Erfolg")

        XCTAssertEqual(store.tabs.count, vorher.count + 1)
        XCTAssertEqual(store.tabs.last, "Neuer Reiter")
        XCTAssertEqual(model.activeTab, "Neuer Reiter", "neuer Reiter ist aktiv")
        XCTAssertEqual(model.renaming, .tab("Neuer Reiter"), "Namensfeld ist offen")
        XCTAssertEqual(model.renameDraft, "Neuer Reiter")
        XCTAssertEqual(model.requestedFocus, .rename)
    }

    func testNeuerReiterUeberlebtDasUmbenennenMitNeuemNamen() {
        XCTAssertTrue(model.addTab())
        model.renameDraft = "Docker"
        XCTAssertTrue(model.commitRename(), "leerer Reiter muss umbenennbar sein")
        XCTAssertEqual(store.tabs.last, "Docker")
        XCTAssertEqual(model.activeTab, "Docker")
    }

    // MARK: - Loeschen und Undo (P9)

    func testZeileLoeschenUndWiederherstellen() {
        model.moveSelection(by: 1)                      // "git log", Index 1
        XCTAssertEqual(model.selectedItem?.label, "git log")

        XCTAssertTrue(model.deleteSelection())
        XCTAssertEqual(git.map(\.label), ["git status -sb", "git commit -m"])
        XCTAssertTrue(model.canUndo)
        XCTAssertEqual(model.statusText, "Gelöscht · ⌘Z")

        XCTAssertTrue(model.undoDelete())
        XCTAssertEqual(git.map(\.label), ["git status -sb", "git log", "git commit -m"],
                       "an derselben Position")
        XCTAssertEqual(store.items, sample, "gesamtes Array identisch")
        XCTAssertFalse(model.canUndo)
    }

    func testZeileAusDemSeedIstLoeschbar() {
        XCTAssertTrue(model.deleteSelection())
        XCTAssertFalse(store.items.contains(sample[0]))
    }

    func testGruppeMitEintraegenLoeschenUndUndo() {
        XCTAssertEqual(store.groups(in: "Git").first?.items.count, 2)

        XCTAssertTrue(model.deleteGroup("Status"))
        XCTAssertEqual(git.map(\.label), ["git commit -m"])
        XCTAssertEqual(store.groups(in: "Git").map(\.name), ["Committen"])

        XCTAssertTrue(model.undoDelete())
        XCTAssertEqual(store.items, sample)
        XCTAssertEqual(store.groups(in: "Git").map(\.name), ["Status", "Committen"])
    }

    func testReiterMitEintraegenLoeschenUndUndoAnGleichemIndex() {
        XCTAssertTrue(model.deleteTab("Claude"))
        XCTAssertEqual(store.tabs, ["Git", "Python", "zsh"])
        XCTAssertTrue(store.items(in: "Claude").isEmpty)

        XCTAssertTrue(model.undoDelete())
        XCTAssertEqual(store.tabs, LibraryStore.defaultTabs, "wieder an Index 1")
        XCTAssertEqual(store.items, sample)
    }

    func testLetzterReiterIstLoeschbar() {
        for tab in LibraryStore.defaultTabs { model.deleteTab(tab) }
        XCTAssertTrue(store.tabs.isEmpty)
        XCTAssertTrue(store.items.isEmpty)
        XCTAssertEqual(model.activeTab, "")
        XCTAssertTrue(model.rows.isEmpty)
        XCTAssertTrue(model.entries.isEmpty)
        XCTAssertEqual(model.statusText, "Gelöscht · ⌘Z")
    }

    func testLeererZustandBleibtBedienbar() {
        for tab in LibraryStore.defaultTabs { model.deleteTab(tab) }

        XCTAssertNil(model.selectedItem, "kein Absturz ohne Auswahl")
        XCTAssertFalse(model.copySelection())
        XCTAssertNil(model.addEntry(), "ohne Reiter kein Eintrag")
        XCTAssertFalse(model.addGroup())
        XCTAssertFalse(model.beginRename(.tab("")))
        model.moveSelection(by: 1)
        model.cycleTab(by: 1)
        model.selectTab(number: 1)
        XCTAssertEqual(model.activeTab, "")

        XCTAssertTrue(model.addTab(), "+ legt wieder einen Reiter an")
        XCTAssertEqual(model.activeTab, "Neuer Reiter")
    }

    func testLeererZustandIstSpeicherbarUndLadbar() throws {
        let fileURL = tempDirectory.appendingPathComponent("leer.json")
        try JSONEncoder().encode(sample).write(to: fileURL)
        let persistent = LibraryStore(fileURL: fileURL, seedURL: nil)
        try persistent.load()
        let persistentModel = OverlayViewModel(store: persistent)

        for tab in LibraryStore.defaultTabs { persistentModel.deleteTab(tab) }
        XCTAssertTrue(persistentModel.save())

        let reloaded = LibraryStore(fileURL: fileURL, seedURL: nil)
        try reloaded.load()
        XCTAssertTrue(reloaded.tabs.isEmpty)
        XCTAssertTrue(reloaded.items.isEmpty)
        XCTAssertEqual(OverlayViewModel(store: reloaded).activeTab, "")
    }

    func testDateiMitLeerenTabsUndItemsWirdGeladen() throws {
        let fileURL = tempDirectory.appendingPathComponent("blank.json")
        try Data(#"{"items":[],"tabs":[]}"#.utf8).write(to: fileURL)

        let store = LibraryStore(fileURL: fileURL, seedURL: nil)
        XCTAssertNoThrow(try store.load())
        XCTAssertTrue(store.tabs.isEmpty)
        XCTAssertTrue(store.items.isEmpty)
        XCTAssertTrue(store.groups(in: "").isEmpty)
    }

    // MARK: - Undo verfaellt bei anderer Aktion

    func testAndereAktionVerwirftDasUndo() {
        XCTAssertTrue(model.deleteSelection())
        XCTAssertTrue(model.canUndo)

        model.moveSelection(by: 1)
        XCTAssertFalse(model.canUndo)
        XCTAssertFalse(model.undoDelete())
        XCTAssertEqual(model.statusText, "2 Einträge")
    }

    func testKopierenVerdraengtDenLoeschhinweis() {
        let spy = PasteboardSpy()
        model.writeToPasteboard = spy.write
        XCTAssertTrue(model.deleteSelection())

        XCTAssertTrue(model.copySelection())
        XCTAssertEqual(model.statusText, "Kopiert")
        XCTAssertFalse(model.canUndo)
    }

    func testUmsortierenVerwirftDasUndo() {
        XCTAssertTrue(model.deleteSelection())
        model.moveGroup("Committen", before: "Status")
        XCTAssertFalse(model.canUndo)
    }

    // MARK: - Kein Loeschen bei Suche, Fokus, Umbenennung

    func testKeinLoeschenBeiAktiverSuche() {
        model.query = "git"
        XCTAssertFalse(model.canDelete)
        XCTAssertFalse(model.deleteSelection())
        XCTAssertFalse(model.deleteGroup("Status"))
        XCTAssertFalse(model.deleteTab("Git"))
        XCTAssertEqual(store.items, sample)
    }

    func testKeinLoeschenMitFokusImZeilenfeld() {
        model.focusedField = .command(sample[0].id)
        XCTAssertFalse(model.canDelete)
        XCTAssertFalse(model.deleteSelection())
        XCTAssertEqual(store.items, sample)
    }

    func testKeinLoeschenWaehrendUmbenennung() {
        XCTAssertTrue(model.beginRename(.group("Status")))
        XCTAssertFalse(model.canDelete)
        XCTAssertFalse(model.deleteSelection())
        XCTAssertFalse(model.deleteGroup("Status"))
        XCTAssertFalse(model.deleteTab("Git"))
        XCTAssertEqual(store.items, sample)
    }

    func testUndoOhneLoeschenIstNoOp() {
        XCTAssertFalse(model.undoDelete())
        XCTAssertEqual(store.items, sample)
    }

}
