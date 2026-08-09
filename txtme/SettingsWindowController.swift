import Cocoa

final class SettingsWindowController: NSWindowController {
    static let shared = SettingsWindowController()

    private let boldCheckbox: NSButton = {
        let button = NSButton(checkboxWithTitle: "Bold default text", target: nil, action: nil)
        return button
    }()

    private let fontNameLabel: NSTextField = {
        let label = NSTextField(labelWithString: "")
        label.font = .systemFont(ofSize: 13)
        label.textColor = .secondaryLabelColor
        return label
    }()

    private let selectFontButton: NSButton = {
        let button = NSButton(title: "Select Font\u{2026}", target: nil, action: nil)
        button.bezelStyle = .rounded
        return button
    }()

    private let nvaltCheckbox: NSButton = {
        let button = NSButton(checkboxWithTitle: "nvALT style notes list", target: nil, action: nil)
        return button
    }()

    private convenience init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 460, height: 250),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Settings"
        window.center()
        window.isReleasedWhenClosed = false
        self.init(window: window)
        setUpContent()
    }

    private func setUpContent() {
        guard let window else { return }

        boldCheckbox.target = self
        boldCheckbox.action = #selector(boldToggled(_:))
        boldCheckbox.state = EditorSettings.shared.isBold ? .on : .off

        selectFontButton.target = self
        selectFontButton.action = #selector(selectFontTapped)

        updateFontLabel()

        nvaltCheckbox.target = self
        nvaltCheckbox.action = #selector(nvaltToggled(_:))
        nvaltCheckbox.state = NotesListSettings.shared.useNvaltStyle ? .on : .off

        let fontRow = NSStackView(views: [fontNameLabel, selectFontButton])
        fontRow.orientation = .horizontal
        fontRow.spacing = 8
        fontRow.alignment = .centerY

        let grid = NSGridView(views: [
            [makeSectionLabel("Editor"), boldCheckbox],
            [NSGridCell.emptyContentView, fontRow],
            [makeSectionLabel("Notes"), nvaltCheckbox],
        ])
        grid.rowSpacing = 16
        grid.columnSpacing = 12
        grid.column(at: 0).xPlacement = .trailing
        grid.column(at: 1).xPlacement = .leading
        grid.row(at: 0).topPadding = 28
        grid.row(at: 2).topPadding = 10
        grid.translatesAutoresizingMaskIntoConstraints = false

        let container = NSView()
        container.addSubview(grid)
        NSLayoutConstraint.activate([
            grid.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 24),
            grid.trailingAnchor.constraint(lessThanOrEqualTo: container.trailingAnchor, constant: -24),
            grid.topAnchor.constraint(equalTo: container.topAnchor),
        ])

        window.contentView = container
    }

    private func makeSectionLabel(_ text: String) -> NSTextField {
        let label = NSTextField(labelWithString: "\(text):")
        label.font = .systemFont(ofSize: 13)
        label.textColor = .labelColor
        return label
    }

    private func updateFontLabel() {
        let font = EditorSettings.shared.font
        fontNameLabel.stringValue = "\(font.displayName ?? font.fontName) \u{2013} \(Int(font.pointSize))pt"
    }

    @objc private func boldToggled(_ sender: NSButton) {
        EditorSettings.shared.isBold = sender.state == .on
    }

    @objc private func nvaltToggled(_ sender: NSButton) {
        NotesListSettings.shared.useNvaltStyle = sender.state == .on
    }

    @objc private func selectFontTapped() {
        let fontManager = NSFontManager.shared
        fontManager.target = self
        fontManager.action = #selector(changeFont(_:))
        fontManager.setSelectedFont(EditorSettings.shared.font, isMultiple: false)
        fontManager.orderFrontFontPanel(self)
    }

    @objc func changeFont(_ sender: Any?) {
        guard let fontManager = sender as? NSFontManager else { return }
        EditorSettings.shared.font = fontManager.convert(EditorSettings.shared.font)
        updateFontLabel()
    }

    @objc func openSettings(_ sender: Any?) {
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
