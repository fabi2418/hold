import XCTest

final class LibraryImportTests: XCTestCase {
    private let bestand = [
        LibraryItem(cat: "Git", group: "Status", label: "git status -sb", desc: "Kurzstatus"),
        LibraryItem(cat: "zsh", group: "Allgemein", label: "ls -la", desc: "Dateien"),
    ]
    private let tabs = ["Git", "Claude", "Python", "zsh"]

    private func json(_ raw: String) throws -> [ImportedItem] {
        try LibraryImport.decode(raw)
    }

    // MARK: - Dekodieren

    func testGueltigesArrayWirdGelesen() throws {
        let entries = try json("""
        [{"cat":"Git","group":"Reparatur","label":"git reflog","desc":"Verlorene Commits"}]
        """)
        XCTAssertEqual(entries, [ImportedItem(cat: "Git", group: "Reparatur",
                                              label: "git reflog", desc: "Verlorene Commits")])
    }

    func testLeeresArrayIstGueltig() throws {
        XCTAssertTrue(try json("[]").isEmpty)
    }

    func testKaputtesJsonWirft() {
        for muell in ["kein json", "{", "[{\"cat\":\"Git\"}]", "{\"cat\":\"Git\"}", ""] {
            XCTAssertThrowsError(try json(muell)) { error in
                XCTAssertEqual(error as? LibraryImport.Failure, .invalidJSON)
            }
        }
    }

    func testFehlermeldungIstDerFooterText() {
        XCTAssertEqual(LibraryImport.Failure.invalidJSON.errorDescription, "Import fehlgeschlagen")
    }

    // MARK: - Merge

    func testNeueEintraegeLandenAmArrayEnde() throws {
        let incoming = try json("""
        [{"cat":"Git","group":"Reparatur","label":"git reflog","desc":"Verlorene Commits"}]
        """)
        let merged = LibraryImport.merge(incoming, into: bestand, tabs: tabs)

        XCTAssertEqual(merged.items.count, 3)
        XCTAssertEqual(merged.items.last?.label, "git reflog")
        XCTAssertEqual(merged.items.prefix(2).map(\.label), bestand.map(\.label),
                       "Bestand bleibt in Reihenfolge und Inhalt unberührt")
        XCTAssertEqual(merged.result, LibraryImport.Result(imported: 1, skipped: 0))
        XCTAssertEqual(merged.result.message, "1 importiert, 0 übersprungen")
    }

    func testDuplikatWirdUebersprungen() throws {
        let incoming = try json("""
        [{"cat":"Git","group":"Andere Gruppe","label":"git status -sb","desc":"Anderer Text"}]
        """)
        let merged = LibraryImport.merge(incoming, into: bestand, tabs: tabs)

        XCTAssertEqual(merged.items, bestand, "Library unverändert")
        XCTAssertEqual(merged.result, LibraryImport.Result(imported: 0, skipped: 1))
    }

    func testGleicherLabelInAnderemReiterIstKeinDuplikat() throws {
        let incoming = try json("""
        [{"cat":"zsh","group":"Allgemein","label":"git status -sb","desc":"anderer Reiter"}]
        """)
        let merged = LibraryImport.merge(incoming, into: bestand, tabs: tabs)
        XCTAssertEqual(merged.result, LibraryImport.Result(imported: 1, skipped: 0))
    }

    func testDuplikatInnerhalbDesImportsZaehltAlsUebersprungen() throws {
        let incoming = try json("""
        [{"cat":"Go","group":"Basis","label":"go build","desc":"Bauen"},
         {"cat":"Go","group":"Andere","label":"go build","desc":"Nochmal"}]
        """)
        let merged = LibraryImport.merge(incoming, into: bestand, tabs: tabs)
        XCTAssertEqual(merged.result, LibraryImport.Result(imported: 1, skipped: 1))
        XCTAssertEqual(merged.items.filter { $0.label == "go build" }.count, 1)
    }

    func testUnbekannterReiterWirdHintenErgaenzt() throws {
        let incoming = try json("""
        [{"cat":"Docker","group":"Container","label":"docker ps","desc":"Laufende Container"}]
        """)
        let merged = LibraryImport.merge(incoming, into: bestand, tabs: tabs)

        XCTAssertEqual(merged.tabs, ["Git", "Claude", "Python", "zsh", "Docker"])
        XCTAssertEqual(merged.items.last?.cat, "Docker")
    }

    func testBekannterReiterWirdNichtVerdoppelt() throws {
        let incoming = try json("""
        [{"cat":"Git","group":"Reparatur","label":"git reflog","desc":"x"}]
        """)
        XCTAssertEqual(LibraryImport.merge(incoming, into: bestand, tabs: tabs).tabs, tabs)
    }

    func testZweiNeueReiterInEingabereihenfolge() throws {
        let incoming = try json("""
        [{"cat":"Rust","group":"Basis","label":"cargo build","desc":"Bauen"},
         {"cat":"Go","group":"Basis","label":"go test ./...","desc":"Testen"}]
        """)
        let merged = LibraryImport.merge(incoming, into: bestand, tabs: tabs)
        XCTAssertEqual(merged.tabs, ["Git", "Claude", "Python", "zsh", "Rust", "Go"])
    }

    func testLeererImportAendertNichts() throws {
        let merged = LibraryImport.merge(try json("[]"), into: bestand, tabs: tabs)
        XCTAssertEqual(merged.items, bestand)
        XCTAssertEqual(merged.tabs, tabs)
        XCTAssertEqual(merged.result, LibraryImport.Result(imported: 0, skipped: 0))
    }

    func testImportInLeereLibrary() throws {
        let incoming = try json("""
        [{"cat":"Git","group":"Status","label":"git status","desc":"Status"}]
        """)
        let merged = LibraryImport.merge(incoming, into: [], tabs: [])
        XCTAssertEqual(merged.tabs, ["Git"])
        XCTAssertEqual(merged.items.count, 1)
    }

    func testReihenfolgeIstStabilUndIdempotent() throws {
        let raw = """
        [{"cat":"Git","group":"A","label":"eins","desc":"1"},
         {"cat":"Git","group":"A","label":"zwei","desc":"2"},
         {"cat":"Git","group":"B","label":"drei","desc":"3"}]
        """
        let erster = LibraryImport.merge(try json(raw), into: bestand, tabs: tabs)
        XCTAssertEqual(erster.items.suffix(3).map(\.label), ["eins", "zwei", "drei"])

        let zweiter = LibraryImport.merge(try json(raw), into: erster.items, tabs: erster.tabs)
        XCTAssertEqual(zweiter.result, LibraryImport.Result(imported: 0, skipped: 3),
                       "zweiter Lauf importiert nichts")
        XCTAssertEqual(zweiter.items.map(\.label), erster.items.map(\.label),
                       "Reihenfolge unverändert")
    }

    func testNeueEintraegeBekommenEigeneIds() throws {
        let incoming = try json("""
        [{"cat":"Git","group":"A","label":"eins","desc":"1"},
         {"cat":"Git","group":"A","label":"zwei","desc":"2"}]
        """)
        let merged = LibraryImport.merge(incoming, into: [], tabs: [])
        XCTAssertEqual(Set(merged.items.map(\.id)).count, 2)
    }
}
