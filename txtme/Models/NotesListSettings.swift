import Foundation

extension Notification.Name {
    static let notesListStyleChanged = Notification.Name("com.txtme.notesListStyleChanged")
}

final class NotesListSettings {
    static let shared = NotesListSettings()

    private let styleKey = "com.txtme.useNvaltStyleList"

    var useNvaltStyle: Bool {
        didSet {
            UserDefaults.standard.set(useNvaltStyle, forKey: styleKey)
            UserDefaults.standard.synchronize()
            NotificationCenter.default.post(name: .notesListStyleChanged, object: nil)
        }
    }

    private init() {
        useNvaltStyle = UserDefaults.standard.bool(forKey: styleKey)
    }
}
