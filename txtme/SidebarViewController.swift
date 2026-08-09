import Cocoa

protocol SidebarViewControllerDelegate: AnyObject {
    func sidebarDidSelectFolder(_ folder: ImportedFolder)
    func sidebarDidRequestImportFolder()
    func sidebarDidRequestRemoveFolder(_ folder: ImportedFolder)
    func sidebarDidRequestNewFile()
}

final class SidebarViewController: NSViewController {
    weak var delegate: SidebarViewControllerDelegate?

    private let headerLabel: NSTextField = {
        let label = NSTextField(labelWithString: "FOLDERS")
        label.font = .systemFont(ofSize: 11, weight: .semibold)
        label.textColor = .secondaryLabelColor
        return label
    }()

    private let importButton: NSButton = {
        let button = NSButton(image: NSImage(systemSymbolName: "plus", accessibilityDescription: "Import Folder")!, target: nil, action: nil)
        button.isBordered = false
        button.bezelStyle = .regularSquare
        button.imagePosition = .imageOnly
        button.contentTintColor = .secondaryLabelColor
        button.toolTip = "Import Folder"
        return button
    }()

    private let scrollView = NSScrollView()
    private let tableView = NSTableView()

    private let newFileButton: NSButton = {
        let button = NSButton(title: "  New Text File", image: NSImage(systemSymbolName: "square.and.pencil", accessibilityDescription: nil)!, target: nil, action: nil)
        button.imagePosition = .imageLeading
        button.isBordered = false
        button.bezelStyle = .regularSquare
        button.font = .systemFont(ofSize: 12, weight: .regular)
        button.contentTintColor = .secondaryLabelColor
        button.alignment = .left
        return button
    }()

    private var folders: [ImportedFolder] = []

    override func loadView() {
        view = NSView()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setUpLayout()
        setUpTableView()

        importButton.target = self
        importButton.action = #selector(importTapped)

        newFileButton.target = self
        newFileButton.action = #selector(newFileTapped)
    }

    private func setUpLayout() {
        headerLabel.translatesAutoresizingMaskIntoConstraints = false
        importButton.translatesAutoresizingMaskIntoConstraints = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        newFileButton.translatesAutoresizingMaskIntoConstraints = false

        let separator = NSBox()
        separator.boxType = .separator
        separator.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(headerLabel)
        view.addSubview(importButton)
        view.addSubview(scrollView)
        view.addSubview(separator)
        view.addSubview(newFileButton)

        NSLayoutConstraint.activate([
            headerLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            headerLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),

            importButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -12),
            importButton.centerYAnchor.constraint(equalTo: headerLabel.centerYAnchor),
            importButton.widthAnchor.constraint(equalToConstant: 20),
            importButton.heightAnchor.constraint(equalToConstant: 20),

            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: headerLabel.bottomAnchor, constant: 8),
            scrollView.bottomAnchor.constraint(equalTo: separator.topAnchor, constant: -8),

            separator.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            separator.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            separator.bottomAnchor.constraint(equalTo: newFileButton.topAnchor, constant: -8),

            newFileButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 12),
            newFileButton.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -12),
            newFileButton.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -12),
            newFileButton.heightAnchor.constraint(equalToConstant: 24),
        ])
    }

    private func setUpTableView() {
        scrollView.documentView = tableView
        scrollView.hasVerticalScroller = true
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder

        let column = NSTableColumn(identifier: .init("FolderColumn"))
        column.title = ""
        tableView.addTableColumn(column)
        tableView.headerView = nil
        tableView.rowHeight = 28
        tableView.backgroundColor = .clear
        tableView.style = .sourceList
        tableView.selectionHighlightStyle = .sourceList
        tableView.dataSource = self
        tableView.delegate = self
        tableView.menu = makeContextMenu()
    }

    private func makeContextMenu() -> NSMenu {
        let menu = NSMenu()
        let remove = NSMenuItem(title: "Remove Folder", action: #selector(removeSelectedFolder), keyEquivalent: "")
        remove.target = self
        menu.addItem(remove)
        return menu
    }

    func reload() {
        folders = FolderStore.shared.folders
        tableView.reloadData()
    }

    func select(_ folder: ImportedFolder) {
        guard let index = folders.firstIndex(where: { $0.id == folder.id }) else { return }
        tableView.selectRowIndexes(IndexSet(integer: index), byExtendingSelection: false)
    }

    @objc private func importTapped() {
        delegate?.sidebarDidRequestImportFolder()
    }

    @objc private func newFileTapped() {
        delegate?.sidebarDidRequestNewFile()
    }

    @objc private func removeSelectedFolder() {
        let row = tableView.clickedRow
        guard folders.indices.contains(row) else { return }
        delegate?.sidebarDidRequestRemoveFolder(folders[row])
    }
}

extension SidebarViewController: NSTableViewDataSource, NSTableViewDelegate {
    func numberOfRows(in tableView: NSTableView) -> Int {
        folders.count
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let identifier = NSUserInterfaceItemIdentifier("FolderCell")
        let cell: NSTableCellView
        if let reused = tableView.makeView(withIdentifier: identifier, owner: self) as? NSTableCellView {
            cell = reused
        } else {
            cell = NSTableCellView()
            cell.identifier = identifier

            let imageView = NSImageView()
            imageView.image = NSImage(systemSymbolName: "folder", accessibilityDescription: nil)
            imageView.contentTintColor = .secondaryLabelColor
            imageView.translatesAutoresizingMaskIntoConstraints = false

            let textField = NSTextField(labelWithString: "")
            textField.font = .systemFont(ofSize: 13)
            textField.lineBreakMode = .byTruncatingTail
            textField.translatesAutoresizingMaskIntoConstraints = false

            cell.addSubview(imageView)
            cell.addSubview(textField)
            cell.imageView = imageView
            cell.textField = textField

            NSLayoutConstraint.activate([
                imageView.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 4),
                imageView.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
                imageView.widthAnchor.constraint(equalToConstant: 16),
                imageView.heightAnchor.constraint(equalToConstant: 16),

                textField.leadingAnchor.constraint(equalTo: imageView.trailingAnchor, constant: 8),
                textField.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -4),
                textField.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
            ])
        }

        cell.textField?.stringValue = folders[row].name
        return cell
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        let row = tableView.selectedRow
        guard folders.indices.contains(row) else { return }
        delegate?.sidebarDidSelectFolder(folders[row])
    }
}
