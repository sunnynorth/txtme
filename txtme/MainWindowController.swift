import Cocoa

final class MainWindowController: NSWindowController {
    private let splitViewController = NSSplitViewController()
    private let sidebarVC = SidebarViewController()
    private let contentVC = ContentViewController()

    private var selectedFolder: ImportedFolder?

    convenience init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1000, height: 640),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "txtme"
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.minSize = NSSize(width: 640, height: 400)
        window.center()
        window.setFrameAutosaveName("MainWindow")
        self.init(window: window)
        setUpContent()
    }

    /// Builds the split view and wires delegates. Not using `windowDidLoad()` here since
    /// this window is constructed in code (not loaded from a nib), so that lifecycle
    /// method is never invoked automatically.
    private func setUpContent() {
        sidebarVC.delegate = self
        window?.delegate = self

        let sidebarItem = NSSplitViewItem(sidebarWithViewController: sidebarVC)
        sidebarItem.minimumThickness = 200
        sidebarItem.maximumThickness = 320
        sidebarItem.canCollapse = true

        let contentItem = NSSplitViewItem(viewController: contentVC)

        splitViewController.addSplitViewItem(sidebarItem)
        splitViewController.addSplitViewItem(contentItem)
        splitViewController.splitView.dividerStyle = .thin

        window?.contentViewController = splitViewController

        sidebarVC.reload()
    }

    func flushPendingSave() {
        contentVC.flushPendingSave()
    }

    @objc func newTextFileMenuAction(_ sender: Any?) {
        sidebarDidRequestNewFile()
    }

    @objc func importFolderMenuAction(_ sender: Any?) {
        sidebarDidRequestImportFolder()
    }

    private func createFile(in folder: ImportedFolder) {
        guard let folderURL = FolderStore.shared.resolveURL(for: folder) else { return }
        let newURL = TextFileManager.uniqueFileURL(in: folderURL)
        guard TextFileManager.createFile(at: newURL) else { return }
        contentVC.showGrid(for: folder)
        contentVC.openFile(at: newURL)
    }

    private func presentFolderChoice(_ folders: [ImportedFolder], completion: @escaping (ImportedFolder?) -> Void) {
        guard let window else {
            completion(nil)
            return
        }

        let alert = NSAlert()
        alert.messageText = "Choose a Folder"
        alert.informativeText = "Which folder should the new text file be created in?"
        alert.addButton(withTitle: "Create")
        alert.addButton(withTitle: "Cancel")

        let popup = NSPopUpButton(frame: NSRect(x: 0, y: 0, width: 240, height: 24))
        popup.addItems(withTitles: folders.map { $0.name })
        alert.accessoryView = popup

        alert.beginSheetModal(for: window) { response in
            guard response == .alertFirstButtonReturn else {
                completion(nil)
                return
            }
            completion(folders[popup.indexOfSelectedItem])
        }
    }

    private func presentAlert(message: String, info: String) {
        guard let window else { return }
        let alert = NSAlert()
        alert.messageText = message
        alert.informativeText = info
        alert.beginSheetModal(for: window)
    }
}

extension MainWindowController: SidebarViewControllerDelegate {
    func sidebarDidSelectFolder(_ folder: ImportedFolder) {
        selectedFolder = folder
        contentVC.showGrid(for: folder)
    }

    func sidebarDidRequestImportFolder() {
        guard let window else { return }
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.prompt = "Import"
        panel.message = "Choose a folder of .txt files to import"

        panel.beginSheetModal(for: window) { [weak self] response in
            guard let self, response == .OK, let url = panel.url else { return }
            if let folder = FolderStore.shared.addFolder(url: url) {
                self.sidebarVC.reload()
                self.sidebarVC.select(folder)
                self.sidebarDidSelectFolder(folder)
            }
        }
    }

    func sidebarDidRequestRemoveFolder(_ folder: ImportedFolder) {
        FolderStore.shared.removeFolder(folder)
        if selectedFolder?.id == folder.id {
            selectedFolder = nil
            contentVC.showEmpty()
        }
        sidebarVC.reload()
    }

    func sidebarDidRequestNewFile() {
        if let folder = selectedFolder {
            createFile(in: folder)
            return
        }

        let folders = FolderStore.shared.folders
        guard !folders.isEmpty else {
            presentAlert(
                message: "No Folders Imported",
                info: "Import a folder first, then you can create a text file inside it."
            )
            return
        }

        presentFolderChoice(folders) { [weak self] folder in
            guard let self, let folder else { return }
            self.selectedFolder = folder
            self.sidebarVC.select(folder)
            self.createFile(in: folder)
        }
    }
}

extension MainWindowController: NSWindowDelegate {
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        contentVC.flushPendingSave()
        return true
    }
}
