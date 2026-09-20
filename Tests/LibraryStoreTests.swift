import XCTest

final class LibraryStoreTests: XCTestCase {
    private var tempDirectory: URL!

    override func setUpWithError() throws {
        tempDirectory = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("CheatsheetTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempDirectory)
    }

    private var seedURL: URL {
        Bundle(for: Self.self).url(forResource: "seed", withExtension: "json")!
    }

    private func makeStore() -> LibraryStore {
        LibraryStore(fileURL: tempDirectory.appendingPathComponent("library.json"), seedURL: seedURL)
    }

    private let sample = [
        LibraryItem(cat: "Git", group: "Status", label: "git status -sb", desc: "Kurzstatus"),
        LibraryItem(cat: "Git", group: "Committen", label: "git commit -m", desc: "Änderung sichern"),
        LibraryItem(cat: "Git", group: "Status", label: "git log", desc: "Historie zeigen"),
        LibraryItem(cat: "zsh", group: "Allgemein", label: "ls -la", desc: "Dateien mit Details"),
    ]

    // MARK: - Laden / Seed

    func testErststartErzeugtDateiAusSeed() throws {
        let store = makeStore()
        XCTAssertFalse(FileManager.default.fileExists(atPath: store.fileURL.path))

        let seeded = try store.load()

        XCTAssertTrue(seeded)
        XCTAssertTrue(FileManager.default.fileExists(atPath: store.fileURL.path))
        XCTAssertEqual(store.items.count, 28)
        XCTAssertEqual(Set(store.items.map(\.cat)), Set(LibraryStore.tabs))
    }

    func testZweiterStartLiestDateiUndSeedetNichtErneut() throws {
        let first = makeStore()
        try first.load()
        first.items.removeAll { $0.cat != "zsh" }
        try first.save()

        let second = makeStore()
        let seeded = try second.load()

        XCTAssertFalse(seeded)
        XCTAssertEqual(second.items, first.items)
    }

    /// M10: ein Edit der Datei ausserhalb der App erscheint beim naechsten Laden.
    func testManuellerEditDerDateiWirdGelesen() throws {
        let store = makeStore()
        try store.load()

        let edited = [LibraryItem(cat: "Python", group: "Umgebung", label: "python3 -m venv .venv", desc: "Neu")]
        let data = try JSONEncoder().encode(edited)
        try data.write(to: store.fileURL)

        let reloaded = makeStore()
        try reloaded.load()
        XCTAssertEqual(reloaded.items, edited)
    }

    // MARK: - Speichern

    func testSpeichernUndLadenIstVerlustfrei() throws {
        let store = makeStore()
        try store.load()
        store.items = sample
        try store.save()

        let reloaded = makeStore()
        try reloaded.load()
        XCTAssertEqual(reloaded.items, sample)
    }

    func testSpeichernUeberschreibtBestehendeDateiVollstaendig() throws {
        let store = makeStore()
        try store.load()
        store.items = sample
        try store.save()

        store.items = [sample[0]]
        try store.save()

        let reloaded = makeStore()
        try reloaded.load()
        XCTAssertEqual(reloaded.items, [sample[0]])
    }

    // MARK: - Filter (label / desc / cat)

    func testFilterFindetLabel() {
        let store = makeStore()
        store.items = sample
        XCTAssertEqual(store.search("commit").map(\.label), ["git commit -m"])
    }

    func testFilterFindetBeschreibung() {
        let store = makeStore()
        store.items = sample
        XCTAssertEqual(store.search("Historie").map(\.label), ["git log"])
    }

    func testFilterFindetKategorie() {
        let store = makeStore()
        store.items = sample
        XCTAssertEqual(store.search("zsh").map(\.label), ["ls -la"])
    }

    func testFilterIgnoriertGrossKleinschreibungUndDiakritika() {
        let store = makeStore()
        store.items = sample
        XCTAssertEqual(store.search("ANDERUNG").map(\.label), ["git commit -m"])
    }

    func testLeereQueryLiefertAlles() {
        let store = makeStore()
        store.items = sample
        XCTAssertEqual(store.search("   ").count, sample.count)
    }

    func testFantasieQueryLiefertNichts() {
        let store = makeStore()
        store.items = sample
        XCTAssertTrue(store.search("xyzzy").isEmpty)
    }

    // MARK: - Gruppierung

    func testGruppenReihenfolgeFolgtErstemAuftreten() {
        let store = makeStore()
        store.items = sample
        XCTAssertEqual(store.groups(in: "Git").map(\.name), ["Status", "Committen"])
    }

    func testGruppeBuendeltAlleEintraege() {
        let store = makeStore()
        store.items = sample
        XCTAssertEqual(store.groups(in: "Git").first?.items.map(\.label), ["git status -sb", "git log"])
    }

    func testLeererReiterLiefertKeineGruppen() {
        let store = makeStore()
        store.items = sample
        XCTAssertTrue(store.groups(in: "Claude").isEmpty)
    }

    func testSeedGruppenReihenfolgeProReiter() throws {
        let store = makeStore()
        try store.load()
        XCTAssertEqual(store.groups(in: "Git").map(\.name),
                       ["Status & Historie", "Committen", "Branches & Remote"])
        XCTAssertEqual(store.groups(in: "zsh").map(\.name), ["Allgemein"])
    }

    func testReiterReihenfolgeIstFest() {
        XCTAssertEqual(LibraryStore.tabs, ["Git", "Claude", "Python", "zsh"])
    }

    // MARK: - Index-Klemmung

    func testClampHaeltIndexImBereich() {
        XCTAssertEqual(LibraryStore.clamp(3, count: 10), 3)
        XCTAssertEqual(LibraryStore.clamp(-1, count: 10), 0)
        XCTAssertEqual(LibraryStore.clamp(10, count: 10), 9)
        XCTAssertEqual(LibraryStore.clamp(99, count: 4), 3)
    }

    func testClampBeiLeererListe() {
        XCTAssertEqual(LibraryStore.clamp(0, count: 0), 0)
        XCTAssertEqual(LibraryStore.clamp(5, count: 0), 0)
        XCTAssertEqual(LibraryStore.clamp(-5, count: 0), 0)
    }

    /// Filterwechsel verkleinert die Trefferliste: der alte Index muss klemmen.
    func testClampNachFilterwechsel() {
        let store = makeStore()
        store.items = sample
        let selection = 3
        let treffer = store.search("git")
        XCTAssertEqual(treffer.count, 3)
        XCTAssertEqual(LibraryStore.clamp(selection, count: treffer.count), 2)
    }
    // MARK: - Robustheit

    func testFehlenderSeedWirftFehler() {
        let store = LibraryStore(fileURL: tempDirectory.appendingPathComponent("library.json"), seedURL: nil)

        XCTAssertThrowsError(try store.load()) { error in
            XCTAssertEqual(error as? LibraryError, .seedUnavailable("seed.json liegt nicht im Bundle"))
        }
        XCTAssertFalse(FileManager.default.fileExists(atPath: store.fileURL.path))
        XCTAssertFalse(store.isLoaded)
    }

    func testUnlesbarerSeedWirftFehler() {
        let store = LibraryStore(fileURL: tempDirectory.appendingPathComponent("library.json"),
                                 seedURL: tempDirectory.appendingPathComponent("fehlt.json"))

        XCTAssertThrowsError(try store.load()) { error in
            guard case .seedUnavailable = (error as? LibraryError) else {
                return XCTFail("Erwartet: seedUnavailable, bekommen: \(error)")
            }
        }
        XCTAssertFalse(store.isLoaded)
    }

    func testMuellInDateiWirftUndLaesstDateiUnveraendert() throws {
        let store = makeStore()
        let muell = Data("{ kein gueltiges JSON".utf8)
        try FileManager.default.createDirectory(at: store.fileURL.deletingLastPathComponent(),
                                                withIntermediateDirectories: true)
        try muell.write(to: store.fileURL)

        XCTAssertThrowsError(try store.load())

        XCTAssertFalse(store.isLoaded)
        XCTAssertEqual(try Data(contentsOf: store.fileURL), muell)
    }

    func testSaveNachFehlgeschlagenemLadenWirdBlockiert() throws {
        let store = makeStore()
        let muell = Data("{ kein gueltiges JSON".utf8)
        try FileManager.default.createDirectory(at: store.fileURL.deletingLastPathComponent(),
                                                withIntermediateDirectories: true)
        try muell.write(to: store.fileURL)
        XCTAssertThrowsError(try store.load())

        store.items = sample
        XCTAssertThrowsError(try store.save()) { error in
            XCTAssertEqual(error as? LibraryError, .saveBlockedAfterFailedLoad)
        }
        XCTAssertEqual(try Data(contentsOf: store.fileURL), muell)
    }

    func testSaveOhneVorherigesLadenWirdBlockiert() {
        let store = makeStore()
        store.items = sample

        XCTAssertThrowsError(try store.save()) { error in
            XCTAssertEqual(error as? LibraryError, .saveBlockedAfterFailedLoad)
        }
        XCTAssertFalse(FileManager.default.fileExists(atPath: store.fileURL.path))
    }

    // MARK: - Reiter-Zaehler (M4)

    func testSeedZaehlerProReiter() throws {
        let store = makeStore()
        try store.load()
        XCTAssertEqual(LibraryStore.tabs.map { store.items(in: $0).count }, [10, 10, 5, 3])
        XCTAssertEqual(LibraryStore.tabs.reduce(0) { $0 + store.items(in: $1).count }, store.items.count)
    }

    func testUnbekannterReiterIstLeer() throws {
        let store = makeStore()
        try store.load()
        XCTAssertTrue(store.items(in: "Rust").isEmpty)
    }

}
