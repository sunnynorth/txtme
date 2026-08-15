import Cocoa

protocol EditorViewControllerDelegate: AnyObject {
    func editorDidRequestBack()
}

private func leadingWhitespace(of line: String) -> String {
    String(line.prefix { $0 == " " || $0 == "\t" })
}

/// If `line` starts with a list marker (numbered, lettered, or bulleted), returns the marker
/// that should continue it on the next line. The marker is recognized whether or not a space
/// has been typed after it yet, since Return is often pressed right after the punctuation.
private func nextListMarker(for line: String) -> String? {
    if line.range(of: #"^[-*•](\s+|$)"#, options: .regularExpression) != nil, let symbol = line.first {
        return "\(symbol) "
    }
    if let match = line.range(of: #"^\d+[.)](\s+|$)"#, options: .regularExpression) {
        let raw = line[match]
        let digits = raw.prefix { $0.isNumber }
        guard let number = Int(digits) else { return nil }
        let separator = raw[digits.endIndex]
        return "\(number + 1)\(separator) "
    }
    if let match = line.range(of: #"^[A-Za-z][.)](\s+|$)"#, options: .regularExpression) {
        let raw = line[match]
        guard let letter = raw.first, let asciiValue = letter.asciiValue else { return nil }
        let separator = raw[raw.index(after: raw.startIndex)]
        return "\(Character(Unicode.Scalar(asciiValue + 1)))\(separator) "
    }
    return nil
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
        textView.isContinuousSpellCheckingEnabled = true
        textView.isAutomaticSpellingCorrectionEnabled = false
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
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(focusModeChanged),
            name: .focusModeChanged,
            object: nil
        )
    }

    @objc private func editorSettingsChanged() {
        textView.font = EditorSettings.shared.effectiveFont
        if FocusModeState.shared.isEnabled {
            updateFocusDimming()
        }
    }

    @objc private func focusModeChanged() {
        if FocusModeState.shared.isEnabled {
            updateFocusDimming()
        } else {
            clearFocusDimming()
        }
    }

    /// Dims every paragraph except the one containing the cursor, for distraction-free writing.
    /// Purely visual (an NSAttributedString attribute) — never touches the saved plain-text content.
    private func updateFocusDimming() {
        guard let textStorage = textView.textStorage else { return }
        let fullText = textView.string as NSString
        guard fullText.length > 0 else { return }

        let cursor = min(textView.selectedRange().location, fullText.length)
        let activeRange = fullText.paragraphRange(for: NSRange(location: cursor, length: 0))
        let fullRange = NSRange(location: 0, length: fullText.length)
        let dimColor = NSColor.textColor.withAlphaComponent(0.25)

        textStorage.beginEditing()
        textStorage.addAttribute(.foregroundColor, value: dimColor, range: fullRange)
        textStorage.addAttribute(.foregroundColor, value: NSColor.textColor, range: activeRange)
        textStorage.endEditing()
    }

    private func clearFocusDimming() {
        guard let textStorage = textView.textStorage else { return }
        let fullRange = NSRange(location: 0, length: (textView.string as NSString).length)
        guard fullRange.length > 0 else { return }
        textStorage.addAttribute(.foregroundColor, value: NSColor.textColor, range: fullRange)
    }

    func open(url: URL, folder: ImportedFolder) {
        flushPendingSave()
        fileURL = url
        self.folder = folder
        folderLabel.stringValue = folder.name
        textView.string = resolvedFolderURL.map { TextFileManager.read(url, in: $0) } ?? ""
        let modDate = (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? Date()
        updateStatus(date: modDate)
        if FocusModeState.shared.isEnabled {
            updateFocusDimming()
        }
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
        if FocusModeState.shared.isEnabled {
            updateFocusDimming()
        }
    }

    func textViewDidChangeSelection(_ notification: Notification) {
        if FocusModeState.shared.isEnabled {
            updateFocusDimming()
        }
    }

    func textView(_ textView: NSTextView, shouldChangeTextIn affectedCharRange: NSRange, replacementString: String?) -> Bool {
        guard replacementString == "\n", affectedCharRange.length == 0 else { return true }
        return handleReturnKey(in: textView, at: affectedCharRange)
    }

    /// Continues the current line's indentation, and if the line is a list item, its marker
    /// (numbered, lettered, or bulleted) auto-incremented on the new line.
    private func handleReturnKey(in textView: NSTextView, at range: NSRange) -> Bool {
        let text = textView.string as NSString
        let lineStart = text.lineRange(for: NSRange(location: range.location, length: 0)).location
        let beforeCursorRange = NSRange(location: lineStart, length: range.location - lineStart)
        let currentLine = text.substring(with: beforeCursorRange)

        let indent = leadingWhitespace(of: currentLine)
        let contentAfterIndent = String(currentLine.dropFirst(indent.count))

        guard let marker = nextListMarker(for: contentAfterIndent) else {
            guard !indent.isEmpty else { return true }
            return replaceText(in: textView, range: range, with: "\n" + indent)
        }

        return replaceText(in: textView, range: range, with: "\n" + indent + marker)
    }

    private func replaceText(in textView: NSTextView, range: NSRange, with replacement: String) -> Bool {
        guard textView.shouldChangeText(in: range, replacementString: replacement) else { return false }
        textView.textStorage?.replaceCharacters(in: range, with: replacement)
        textView.didChangeText()
        return false
    }
}
