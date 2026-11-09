import Foundation
import Combine

/// A key the user holds to dictate. Either a modifier (Right Option, Fn, …) or a regular key (F13, `, …).
struct Hotkey: Codable, Hashable {
    var keyCode: UInt16
    var isModifier: Bool

    var name: String { KeyNames.name(for: keyCode) }

    static let rightOption = Hotkey(keyCode: 61, isModifier: true)

    static let presets: [Hotkey] = [
        Hotkey(keyCode: 61, isModifier: true),  // Right Option
        Hotkey(keyCode: 54, isModifier: true),  // Right Command
        Hotkey(keyCode: 62, isModifier: true),  // Right Control
        Hotkey(keyCode: 60, isModifier: true),  // Right Shift
        Hotkey(keyCode: 63, isModifier: true),  // Fn
        Hotkey(keyCode: 58, isModifier: true),  // Left Option
        Hotkey(keyCode: 59, isModifier: true),  // Left Control
    ]
}

enum KeyNames {
    /// Device-dependent flag bit for each modifier key (lets us tell left from right).
    static func modifierMask(for keyCode: UInt16) -> UInt64? {
        switch keyCode {
        case 59: return 0x0000_0001 // left control
        case 62: return 0x0000_2000 // right control
        case 56: return 0x0000_0002 // left shift
        case 60: return 0x0000_0004 // right shift
        case 55: return 0x0000_0008 // left command
        case 54: return 0x0000_0010 // right command
        case 58: return 0x0000_0020 // left option
        case 61: return 0x0000_0040 // right option
        case 63: return 0x0080_0000 // fn
        default: return nil
        }
    }

    static func name(for keyCode: UInt16) -> String {
        if let n = names[keyCode] { return n }
        return "Клавиша #\(keyCode)"
    }

    private static let names: [UInt16: String] = [
        54: "Правый ⌘ Command", 55: "Левый ⌘ Command",
        56: "Левый ⇧ Shift", 60: "Правый ⇧ Shift",
        58: "Левый ⌥ Option", 61: "Правый ⌥ Option",
        59: "Левый ⌃ Control", 62: "Правый ⌃ Control",
        63: "Fn / 🌐",
        122: "F1", 120: "F2", 99: "F3", 118: "F4", 96: "F5", 97: "F6",
        98: "F7", 100: "F8", 101: "F9", 109: "F10", 103: "F11", 111: "F12",
        105: "F13", 107: "F14", 113: "F15", 106: "F16", 64: "F17", 79: "F18", 80: "F19", 90: "F20",
        49: "Пробел", 53: "Esc", 36: "Return", 48: "Tab", 51: "Delete", 117: "⌦ Forward Delete",
        123: "←", 124: "→", 125: "↓", 126: "↑",
        115: "Home", 119: "End", 116: "Page Up", 121: "Page Down",
        50: "` (Ё)", 10: "§",
        0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G", 6: "Z", 7: "X", 8: "C", 9: "V",
        11: "B", 12: "Q", 13: "W", 14: "E", 15: "R", 16: "Y", 17: "T",
        18: "1", 19: "2", 20: "3", 21: "4", 22: "6", 23: "5", 24: "=", 25: "9", 26: "7",
        27: "-", 28: "8", 29: "0", 30: "]", 31: "O", 32: "U", 33: "[", 34: "I", 35: "P",
        37: "L", 38: "J", 39: "'", 40: "K", 41: ";", 42: "\\", 43: ",", 44: "/", 45: "N",
        46: "M", 47: ".",
    ]
}

final class AppSettings: ObservableObject {
    static let shared = AppSettings()
    private let d = UserDefaults.standard

    @Published var hotkey: Hotkey {
        didSet { if let data = try? JSONEncoder().encode(hotkey) { d.set(data, forKey: "hotkey") } }
    }
    @Published var localeID: String { didSet { d.set(localeID, forKey: "localeID") } }
    @Published var onDevice: Bool { didSet { d.set(onDevice, forKey: "onDevice") } }
    @Published var addTrailingSpace: Bool { didSet { d.set(addTrailingSpace, forKey: "addTrailingSpace") } }
    @Published var playSounds: Bool { didSet { d.set(playSounds, forKey: "playSounds") } }
    @Published var showOverlay: Bool { didSet { d.set(showOverlay, forKey: "showOverlay") } }

    private init() {
        d.register(defaults: [
            "localeID": "ru-RU",
            "onDevice": true,
            "addTrailingSpace": true,
            "playSounds": true,
            "showOverlay": true,
        ])
        if let data = d.data(forKey: "hotkey"), let hk = try? JSONDecoder().decode(Hotkey.self, from: data) {
            hotkey = hk
        } else {
            hotkey = .rightOption
        }
        localeID = d.string(forKey: "localeID") ?? "ru-RU"
        onDevice = d.bool(forKey: "onDevice")
        addTrailingSpace = d.bool(forKey: "addTrailingSpace")
        playSounds = d.bool(forKey: "playSounds")
        showOverlay = d.bool(forKey: "showOverlay")
    }
}
