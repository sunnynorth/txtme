import Cocoa

extension Notification.Name {
    static let editorSettingsChanged = Notification.Name("com.txtme.editorSettingsChanged")
}

final class EditorSettings {
    static let shared = EditorSettings()

    private let boldKey = "com.txtme.editorBoldText"
    private let fontNameKey = "com.txtme.editorFontName"
    private let fontSizeKey = "com.txtme.editorFontSize"

    var isBold: Bool {
        didSet {
            UserDefaults.standard.set(isBold, forKey: boldKey)
            UserDefaults.standard.synchronize()
            NotificationCenter.default.post(name: .editorSettingsChanged, object: nil)
        }
    }

    var font: NSFont {
        didSet {
            UserDefaults.standard.set(font.fontName, forKey: fontNameKey)
            UserDefaults.standard.set(Double(font.pointSize), forKey: fontSizeKey)
            UserDefaults.standard.synchronize()
            NotificationCenter.default.post(name: .editorSettingsChanged, object: nil)
        }
    }

    /// The font actually applied to the editor, with the bold trait folded in if enabled.
    var effectiveFont: NSFont {
        guard isBold else { return font }
        return NSFontManager.shared.convert(font, toHaveTrait: .boldFontMask)
    }

    private init() {
        isBold = UserDefaults.standard.bool(forKey: boldKey)
        if let name = UserDefaults.standard.string(forKey: fontNameKey) {
            let size = UserDefaults.standard.double(forKey: fontSizeKey)
            font = NSFont(name: name, size: size > 0 ? CGFloat(size) : 14) ?? .systemFont(ofSize: 14)
        } else {
            font = .systemFont(ofSize: 14)
        }
    }
}
