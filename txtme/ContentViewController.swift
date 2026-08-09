import Cocoa

final class ContentViewController: NSViewController {
    private let emptyStateLabel: NSTextField = {
        let label = NSTextField(labelWithString: "Select a folder to see its text files")
        label.font = .systemFont(ofSize: 14)
        label.textColor = .secondaryLabelColor
        label.alignment = .center
        return label
    }()

    private let gridVC = CardGridViewController()
    private let listVC = NotesListViewController()
    private let editorVC = EditorViewController()

    private var currentFolder: ImportedFolder?

    override func loadView() {
        view = NSView()

        emptyStateLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(emptyStateLabel)
        NSLayoutConstraint.activate([
            emptyStateLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            emptyStateLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor),
        ])

        gridVC.delegate = self
        listVC.delegate = self
        editorVC.delegate = self

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(notesListStyleChanged),
            name: .notesListStyleChanged,
            object: nil
        )
    }

    func showEmpty() {
        editorVC.flushPendingSave()
        currentFolder = nil
        removeAllChildren()
        emptyStateLabel.isHidden = false
    }

    func showGrid(for folder: ImportedFolder) {
        editorVC.flushPendingSave()
        currentFolder = folder
        emptyStateLabel.isHidden = true
        embedActiveList()
    }

    func openFile(at url: URL) {
        guard let folder = currentFolder else { return }
        emptyStateLabel.isHidden = true
        embed(editorVC)
        editorVC.open(url: url, folderName: folder.name)
    }

    func flushPendingSave() {
        editorVC.flushPendingSave()
    }

    private func embedActiveList() {
        guard let folder = currentFolder else { return }
        if NotesListSettings.shared.useNvaltStyle {
            embed(listVC)
            listVC.show(folder: folder)
        } else {
            embed(gridVC)
            gridVC.show(folder: folder)
        }
    }

    @objc private func notesListStyleChanged() {
        guard currentFolder != nil, !children.contains(where: { $0 === editorVC }) else { return }
        embedActiveList()
    }

    private func embed(_ child: NSViewController) {
        guard children.last !== child else { return }
        removeAllChildren()
        addChild(child)
        child.view.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(child.view)
        NSLayoutConstraint.activate([
            child.view.topAnchor.constraint(equalTo: view.topAnchor),
            child.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            child.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            child.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }

    private func removeAllChildren() {
        for child in children {
            child.view.removeFromSuperview()
            child.removeFromParent()
        }
    }
}

extension ContentViewController: CardGridViewControllerDelegate {
    func cardGridDidSelectFile(_ item: TextFileItem) {
        openFile(at: item.url)
    }
}

extension ContentViewController: NotesListViewControllerDelegate {
    func notesListDidSelectFile(_ item: TextFileItem) {
        openFile(at: item.url)
    }
}

extension ContentViewController: EditorViewControllerDelegate {
    func editorDidRequestBack() {
        embedActiveList()
    }
}
