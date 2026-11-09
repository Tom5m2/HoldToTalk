import AppKit
import CoreGraphics

/// Puts text into whatever app has focus: via the clipboard + ⌘V, then restores the clipboard.
enum TextInserter {
    static let eventMarker: Int64 = 0x4854_5421 // "HTT!"

    static func insert(_ text: String) {
        let pb = NSPasteboard.general
        let saved = snapshot(pb)

        pb.clearContents()
        pb.setString(text, forType: .string)
        // Ask clipboard managers not to record this.
        pb.setData(Data(), forType: NSPasteboard.PasteboardType("org.nspasteboard.TransientType"))
        let ourChange = pb.changeCount

        pressCommandV()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            // Don't clobber the clipboard if something else was copied meanwhile.
            guard pb.changeCount == ourChange else { return }
            restore(saved, to: pb)
        }
    }

    private static func pressCommandV() {
        let src = CGEventSource(stateID: .privateState)
        let vKey: CGKeyCode = 9
        for keyDown in [true, false] {
            guard let ev = CGEvent(keyboardEventSource: src, virtualKey: vKey, keyDown: keyDown) else { continue }
            ev.flags = .maskCommand
            ev.setIntegerValueField(.eventSourceUserData, value: eventMarker)
            ev.post(tap: .cghidEventTap)
        }
    }

    private static func snapshot(_ pb: NSPasteboard) -> [[NSPasteboard.PasteboardType: Data]] {
        (pb.pasteboardItems ?? []).map { item in
            var dict: [NSPasteboard.PasteboardType: Data] = [:]
            for type in item.types {
                if let data = item.data(forType: type) { dict[type] = data }
            }
            return dict
        }
    }

    private static func restore(_ items: [[NSPasteboard.PasteboardType: Data]], to pb: NSPasteboard) {
        pb.clearContents()
        guard !items.isEmpty else { return }
        let newItems: [NSPasteboardItem] = items.map { dict in
            let item = NSPasteboardItem()
            for (type, data) in dict { item.setData(data, forType: type) }
            return item
        }
        pb.writeObjects(newItems)
    }
}
