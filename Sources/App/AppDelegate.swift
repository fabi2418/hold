import AppKit
import ApplicationServices
import os

private let log = Logger(subsystem: "com.fabi2418.cheatsheet", category: "app")

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let statusLine = NSMenuItem(title: "", action: #selector(requestAccessibility), keyEquivalent: "")
    private let monitor = CmdHoldMonitor()
    private let library = LibraryStore()
    private lazy var model = OverlayViewModel(store: library)
    private lazy var panel = OverlayPanel(model: model)

    func applicationDidFinishLaunching(_ notification: Notification) {
        log.info("App gestartet (main=\(Thread.isMainThread))")
        loadLibrary()
        panel.onRequestClose = { [monitor] in monitor.close() }
        monitor.onOpen = { [panel] in
            log.info("Panel eingeblendet (main=\(Thread.isMainThread))")
            panel.show()
        }
        monitor.onClose = { [panel] in
            log.info("Panel ausgeblendet (main=\(Thread.isMainThread))")
            panel.hide()
        }

        let button = statusItem.button
        button?.image = NSImage(systemSymbolName: "command", accessibilityDescription: "Cheatsheet")
        if button?.image == nil { button?.title = "⌘" }
        log.info("StatusItem erzeugt: isVisible=\(self.statusItem.isVisible) button!=nil=\(button != nil) image!=nil=\(button?.image != nil)")

        let menu = NSMenu()
        menu.delegate = self
        let test = NSMenuItem(title: "Overlay öffnen (Test)", action: #selector(toggleOverlay), keyEquivalent: "")
        menu.addItem(test)
        menu.addItem(statusLine)
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Beenden", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        for item in menu.items where item.action != #selector(NSApplication.terminate(_:)) { item.target = self }
        statusItem.menu = menu

        let trusted = AXIsProcessTrustedWithOptions(["AXTrustedCheckOptionPrompt": true] as CFDictionary)
        log.info("Accessibility beim Start: trusted=\(trusted)")
        Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [monitor] timer in
            if monitor.start() { timer.invalidate() }
        }
    }

    private func loadLibrary() {
        do {
            let seeded = try library.load()
            log.info("Library geladen: \(self.library.items.count) Einträge, seeded=\(seeded), Pfad=\(self.library.fileURL.path, privacy: .public)")
        } catch {
            log.error("Library konnte nicht geladen werden: \(error.localizedDescription, privacy: .public)")
        }
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        let trusted = AXIsProcessTrusted()
        let tapState = monitor.isRunning ? "Tap aktiv" : "Tap inaktiv"
        statusLine.title = "Bedienungshilfen: \(trusted ? "erteilt" : "fehlt") · \(tapState)"
        log.info("Menü geöffnet: trusted=\(trusted) tapRunning=\(self.monitor.isRunning)")
    }

    @objc private func toggleOverlay() {
        log.info("Overlay über Menü umgeschaltet")
        monitor.toggle()
    }

    @objc private func requestAccessibility() {
        _ = AXIsProcessTrustedWithOptions(["AXTrustedCheckOptionPrompt": true] as CFDictionary)
    }
}
