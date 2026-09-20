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
        XCTAssertEqual(OverlayList.cycleTab(from: "Git", by: -1), "zsh")
        XCTAssertEqual(OverlayList.cycleTab(from: "zsh", by: 1), "Git")
        XCTAssertEqual(OverlayList.cycleTab(from: "Git", by: 1), "Claude")
    }

    func testCycleTabMitUnbekanntemReiterBleibtStehen() {
        XCTAssertEqual(OverlayList.cycleTab(from: "Rust", by: 1), "Rust")
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

}
