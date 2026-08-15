import Cocoa

struct PaletteCommand {
    let title: String
    let shortcut: String?
    let action: () -> Void
}

/// Borderless NSPanel's default `canBecomeKey` is `false`; this override is what lets the
/// search field actually accept keyboard input despite having no titlebar.
private final class KeyablePanel: NSPanel {
    override var canBecomeKey: Bool { true }
}

final class CommandPaletteController: NSWindowController {
    static let shared = CommandPaletteController()

    private let searchField = NSSearchField()
    private let scrollView = NSScrollView()
    private let tableView = NSTableView()

    private var allCommands: [PaletteCommand] = []
    private var filteredCommands: [PaletteCommand] = []

    private convenience init() {
        let panel = KeyablePanel(
            contentRect: NSRect(x: 0, y: 0, width: 560, height: 360),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.isMovableByWindowBackground = true
        panel.level = .floating
        panel.isReleasedWhenClosed = false
        panel.hidesOnDeactivate = false
        self.init(window: panel)
        setUpContent()

        // Dismiss as soon as the palette loses key status, e.g. clicking the app behind it.
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(windowDidResignKey),
            name: NSWindow.didResignKeyNotification,
            object: panel
        )
    }

    @objc private func windowDidResignKey() {
        close()
    }

    private func setUpContent() {
        guard let window else { return }

        let blurView = NSVisualEffectView()
        blurView.material = .popover
        blurView.blendingMode = .behindWindow
        blurView.state = .active
        blurView.wantsLayer = true
        blurView.layer?.cornerRadius = 14
        blurView.layer?.masksToBounds = true
        blurView.translatesAutoresizingMaskIntoConstraints = false

        searchField.translatesAutoresizingMaskIntoConstraints = false
        searchField.placeholderString = "Type a command\u{2026}"
        searchField.font = .systemFont(ofSize: 18)
        searchField.isBordered = false
        searchField.focusRingType = .none
        searchField.drawsBackground = false
        searchField.delegate = self
        (searchField.cell as? NSSearchFieldCell)?.searchButtonCell = nil
        (searchField.cell as? NSSearchFieldCell)?.cancelButtonCell = nil

        let separator = NSBox()
        separator.boxType = .separator
        separator.translatesAutoresizingMaskIntoConstraints = false

        setUpTableView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false

        blurView.addSubview(searchField)
        blurView.addSubview(separator)
        blurView.addSubview(scrollView)

        NSLayoutConstraint.activate([
            searchField.topAnchor.constraint(equalTo: blurView.topAnchor, constant: 16),
            searchField.leadingAnchor.constraint(equalTo: blurView.leadingAnchor, constant: 20),
            searchField.trailingAnchor.constraint(equalTo: blurView.trailingAnchor, constant: -20),

            separator.topAnchor.constraint(equalTo: searchField.bottomAnchor, constant: 14),
            separator.leadingAnchor.constraint(equalTo: blurView.leadingAnchor),
            separator.trailingAnchor.constraint(equalTo: blurView.trailingAnchor),

            scrollView.topAnchor.constraint(equalTo: separator.bottomAnchor),
            scrollView.leadingAnchor.constraint(equalTo: blurView.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: blurView.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: blurView.bottomAnchor),
        ])

        window.contentView = blurView
    }

    private func setUpTableView() {
        let column = NSTableColumn(identifier: .init("CommandColumn"))
        column.title = ""
        tableView.addTableColumn(column)
        tableView.headerView = nil
        tableView.rowHeight = 34
        tableView.backgroundColor = .clear
        tableView.style = .plain
        tableView.intercellSpacing = NSSize(width: 0, height: 0)
        tableView.dataSource = self
        tableView.delegate = self
        tableView.target = self
        tableView.action = #selector(rowClicked)

        scrollView.documentView = tableView
        scrollView.hasVerticalScroller = true
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
    }

