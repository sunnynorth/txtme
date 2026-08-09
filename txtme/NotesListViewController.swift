import Cocoa

protocol NotesListViewControllerDelegate: AnyObject {
    func notesListDidSelectFile(_ item: TextFileItem)
}

/// An nvALT-style compact vertical list of notes, as an alternative to the card grid.
final class NotesListViewController: NSViewController {
    weak var delegate: NotesListViewControllerDelegate?

    private let headerLabel: NSTextField = {
        let label = NSTextField(labelWithString: "")
        label.font = .systemFont(ofSize: 20, weight: .bold)
        return label
    }()

    private let emptyLabel: NSTextField = {
        let label = NSTextField(labelWithString: "No text files in this folder yet")
        label.font = .systemFont(ofSize: 13)
        label.textColor = .secondaryLabelColor
        label.alignment = .center
        label.isHidden = true
        return label
    }()

    private let scrollView = NSScrollView()
    private let tableView = NSTableView()

    private(set) var folder: ImportedFolder?
    private var items: [TextFileItem] = []

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter
    }()

    override func loadView() {
        view = NSView()
        setUpLayout()
        setUpTableView()
    }

    private func setUpLayout() {
        headerLabel.translatesAutoresizingMaskIntoConstraints = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        emptyLabel.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(headerLabel)
        view.addSubview(scrollView)
        view.addSubview(emptyLabel)

        NSLayoutConstraint.activate([
            headerLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            headerLabel.topAnchor.constraint(equalTo: view.topAnchor, constant: 20),

            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: headerLabel.bottomAnchor, constant: 12),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            emptyLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            emptyLabel.centerYAnchor.constraint(equalTo: scrollView.centerYAnchor),
        ])
    }

    private func setUpTableView() {
        let column = NSTableColumn(identifier: .init("NoteColumn"))
        column.title = ""
        tableView.addTableColumn(column)
        tableView.headerView = nil
        tableView.rowHeight = 46
        tableView.backgroundColor = .clear
        tableView.style = .plain
        tableView.selectionHighlightStyle = .regular
        tableView.intercellSpacing = NSSize(width: 0, height: 0)
        tableView.gridStyleMask = []
        tableView.dataSource = self
        tableView.delegate = self
        tableView.menu = makeContextMenu()

        scrollView.documentView = tableView
        scrollView.hasVerticalScroller = true
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
    }

    private func makeContextMenu() -> NSMenu {
        let menu = NSMenu()

        let rename = NSMenuItem(title: "Rename", action: #selector(renameClicked), keyEquivalent: "")
        rename.target = self
        menu.addItem(rename)

        let reveal = NSMenuItem(title: "Reveal in Finder", action: #selector(revealClicked), keyEquivalent: "")
        reveal.target = self
        menu.addItem(reveal)

        menu.addItem(.separator())

        let delete = NSMenuItem(title: "Delete", action: #selector(deleteClicked), keyEquivalent: "")
        delete.target = self
        menu.addItem(delete)

        return menu
    }

    func show(folder: ImportedFolder) {
        self.folder = folder
        headerLabel.stringValue = folder.name
        reload()
    }

    func reload() {
        guard let folder, let url = FolderStore.shared.resolveURL(for: folder) else {
            items = []
            tableView.reloadData()
            emptyLabel.isHidden = true
            return
        }
        items = TextFileManager.listTextFiles(in: url)
        tableView.reloadData()
        emptyLabel.isHidden = !items.isEmpty
    }

    private func clickedItem() -> TextFileItem? {
        let row = tableView.clickedRow
        guard items.indices.contains(row) else { return nil }
        return items[row]
    }

    @objc private func renameClicked() {
        guard let item = clickedItem() else { return }
        promptRename(item)
    }

    @objc private func revealClicked() {
        guard let item = clickedItem() else { return }
        NSWorkspace.shared.activateFileViewerSelecting([item.url])
    }

    @objc private func deleteClicked() {
        guard let item = clickedItem() else { return }
        confirmDelete(item)
    }

    private func promptRename(_ item: TextFileItem) {
        guard let window = view.window else { return }
        let alert = NSAlert()
        alert.messageText = "Rename File"
        alert.addButton(withTitle: "Rename")
        alert.addButton(withTitle: "Cancel")

        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 240, height: 24))
        field.stringValue = item.name
        alert.accessoryView = field

        alert.beginSheetModal(for: window) { [weak self] response in
            guard response == .alertFirstButtonReturn, let self else { return }
            if TextFileManager.rename(item.url, to: field.stringValue) != nil {
                self.reload()
            }
        }
    }

    private func confirmDelete(_ item: TextFileItem) {
        guard let window = view.window else { return }
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "Delete \u{201C}\(item.name)\u{201D}?"
        alert.informativeText = "This will permanently delete the file. This cannot be undone."
        alert.addButton(withTitle: "Delete")
        alert.addButton(withTitle: "Cancel")

        alert.beginSheetModal(for: window) { [weak self] response in
            guard response == .alertFirstButtonReturn, let self else { return }
            TextFileManager.deleteFile(at: item.url)
            self.reload()
        }
    }
}

