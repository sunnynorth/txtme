import Cocoa

protocol EditorViewControllerDelegate: AnyObject {
    func editorDidRequestBack()
}

final class EditorViewController: NSViewController {
    weak var delegate: EditorViewControllerDelegate?

    private let header = NSView()
    private let separator: NSBox = {
        let box = NSBox()
        box.boxType = .separator
        return box
    }()

    private let backButton: NSButton = {
        let button = NSButton(image: NSImage(systemSymbolName: "chevron.left", accessibilityDescription: "Back")!, target: nil, action: nil)
        button.isBordered = false
        button.bezelStyle = .regularSquare
        button.contentTintColor = .secondaryLabelColor
        return button
    }()

    private let folderLabel: NSTextField = {
        let label = NSTextField(labelWithString: "")
        label.font = .systemFont(ofSize: 12)
        label.textColor = .secondaryLabelColor
        label.lineBreakMode = .byTruncatingTail
        return label
    }()

    private let titleLabel: NSTextField = {
        let label = NSTextField(labelWithString: "")
        label.font = .systemFont(ofSize: 13, weight: .semibold)
        label.alignment = .center
        label.lineBreakMode = .byTruncatingMiddle
        return label
    }()

    private let scrollView = NSScrollView()
    private let textView = NSTextView()

    private var fileURL: URL?
    private var folder: ImportedFolder?
    private var saveTimer: Timer?

    private var resolvedFolderURL: URL? {
        folder.flatMap { FolderStore.shared.resolveURL(for: $0) }
    }

    private static let statusFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter
    }()

    override func loadView() {
        view = NSView()
        setUpHeader()
        setUpTextView()
    }

    private func setUpHeader() {
        header.translatesAutoresizingMaskIntoConstraints = false
        separator.translatesAutoresizingMaskIntoConstraints = false
        backButton.translatesAutoresizingMaskIntoConstraints = false
        folderLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        backButton.target = self
        backButton.action = #selector(backTapped)

        header.addSubview(backButton)
        header.addSubview(folderLabel)
        header.addSubview(titleLabel)

        view.addSubview(header)
        view.addSubview(separator)

        NSLayoutConstraint.activate([
            header.topAnchor.constraint(equalTo: view.topAnchor),
            header.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            header.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            header.heightAnchor.constraint(equalToConstant: 44),

            backButton.leadingAnchor.constraint(equalTo: header.leadingAnchor, constant: 16),
            backButton.centerYAnchor.constraint(equalTo: header.centerYAnchor),
            backButton.widthAnchor.constraint(equalToConstant: 14),
            backButton.heightAnchor.constraint(equalToConstant: 16),

            folderLabel.leadingAnchor.constraint(equalTo: backButton.trailingAnchor, constant: 6),
            folderLabel.centerYAnchor.constraint(equalTo: header.centerYAnchor),
            folderLabel.trailingAnchor.constraint(lessThanOrEqualTo: titleLabel.leadingAnchor, constant: -12),

            titleLabel.centerXAnchor.constraint(equalTo: header.centerXAnchor),
            titleLabel.centerYAnchor.constraint(equalTo: header.centerYAnchor),
            titleLabel.leadingAnchor.constraint(greaterThanOrEqualTo: header.leadingAnchor, constant: 140),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: header.trailingAnchor, constant: -140),

            separator.topAnchor.constraint(equalTo: header.bottomAnchor),
            separator.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            separator.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])
    }

    private func setUpTextView() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = true
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = true

        let contentSize = scrollView.contentSize
        textView.frame = NSRect(origin: .zero, size: contentSize)
        textView.isRichText = false
        textView.font = EditorSettings.shared.effectiveFont
        textView.textColor = .textColor
        textView.textContainerInset = NSSize(width: 24, height: 20)
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = true
        textView.delegate = self
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.minSize = NSSize(width: 0, height: 0)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.containerSize = NSSize(width: contentSize.width, height: CGFloat.greatestFiniteMagnitude)

        scrollView.documentView = textView
        view.addSubview(scrollView)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: separator.bottomAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(editorSettingsChanged),
            name: .editorSettingsChanged,
            object: nil
        )
    }

    @objc private func editorSettingsChanged() {
        textView.font = EditorSettings.shared.effectiveFont
    }

    func open(url: URL, folder: ImportedFolder) {
        flushPendingSave()
        fileURL = url
        self.folder = folder
        folderLabel.stringValue = folder.name
        textView.string = resolvedFolderURL.map { TextFileManager.read(url, in: $0) } ?? ""
        let modDate = (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? Date()
        updateStatus(date: modDate)
        view.window?.makeFirstResponder(textView)
    }

    func flushPendingSave() {
        guard saveTimer != nil else { return }
        saveNow()
    }

    private func scheduleSave() {
        saveTimer?.invalidate()
        saveTimer = Timer.scheduledTimer(withTimeInterval: 0.6, repeats: false) { [weak self] _ in
            self?.saveNow()
        }
    }

    private func saveNow() {
        saveTimer?.invalidate()
        saveTimer = nil
        guard let fileURL, let folderURL = resolvedFolderURL else { return }
        TextFileManager.write(textView.string, to: fileURL, in: folderURL)
        updateStatus(date: Date())
    }

    private func updateStatus(date: Date) {
        let name = (fileURL?.lastPathComponent as NSString?)?.deletingPathExtension ?? ""
        titleLabel.stringValue = "\(name) \u{2014} Edited \(Self.statusFormatter.string(from: date))"
    }

    @objc private func backTapped() {
        flushPendingSave()
        delegate?.editorDidRequestBack()
    }

    override func viewWillDisappear() {
        super.viewWillDisappear()
        flushPendingSave()
    }
}

extension EditorViewController: NSTextViewDelegate {
    func textDidChange(_ notification: Notification) {
        scheduleSave()
    }
}