    func present(commands: [PaletteCommand]) {
        allCommands = commands
        filteredCommands = commands
        searchField.stringValue = ""
        tableView.reloadData()
        selectRow(0)

        guard let window else { return }
        if let mainWindow = NSApp.mainWindow ?? NSApp.windows.first(where: { $0.isVisible && $0 !== window }) {
            let mainFrame = mainWindow.frame
            let size = window.frame.size
            let origin = NSPoint(
                x: mainFrame.midX - size.width / 2,
                y: mainFrame.midY - size.height / 2
            )
            window.setFrameOrigin(origin)
        } else {
            window.center()
        }

        showWindow(nil)
        window.makeKeyAndOrderFront(nil)
        window.makeFirstResponder(searchField)
    }

    private func filterCommands() {
        let query = searchField.stringValue.trimmingCharacters(in: .whitespaces).lowercased()
        filteredCommands = query.isEmpty ? allCommands : allCommands.filter { $0.title.lowercased().contains(query) }
        tableView.reloadData()
        selectRow(filteredCommands.isEmpty ? nil : 0)
    }

    private func selectRow(_ row: Int?) {
        guard let row, row >= 0, row < filteredCommands.count else {
            tableView.deselectAll(nil)
            return
        }
        tableView.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
        tableView.scrollRowToVisible(row)
    }

    private func moveSelection(by delta: Int) {
        guard !filteredCommands.isEmpty else { return }
        let current = tableView.selectedRow
        let base = current < 0 ? (delta > 0 ? -1 : 0) : current
        let next = max(0, min(filteredCommands.count - 1, base + delta))
        selectRow(next)
    }

    @objc private func rowClicked() {
        executeSelectedCommand()
    }

    private func executeSelectedCommand() {
        let row = tableView.selectedRow
        guard filteredCommands.indices.contains(row) else { return }
        let command = filteredCommands[row]
        close()
        command.action()
    }
}

extension CommandPaletteController: NSSearchFieldDelegate {
    func controlTextDidChange(_ obj: Notification) {
        filterCommands()
    }

    func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        switch commandSelector {
        case #selector(NSResponder.moveUp(_:)):
            moveSelection(by: -1)
            return true
        case #selector(NSResponder.moveDown(_:)):
            moveSelection(by: 1)
            return true
        case #selector(NSResponder.insertNewline(_:)):
            executeSelectedCommand()
            return true
        case #selector(NSResponder.cancelOperation(_:)):
            close()
            return true
        default:
            return false
        }
    }
}

extension CommandPaletteController: NSTableViewDataSource, NSTableViewDelegate {
    func numberOfRows(in tableView: NSTableView) -> Int {
        filteredCommands.count
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let identifier = NSUserInterfaceItemIdentifier("CommandRow")
        let command = filteredCommands[row]

        let cell: NSTableCellView
        let titleLabel: NSTextField
        let shortcutLabel: NSTextField

        if let reused = tableView.makeView(withIdentifier: identifier, owner: self) as? NSTableCellView,
           let reusedTitle = reused.viewWithTag(1) as? NSTextField,
           let reusedShortcut = reused.viewWithTag(2) as? NSTextField {
            cell = reused
            titleLabel = reusedTitle
            shortcutLabel = reusedShortcut
        } else {
            cell = NSTableCellView()
            cell.identifier = identifier

            titleLabel = NSTextField(labelWithString: "")
            titleLabel.font = .systemFont(ofSize: 13)
            titleLabel.tag = 1
            titleLabel.translatesAutoresizingMaskIntoConstraints = false

            shortcutLabel = NSTextField(labelWithString: "")
            shortcutLabel.font = .systemFont(ofSize: 11.5)
            shortcutLabel.textColor = .tertiaryLabelColor
            shortcutLabel.alignment = .right
            shortcutLabel.tag = 2
            shortcutLabel.translatesAutoresizingMaskIntoConstraints = false

            cell.addSubview(titleLabel)
            cell.addSubview(shortcutLabel)

            NSLayoutConstraint.activate([
                titleLabel.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 20),
                titleLabel.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
                titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: shortcutLabel.leadingAnchor, constant: -12),

                shortcutLabel.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -20),
                shortcutLabel.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
            ])
        }

        titleLabel.stringValue = command.title
        shortcutLabel.stringValue = command.shortcut ?? ""
        return cell
    }
}
