import AppKit
import CoreGraphics

/// Watches the keyboard globally (CGEventTap; needs Accessibility permission)
/// and reports when the push-to-talk key goes down and up.
final class HotkeyMonitor {
    var hotkey: Hotkey { didSet { isDown = false; interrupted = false } }

    var onPress: (() -> Void)?
    var onRelease: (() -> Void)?
    /// Another key was pressed while a modifier hotkey was held (e.g. ⌥+E) — not a dictation.
    var onInterrupt: (() -> Void)?
    /// When set, the next key pressed is captured as the new hotkey instead of being handled.
    var captureHandler: ((Hotkey?) -> Void)?

    private var tap: CFMachPort?
    private var source: CFRunLoopSource?
    private var isDown = false
    private var interrupted = false

    init(hotkey: Hotkey) { self.hotkey = hotkey }

    var isRunning: Bool { tap != nil }

    @discardableResult
    func start() -> Bool {
        if tap != nil { return true }
        let types: [CGEventType] = [.keyDown, .keyUp, .flagsChanged]
        let mask = types.reduce(CGEventMask(0)) { $0 | (CGEventMask(1) << $1.rawValue) }
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: hotkeyTapCallback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else { return false }
        self.tap = tap
        source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        return true
    }

    fileprivate func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        let pass = Unmanaged.passUnretained(event)

        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
            return pass
        }
        // Ignore our own synthetic ⌘V.
        if event.getIntegerValueField(.eventSourceUserData) == TextInserter.eventMarker { return pass }

        let keyCode = UInt16(event.getIntegerValueField(.keyboardEventKeycode))
        let flags = event.flags.rawValue

        // Capturing a new hotkey from the settings window.
        if let capture = captureHandler {
            switch type {
            case .keyDown:
                captureHandler = nil
                capture(keyCode == 53 ? nil : Hotkey(keyCode: keyCode, isModifier: false)) // Esc cancels
                return nil
            case .keyUp:
                return nil
            case .flagsChanged:
                if let m = KeyNames.modifierMask(for: keyCode), flags & m != 0 {
                    captureHandler = nil
                    capture(Hotkey(keyCode: keyCode, isModifier: true))
                }
                return pass
            default:
                return pass
            }
        }

        if hotkey.isModifier {
            if type == .flagsChanged, keyCode == hotkey.keyCode, let m = KeyNames.modifierMask(for: keyCode) {
                let down = flags & m != 0
                if down && !isDown {
                    isDown = true
                    interrupted = false
                    onPress?()
                } else if !down && isDown {
                    isDown = false
                    if !interrupted { onRelease?() }
                }
            } else if type == .keyDown && isDown && !interrupted {
                // The modifier is being used in a shortcut — cancel dictation, let the key through.
                interrupted = true
                onInterrupt?()
            }
            return pass
        } else {
            guard keyCode == hotkey.keyCode, type == .keyDown || type == .keyUp else { return pass }
            if type == .keyDown {
                if !isDown { isDown = true; onPress?() } // autorepeat is ignored
            } else if isDown {
                isDown = false
                onRelease?()
            }
            return nil // swallow the key so it doesn't type anything
        }
    }
}

private func hotkeyTapCallback(
    proxy: CGEventTapProxy, type: CGEventType, event: CGEvent, userInfo: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    guard let userInfo else { return Unmanaged.passUnretained(event) }
    let monitor = Unmanaged<HotkeyMonitor>.fromOpaque(userInfo).takeUnretainedValue()
    return monitor.handle(type: type, event: event)
}
