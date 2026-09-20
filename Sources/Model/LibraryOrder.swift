import Foundation

/// Zielposition beim Verschieben einer Zeile (P8).
enum DropPosition: Equatable {
    /// Vor die Zeile mit dieser id; die Gruppe wird von ihr uebernommen.
    case before(UUID)
    /// Ans Ende dieser Gruppe. Deckt auch die noch leere Gruppe ab.
    case endOfGroup(String)
}

/// Reine Sortierlogik auf dem items-Array. Die Reihenfolge des Arrays IST die
/// Ordnung: kein Ordnungsfeld, keine Formataenderung. Die Gruppenreihenfolge
/// ergibt sich weiterhin aus dem ersten Auftreten.
enum LibraryOrder {
    /// Fuehrt eine Umsortierung aus, die nur Eintraege eines Reiters betrifft.
    /// Die Plaetze des Reiters im Gesamtarray bleiben erhalten, Eintraege
    /// anderer Reiter werden dadurch nie verschoben.
    static func reorder(_ items: [LibraryItem],
                        in tab: String,
                        transform: ([LibraryItem]) -> [LibraryItem]) -> [LibraryItem] {
        let slots = items.indices.filter { items[$0].cat == tab }
        let changed = transform(slots.map { items[$0] })
        guard changed.count == slots.count else { return items }
        var result = items
        for (slot, item) in zip(slots, changed) { result[slot] = item }
        return result
    }

    /// Verschiebt eine Zeile innerhalb ihres Reiters, auch ueber Gruppengrenzen.
    static func moveItem(_ items: [LibraryItem],
                         id: UUID,
                         to position: DropPosition,
                         in tab: String) -> [LibraryItem] {
        reorder(items, in: tab) { sub in
            guard let from = sub.firstIndex(where: { $0.id == id }) else { return sub }
            var list = sub
            var moved = list.remove(at: from)

            switch position {
            case .before(let targetID):
                guard targetID != id,
                      let to = list.firstIndex(where: { $0.id == targetID }) else { return sub }
                moved.group = list[to].group
                list.insert(moved, at: to)
            case .endOfGroup(let group):
                moved.group = group
                if let last = list.lastIndex(where: { $0.group == group }) {
                    list.insert(moved, at: last + 1)
                } else {
                    list.append(moved)
                }
            }
            return list
        }
    }

    /// Verschiebt den gesamten Block einer Gruppe vor eine andere Gruppe,
    /// `before == nil` heisst ans Ende. Die Reihenfolge innerhalb des Blocks
    /// bleibt erhalten.
    static func moveGroup(_ items: [LibraryItem],
                          group: String,
                          before target: String?,
                          in tab: String) -> [LibraryItem] {
        guard group != target else { return items }
        return reorder(items, in: tab) { sub in
            guard sub.contains(where: { $0.group == group }) else { return sub }
            let block = sub.filter { $0.group == group }
            var rest = sub.filter { $0.group != group }
            if let target, let at = rest.firstIndex(where: { $0.group == target }) {
                rest.insert(contentsOf: block, at: at)
            } else {
                rest.append(contentsOf: block)
            }
            return rest
        }
    }

    /// Verschiebt einen Reiter vor einen anderen, `before == nil` ans Ende.
    static func moveTab(_ tabs: [String], _ tab: String, before target: String?) -> [String] {
        guard tab != target, let from = tabs.firstIndex(of: tab) else { return tabs }
        var list = tabs
        let moved = list.remove(at: from)
        if let target, let at = list.firstIndex(of: target) {
            list.insert(moved, at: at)
        } else {
            list.append(moved)
        }
        return list
    }

    /// Gruppennamen eines Reiters in der Reihenfolge ihres ersten Auftretens.
    static func groupOrder(_ items: [LibraryItem], in tab: String) -> [String] {
        var seen: Set<String> = []
        var order: [String] = []
        for item in items where item.cat == tab {
            if seen.insert(item.group).inserted { order.append(item.group) }
        }
        return order
    }

    /// ⌘-Kuerzel folgen der Reiterreihenfolge; ab dem 10. Reiter keines mehr.
    static func shortcut(forTabAt index: Int) -> Int? {
        (0 ..< 9).contains(index) ? index + 1 : nil
    }
}

/// Was gerade gezogen wird bzw. worauf gezogen wird (P8).
enum DragItem: Equatable {
    case row(UUID)
    case group(String)
    case tab(String)

    var id: String {
        switch self {
        case .row(let id): return "row:\(id.uuidString)"
        case .group(let name): return "group:\(name)"
        case .tab(let name): return "tab:\(name)"
        }
    }
}

/// Merkposten fuer ⌘Z: der Zustand unmittelbar vor dem letzten Loeschen (P9).
struct UndoState: Equatable {
    let snapshot: LibraryStore.Snapshot
    let activeTab: String
    let selection: Int
}
