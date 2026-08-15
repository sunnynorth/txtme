import Foundation

extension Notification.Name {
    static let focusModeChanged = Notification.Name("com.txtme.focusModeChanged")
}

final class FocusModeState {
    static let shared = FocusModeState()

    private(set) var isEnabled = false

    private init() {}

    func toggle() {
        isEnabled.toggle()
        NotificationCenter.default.post(name: .focusModeChanged, object: nil)
    }
}
