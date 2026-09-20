import Foundation

/// Wohin der Tastaturfokus im Overlay zeigt. Liegt im Model, weil sowohl die
/// View (setzen) als auch das Panel (Tastenauswertung) ihn kennen muessen.
enum OverlayFocus: Hashable {
    case search
    case description(UUID)
    case command(UUID)
    /// Das Eingabefeld einer laufenden Umbenennung (K3).
    case rename

    /// True fuer alles ausser dem Suchfeld. Waehrend diese Felder den Fokus
    /// haben, greifen ↑↓, ⌘1-4 und ←→ nicht (SCR-03).
    var isRowField: Bool {
        switch self {
        case .search: return false
        case .description, .command, .rename: return true
        }
    }
}

/// Was gerade umbenannt wird (K3). Gruppen immer im aktiven Reiter.
enum RenameTarget: Hashable {
    case tab(String)
    case group(String)
}

/// Was esc im aktuellen Zustand bedeutet (M6). Als eigener Typ, damit die
/// Entscheidung ohne laufendes Panel testbar ist.
enum EscapeAction: Equatable {
    case cancelRename
    case leaveField
    case clearSearch
    case closePanel
}
