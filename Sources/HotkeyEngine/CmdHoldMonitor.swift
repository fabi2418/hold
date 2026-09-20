import AppKit
import os

private let log = Logger(subsystem: "com.fabi2418.hold", category: "hotkey")

private func tapCallback(
    proxy: CGEventTapProxy,
    type: CGEventType,
    event: CGEvent,
    refcon: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    if let refcon {
        Unmanaged<CmdHoldMonitor>.fromOpaque(refcon).takeUnretainedValue().handle(type, event)
    }
    return Unmanaged.passUnretained(event)
}

/// Globaler ⌘-Listener nach M1: ⌘ allein 0,6 s gehalten schaltet das Overlay um.
/// Loslassen von ⌘ aendert nichts. esc laeuft ueber das Panel (siehe OverlayPanel).
final class CmdHoldMonitor {
    var holdDuration: TimeInterval = 0.6
    var onOpen: () -> Void = {}
    var onClose: () -> Void = {}

    private static let modifiers: CGEventFlags = [
        .maskCommand, .maskShift, .maskControl, .maskAlternate, .maskSecondaryFn,
    ]
    private var tap: CFMachPort?
    private var holdTimer: Timer?
    private var armedAt: TimeInterval = 0
    private var isOpen = false
    private var tainted = false
    /// Verhindert, dass derselbe ⌘-Halte-Vorgang mehrfach umschaltet.
    private var firedThisPress = false

    var isRunning: Bool { tap != nil }

    @discardableResult
    func start() -> Bool {
        if tap != nil { return true }
        let types: [CGEventType] = [.flagsChanged, .keyDown, .leftMouseDown, .rightMouseDown, .otherMouseDown]
        let mask = types.reduce(CGEventMask(0)) { $0 | (CGEventMask(1) << CGEventMask($1.rawValue)) }
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: tapCallback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            log.debug("Tap-Erzeugung fehlgeschlagen (Berechtigung fehlt?)")
            return false
        }
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        self.tap = tap
        log.info("Tap installiert (main=\(Thread.isMainThread))")
        return true
    }

    /// Schaltet das Overlay um. Auch vom Menue-Eintrag genutzt, damit der
    /// Monitor und das Panel nie auseinanderlaufen.
    func toggle() {
        isOpen.toggle()
        log.info("Overlay umgeschaltet: isOpen=\(self.isOpen)")
        if isOpen { onOpen() } else { onClose() }
    }

    func close() {
        guard isOpen else { return }
        isOpen = false
        log.info("Overlay geschlossen")
        onClose()
    }

    fileprivate func handle(_ type: CGEventType, _ event: CGEvent) {
        switch type {
        case .tapDisabledByTimeout, .tapDisabledByUserInput:
            log.error("Tap deaktiviert: type=\(type.rawValue) isOpen=\(self.isOpen) – re-enable")
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
            reset()
            close()
        case .flagsChanged:
            let mods = event.flags.intersection(Self.modifiers)
            if !mods.contains(.maskCommand) {
                // Loslassen beendet nur den Halte-Vorgang, es schaltet nicht.
                cancelHold()
                firedThisPress = false
                tainted = !mods.isEmpty
            } else if mods == .maskCommand {
                if !tainted && !firedThisPress && holdTimer == nil { arm() }
            } else {
                tainted = true
                cancelHold()
            }
        default:
            tainted = true
            cancelHold()
        }
    }

    private func arm() {
        log.info("⌘ gedrückt (allein): Timer \(self.holdDuration)s")
        armedAt = ProcessInfo.processInfo.systemUptime
        let timer = Timer(timeInterval: holdDuration, repeats: false) { [weak self] _ in self?.fire() }
        RunLoop.main.add(timer, forMode: .common)
        holdTimer = timer
    }

    private func cancelHold() {
        holdTimer?.invalidate()
        holdTimer = nil
    }

    private func reset() {
        cancelHold()
        tainted = false
        firedThisPress = false
    }

    private func fire() {
        holdTimer = nil
        let held = ProcessInfo.processInfo.systemUptime - armedAt
        let sinceKey = CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: .keyDown)
        let flags = CGEventSource.flagsState(.combinedSessionState).intersection(Self.modifiers)
        log.info("Timer gefeuert: held=\(held) sinceKey=\(sinceKey) flags=\(flags.rawValue)")
        guard sinceKey >= held, flags == .maskCommand else {
            log.info("Timer verworfen (Taste seit ⌘-Druck oder ⌘ nicht allein)")
            tainted = true
            return
        }
        firedThisPress = true
        toggle()
    }
}
