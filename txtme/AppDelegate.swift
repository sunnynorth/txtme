import Cocoa

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var mainWindowController: MainWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let windowController = MainWindowController()
        NSApp.mainMenu = buildMainMenu(windowController: windowController)
        windowController.showWindow(nil)
        windowController.window?.makeKeyAndOrderFront(nil)
        mainWindowController = windowController
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    func applicationWillTerminate(_ notification: Notification) {
        mainWindowController?.flushPendingSave()
    }

    /// Reached via the responder chain (NSApp -> its delegate) whenever the Font Panel's
    /// selection changes, regardless of which window is currently key.
    @objc func changeFont(_ sender: Any?) {
        guard let fontManager = sender as? NSFontManager else { return }
        EditorSettings.shared.font = fontManager.convert(EditorSettings.shared.font)
    }

    @objc func showCommandPalette(_ sender: Any?) {
        guard let windowController = mainWindowController else { return }
        CommandPaletteController.shared.present(commands: buildPaletteCommands(windowController: windowController))
    }

    @objc func toggleFocusModeAction(_ sender: Any?) {
        FocusModeState.shared.toggle()
    }

    private func buildPaletteCommands(windowController: MainWindowController) -> [PaletteCommand] {
        [
            PaletteCommand(title: "New Text File", shortcut: "\u{2318}N") {
                windowController.newTextFileMenuAction(nil)
            },
            PaletteCommand(title: "Import Folder\u{2026}", shortcut: "\u{21e7}\u{2318}O") {
                windowController.importFolderMenuAction(nil)
            },
            PaletteCommand(title: "Toggle Bold Default Text", shortcut: nil) {
                EditorSettings.shared.isBold.toggle()
            },
            PaletteCommand(title: "Select Font\u{2026}", shortcut: nil) {
                NSFontManager.shared.setSelectedFont(EditorSettings.shared.font, isMultiple: false)
                NSFontManager.shared.orderFrontFontPanel(nil)
            },
            PaletteCommand(title: "Toggle nvALT Style Notes List", shortcut: nil) {
                NotesListSettings.shared.useNvaltStyle.toggle()
            },
            PaletteCommand(title: "Settings\u{2026}", shortcut: "\u{2318},") {
                SettingsWindowController.shared.openSettings(nil)
            },
            PaletteCommand(title: "Toggle Focus Mode", shortcut: "\u{21e7}\u{2318}F") {
                FocusModeState.shared.toggle()
            },
        ]
    }

    private func buildMainMenu(windowController: MainWindowController) -> NSMenu {
        let appName = ProcessInfo.processInfo.processName
        let mainMenu = NSMenu()

        let appMenuItem = NSMenuItem()
        mainMenu.addItem(appMenuItem)
        let appMenu = NSMenu()
        appMenuItem.submenu = appMenu
        appMenu.addItem(withTitle: "About \(appName)", action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: "")
        appMenu.addItem(.separator())
        let settingsItem = NSMenuItem(title: "Settings\u{2026}", action: #selector(SettingsWindowController.openSettings(_:)), keyEquivalent: ",")
        settingsItem.target = SettingsWindowController.shared
        appMenu.addItem(settingsItem)
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Hide \(appName)", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        let hideOthers = NSMenuItem(title: "Hide Others", action: #selector(NSApplication.hideOtherApplications(_:)), keyEquivalent: "h")
        hideOthers.keyEquivalentModifierMask = [.command, .option]
        appMenu.addItem(hideOthers)
        appMenu.addItem(withTitle: "Show All", action: #selector(NSApplication.unhideAllApplications(_:)), keyEquivalent: "")
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Quit \(appName)", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")

        let fileMenuItem = NSMenuItem()
        mainMenu.addItem(fileMenuItem)
        let fileMenu = NSMenu(title: "File")
        fileMenuItem.submenu = fileMenu

        let newFileItem = NSMenuItem(title: "New Text File", action: #selector(MainWindowController.newTextFileMenuAction(_:)), keyEquivalent: "n")
        newFileItem.target = windowController
        fileMenu.addItem(newFileItem)

        let importItem = NSMenuItem(title: "Import Folder\u{2026}", action: #selector(MainWindowController.importFolderMenuAction(_:)), keyEquivalent: "o")
        importItem.keyEquivalentModifierMask = [.command, .shift]
        importItem.target = windowController
        fileMenu.addItem(importItem)

        fileMenu.addItem(.separator())
        fileMenu.addItem(withTitle: "Close Window", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")

        let editMenuItem = NSMenuItem()
        mainMenu.addItem(editMenuItem)
        let editMenu = NSMenu(title: "Edit")
        editMenuItem.submenu = editMenu

        editMenu.addItem(withTitle: "Undo", action: Selector(("undo:")), keyEquivalent: "z")
        let redoItem = NSMenuItem(title: "Redo", action: Selector(("redo:")), keyEquivalent: "z")
        redoItem.keyEquivalentModifierMask = [.command, .shift]
        editMenu.addItem(redoItem)
        editMenu.addItem(.separator())
        editMenu.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        editMenu.addItem(.separator())

        let spellingItem = NSMenuItem(title: "Spelling and Grammar", action: nil, keyEquivalent: "")
        let spellingMenu = NSMenu(title: "Spelling and Grammar")
        spellingMenu.addItem(withTitle: "Show Spelling and Grammar", action: #selector(NSText.showGuessPanel(_:)), keyEquivalent: ":")
        spellingMenu.addItem(withTitle: "Check Document Now", action: #selector(NSText.checkSpelling(_:)), keyEquivalent: ";")
        spellingMenu.addItem(.separator())
        spellingMenu.addItem(withTitle: "Check Spelling While Typing", action: #selector(NSTextView.toggleContinuousSpellChecking(_:)), keyEquivalent: "")
        spellingItem.submenu = spellingMenu
        editMenu.addItem(spellingItem)

        let viewMenuItem = NSMenuItem()
        mainMenu.addItem(viewMenuItem)
        let viewMenu = NSMenu(title: "View")
        viewMenuItem.submenu = viewMenu

        let paletteItem = NSMenuItem(title: "Command Palette\u{2026}", action: #selector(AppDelegate.showCommandPalette(_:)), keyEquivalent: "k")
        paletteItem.target = self
        viewMenu.addItem(paletteItem)

        let focusItem = NSMenuItem(title: "Toggle Focus Mode", action: #selector(AppDelegate.toggleFocusModeAction(_:)), keyEquivalent: "f")
        focusItem.keyEquivalentModifierMask = [.command, .shift]
        focusItem.target = self
        viewMenu.addItem(focusItem)

        let windowMenuItem = NSMenuItem()
        mainMenu.addItem(windowMenuItem)
        let windowMenu = NSMenu(title: "Window")
        windowMenuItem.submenu = windowMenu
        windowMenu.addItem(withTitle: "Minimize", action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m")
        windowMenu.addItem(withTitle: "Zoom", action: #selector(NSWindow.performZoom(_:)), keyEquivalent: "")
        NSApp.windowsMenu = windowMenu

        return mainMenu
    }
}
