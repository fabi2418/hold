import AppKit
import os

private let log = Logger(subsystem: "com.fabi2418.cheatsheet", category: "hotkey")

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

    fileprivate func handle(_ type: CGEventType, _ event: CGEvent) {
        switch type {
        case .tapDisabledByTimeout, .tapDisabledByUserInput:
            log.error("Tap deaktiviert: type=\(type.rawValue) isOpen=\(self.isOpen) – re-enable")
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
            cancelHold()
            if isOpen { isOpen = false; onClose() }
        case .flagsChanged:
            let mods = event.flags.intersection(Self.modifiers)
            if !mods.contains(.maskCommand) {
                log.info("⌘ losgelassen: mods=\(mods.rawValue) isOpen=\(self.isOpen) main=\(Thread.isMainThread)")
                cancelHold()
                if isOpen { isOpen = false; onClose() }
                tainted = !mods.isEmpty
            } else if mods == .maskCommand {
                if !tainted && !isOpen && holdTimer == nil { arm() }
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
        isOpen = true
        onOpen()
    }
}
