import Cocoa

protocol CardGridViewControllerDelegate: AnyObject {
    func cardGridDidSelectFile(_ item: TextFileItem)
}

final class CardGridViewController: NSViewController {
    weak var delegate: CardGridViewControllerDelegate?

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
    private let collectionView = NSCollectionView()
    private let flowLayout = NSCollectionViewFlowLayout()

    private(set) var folder: ImportedFolder?
    private var items: [TextFileItem] = []

    override func loadView() {
        view = NSView()
        setUpLayout()
        setUpCollectionView()
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
            scrollView.topAnchor.constraint(equalTo: headerLabel.bottomAnchor, constant: 16),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            emptyLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            emptyLabel.centerYAnchor.constraint(equalTo: scrollView.centerYAnchor),
        ])
    }

    private func setUpCollectionView() {
        flowLayout.itemSize = NSSize(width: 170, height: 220)
        flowLayout.minimumInteritemSpacing = 16
        flowLayout.minimumLineSpacing = 16
        flowLayout.sectionInset = NSEdgeInsets(top: 8, left: 24, bottom: 24, right: 24)

        collectionView.collectionViewLayout = flowLayout
        collectionView.isSelectable = true
        collectionView.allowsMultipleSelection = false
        collectionView.backgroundColors = [.clear]
        collectionView.register(FileCardItem.self, forItemWithIdentifier: FileCardItem.identifier)
        collectionView.dataSource = self
        collectionView.delegate = self

        scrollView.documentView = collectionView
        scrollView.hasVerticalScroller = true
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
    }

    func show(folder: ImportedFolder) {
        self.folder = folder
        headerLabel.stringValue = folder.name
        reload()
    }

    func reload() {
        guard let folder, let url = FolderStore.shared.resolveURL(for: folder) else {
            items = []
            collectionView.reloadData()
            emptyLabel.isHidden = true
            return
        }
        items = TextFileManager.listTextFiles(in: url)
        collectionView.reloadData()
        emptyLabel.isHidden = !items.isEmpty
    }

    private func promptRename(_ item: TextFileItem) {
        guard let window = view.window, let folder, let folderURL = FolderStore.shared.resolveURL(for: folder) else { return }
        let alert = NSAlert()
        alert.messageText = "Rename File"
        alert.addButton(withTitle: "Rename")
        alert.addButton(withTitle: "Cancel")

        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 240, height: 24))
        field.stringValue = item.name
        alert.accessoryView = field

        alert.beginSheetModal(for: window) { [weak self] response in
            guard response == .alertFirstButtonReturn, let self else { return }
            if TextFileManager.rename(item.url, to: field.stringValue, in: folderURL) != nil {
                self.reload()
            }
        }
    }

    private func confirmDelete(_ item: TextFileItem) {
        guard let window = view.window, let folder, let folderURL = FolderStore.shared.resolveURL(for: folder) else { return }
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "Delete \u{201C}\(item.name)\u{201D}?"
        alert.informativeText = "This will permanently delete the file. This cannot be undone."
        alert.addButton(withTitle: "Delete")
        alert.addButton(withTitle: "Cancel")

        alert.beginSheetModal(for: window) { [weak self] response in
            guard response == .alertFirstButtonReturn, let self else { return }
            TextFileManager.deleteFile(at: item.url, in: folderURL)
            self.reload()
        }
    }
}

extension CardGridViewController: NSCollectionViewDataSource {
    func collectionView(_ collectionView: NSCollectionView, numberOfItemsInSection section: Int) -> Int {
        items.count
    }

    func collectionView(_ collectionView: NSCollectionView, itemForRepresentedObjectAt indexPath: IndexPath) -> NSCollectionViewItem {
        let cardItem = collectionView.makeItem(withIdentifier: FileCardItem.identifier, for: indexPath) as! FileCardItem
        cardItem.configure(with: items[indexPath.item])
        cardItem.delegate = self
        return cardItem
    }
}

extension CardGridViewController: NSCollectionViewDelegate {
    func collectionView(_ collectionView: NSCollectionView, didSelectItemsAt indexPaths: Set<IndexPath>) {
        guard let indexPath = indexPaths.first else { return }
        let item = items[indexPath.item]
        collectionView.deselectItems(at: indexPaths)
        delegate?.cardGridDidSelectFile(item)
    }
}

extension CardGridViewController: FileCardItemDelegate {
    func fileCardDidRequestRename(_ item: TextFileItem) {
        promptRename(item)
    }

    func fileCardDidRequestDelete(_ item: TextFileItem) {
        confirmDelete(item)
    }

    func fileCardDidRequestReveal(_ item: TextFileItem) {
        NSWorkspace.shared.activateFileViewerSelecting([item.url])
    }
}
