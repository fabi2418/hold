import AppKit
import SwiftUI
import os

private let log = Logger(subsystem: "com.fabi2418.cheatsheet", category: "panel")

final class OverlayPanel: NSPanel {
    /// Wird von esc gerufen; der AppDelegate leitet auf CmdHoldMonitor.close(),
    /// damit Panel und Monitor denselben Zustand sehen.
    var onRequestClose: () -> Void = {}

    private let model: OverlayViewModel
    private var keyMonitor: Any?
    private var previousApp: NSRunningApplication?
    /// True, solange show()/hide() laufen. Verhindert, dass der Fokuswechsel
    /// waehrend des Oeffnens oder Schliessens selbst als Fokusverlust zaehlt.
    private var isChangingVisibility = false

    private enum Key {
        static let escape: UInt16 = 53
        static let left: UInt16 = 123
        static let right: UInt16 = 124
        static let down: UInt16 = 125
        static let up: UInt16 = 126
        static let c: UInt16 = 8
    }

    init(model: OverlayViewModel) {
        self.model = model
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: Theme.panelWidth, height: 640),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        level = .floating
        isFloatingPanel = true
        hidesOnDeactivate = false
        hasShadow = true
        isOpaque = false
        backgroundColor = .clear
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        let hosting = NSHostingView(rootView: OverlayView(model: model))
        hosting.autoresizingMask = [.width, .height]
        contentView = hosting

        // Hoehe aus dem Layout ableiten: Breite und Inhaltshoehe sind fest,
        // alles andere ergibt sich aus den Abstaenden im View.
        let fitting = hosting.fittingSize
        if fitting.height > 0 {
            setContentSize(NSSize(width: Theme.panelWidth, height: fitting.height))
        }
    }

    /// Borderless-Fenster koennen das per Default nicht; ohne das bekaeme das
    /// Suchfeld keinen Tastaturfokus.
    override var canBecomeKey: Bool { true }

    func show() {
        isChangingVisibility = true
        defer { isChangingVisibility = false }
        previousApp = NSWorkspace.shared.frontmostApplication
        model.prepareForOpen()
        center()
        NSApp.activate(ignoringOtherApps: true)
        makeKeyAndOrderFront(nil)
        startKeyMonitor()
        log.info("Panel geöffnet, Fokus übernommen")
    }

    func hide() {
        isChangingVisibility = true
        defer { isChangingVisibility = false }
        // M10: Aenderungen sind spaetestens beim Schliessen auf der Platte.
        model.save()
        stopKeyMonitor()
        orderOut(nil)
        previousApp?.activate()
        previousApp = nil
        log.info("Panel geschlossen, Fokus zurückgegeben")
    }

    /// Klick nach draussen: das Panel verliert den Key-Status und schliesst.
    /// Die Pruefung laeuft asynchron, weil waehrend des Aktivierens kurzzeitig
    /// ein resignKey durchlaufen kann, dem sofort ein becomeKey folgt.
    override func resignKey() {
        super.resignKey()
        guard !isChangingVisibility else { return }
        DispatchQueue.main.async { [weak self] in
            guard let self, self.isVisible, !self.isKeyWindow, !self.isChangingVisibility else { return }
            log.info("Fokus verloren, Panel wird geschlossen")
            self.onRequestClose()
        }
    }

    // MARK: - Tastatur

    /// Lokaler Monitor statt keyDown-Override: so werden ↑↓←→ und ⌘1-4
    /// abgefangen, bevor das fokussierte Suchfeld sie als Textnavigation
    /// verbraucht; alles andere laeuft unveraendert weiter ins Feld.
    private func startKeyMonitor() {
        guard keyMonitor == nil else { return }
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return event }
            return self.handle(event) ? nil : event
        }
    }

    private func stopKeyMonitor() {
        if let keyMonitor { NSEvent.removeMonitor(keyMonitor) }
        keyMonitor = nil
    }

    /// ⌘C mit Markierung in einem Textfeld gehoert dem Feld, nicht der Auswahl.
    private var searchFieldHasSelection: Bool {
        guard let editor = firstResponder as? NSTextView else { return false }
        return editor.selectedRange().length > 0
    }

    private func handle(_ event: NSEvent) -> Bool {
        let hasCommand = event.modifierFlags.contains(.command)
        let hasControl = event.modifierFlags.contains(.control)

        if isCopyKey(event) {
            if hasCommand && searchFieldHasSelection { return false }
            guard hasCommand || hasControl else { return false }
            model.copySelection()
            return true
        }

        if hasCommand, let digit = event.charactersIgnoringModifiers.flatMap(Int.init),
           (1 ... LibraryStore.tabs.count).contains(digit) {
            guard !model.isSearching, !model.isEditingRow else { return false }
            model.selectTab(number: digit)
            return true
        }

        switch event.keyCode {
        case Key.escape:
            let action = model.escapeAction()
            log.info("esc: editingRow=\(self.model.isEditingRow) searching=\(self.model.isSearching) → \(String(describing: action), privacy: .public)")
            switch action {
            case .leaveField: model.leaveField()
            case .clearSearch: model.clearSearch()
            case .closePanel: onRequestClose()
            }
            return true
        case Key.up:
            guard !model.isEditingRow else { return false }
            model.moveSelection(by: -1)
            return true
        case Key.down:
            guard !model.isEditingRow else { return false }
            model.moveSelection(by: 1)
            return true
        case Key.left, Key.right:
            guard !model.isSearching, !model.isEditingRow else { return false }
            model.cycleTab(by: event.keyCode == Key.left ? -1 : 1)
            return true
        default:
            return false
        }
    }

    private func isCopyKey(_ event: NSEvent) -> Bool {
        if event.charactersIgnoringModifiers?.lowercased() == "c" { return true }
        return event.keyCode == Key.c
    }
}