extension NotesListViewController: NSTableViewDataSource, NSTableViewDelegate {
    func numberOfRows(in tableView: NSTableView) -> Int {
        items.count
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let identifier = NSUserInterfaceItemIdentifier("NoteRow")
        let item = items[row]

        let cell: NSTableCellView
        let titleLabel: NSTextField
        let dateLabel: NSTextField
        let previewLabel: NSTextField

        if let reused = tableView.makeView(withIdentifier: identifier, owner: self) as? NSTableCellView,
           let reusedTitle = reused.viewWithTag(1) as? NSTextField,
           let reusedDate = reused.viewWithTag(2) as? NSTextField,
           let reusedPreview = reused.viewWithTag(3) as? NSTextField {
            cell = reused
            titleLabel = reusedTitle
            dateLabel = reusedDate
            previewLabel = reusedPreview
        } else {
            cell = NSTableCellView()
            cell.identifier = identifier

            titleLabel = NSTextField(labelWithString: "")
            titleLabel.font = .systemFont(ofSize: 13, weight: .semibold)
            titleLabel.lineBreakMode = .byTruncatingTail
            titleLabel.tag = 1
            titleLabel.translatesAutoresizingMaskIntoConstraints = false

            dateLabel = NSTextField(labelWithString: "")
            dateLabel.font = .systemFont(ofSize: 11)
            dateLabel.textColor = .tertiaryLabelColor
            dateLabel.alignment = .right
            dateLabel.tag = 2
            dateLabel.translatesAutoresizingMaskIntoConstraints = false

            previewLabel = NSTextField(labelWithString: "")
            previewLabel.font = .systemFont(ofSize: 11.5)
            previewLabel.textColor = .secondaryLabelColor
            previewLabel.lineBreakMode = .byTruncatingTail
            previewLabel.tag = 3
            previewLabel.translatesAutoresizingMaskIntoConstraints = false

            let separator = NSBox()
            separator.boxType = .separator
            separator.translatesAutoresizingMaskIntoConstraints = false

            cell.addSubview(titleLabel)
            cell.addSubview(dateLabel)
            cell.addSubview(previewLabel)
            cell.addSubview(separator)

            NSLayoutConstraint.activate([
                titleLabel.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 24),
                titleLabel.topAnchor.constraint(equalTo: cell.topAnchor, constant: 7),
                titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: dateLabel.leadingAnchor, constant: -8),

                dateLabel.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -24),
                dateLabel.firstBaselineAnchor.constraint(equalTo: titleLabel.firstBaselineAnchor),
                dateLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 60),

                previewLabel.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 24),
                previewLabel.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -24),
                previewLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 2),

                separator.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 24),
                separator.trailingAnchor.constraint(equalTo: cell.trailingAnchor),
                separator.bottomAnchor.constraint(equalTo: cell.bottomAnchor),
            ])
        }

        titleLabel.stringValue = item.name
        dateLabel.stringValue = Self.dateFormatter.string(from: item.modifiedDate)
        let trimmedPreview = item.preview
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\n", with: " ")
        previewLabel.stringValue = trimmedPreview.isEmpty ? "Empty" : trimmedPreview

        return cell
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        let row = tableView.selectedRow
        guard items.indices.contains(row) else { return }
        let item = items[row]
        tableView.deselectRow(row)
        delegate?.notesListDidSelectFile(item)
    }
}
