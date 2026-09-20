import Foundation

/// Wohin der Tastaturfokus im Overlay zeigt. Liegt im Model, weil sowohl die
/// View (setzen) als auch das Panel (Tastenauswertung) ihn kennen muessen.
enum OverlayFocus: Hashable {
    case search
    case description(UUID)
    case command(UUID)

    /// True fuer die Felder einer Zeile. Waehrend die den Fokus haben, greifen
    /// ↑↓, ⌘1-4 und ←→ nicht (SCR-03).
    var isRowField: Bool {
        switch self {
        case .search: return false
        case .description, .command: return true
        }
    }
}

/// Was esc im aktuellen Zustand bedeutet (M6). Als eigener Typ, damit die
/// Entscheidung ohne laufendes Panel testbar ist.
enum EscapeAction: Equatable {
    case leaveField
    case clearSearch
    case closePanel
}
