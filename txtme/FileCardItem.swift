import Cocoa

protocol FileCardItemDelegate: AnyObject {
    func fileCardDidRequestRename(_ item: TextFileItem)
    func fileCardDidRequestDelete(_ item: TextFileItem)
    func fileCardDidRequestReveal(_ item: TextFileItem)
}

final class FileCardItem: NSCollectionViewItem {
    static let identifier = NSUserInterfaceItemIdentifier("FileCardItem")

    weak var delegate: FileCardItemDelegate?
    private var fileItem: TextFileItem?

    private let cardView: NSView = {
        let view = NSView()
        view.wantsLayer = true
        view.layer?.cornerRadius = 10
        view.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
        view.layer?.borderWidth = 1
        view.layer?.borderColor = NSColor.separatorColor.cgColor
        return view
    }()

    private let titleLabel: NSTextField = {
        let label = NSTextField(labelWithString: "")
        label.font = .systemFont(ofSize: 13, weight: .semibold)
        label.lineBreakMode = .byTruncatingTail
        label.maximumNumberOfLines = 1
        return label
    }()

    private let previewLabel: NSTextField = {
        let label = NSTextField(wrappingLabelWithString: "")
        label.font = .systemFont(ofSize: 11.5)
        label.textColor = .secondaryLabelColor
        label.maximumNumberOfLines = 11
        return label
    }()

    private let dateLabel: NSTextField = {
        let label = NSTextField(labelWithString: "")
        label.font = .systemFont(ofSize: 10.5)
        label.textColor = .tertiaryLabelColor
        return label
    }()

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()

    override func loadView() {
        let root = NSView()

        cardView.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        previewLabel.translatesAutoresizingMaskIntoConstraints = false
        dateLabel.translatesAutoresizingMaskIntoConstraints = false

        root.addSubview(cardView)
        cardView.addSubview(titleLabel)
        cardView.addSubview(previewLabel)
        cardView.addSubview(dateLabel)

        NSLayoutConstraint.activate([
            cardView.leadingAnchor.constraint(equalTo: root.leadingAnchor),
            cardView.trailingAnchor.constraint(equalTo: root.trailingAnchor),
            cardView.topAnchor.constraint(equalTo: root.topAnchor),
            cardView.bottomAnchor.constraint(equalTo: root.bottomAnchor),

            titleLabel.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 14),
            titleLabel.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -14),
            titleLabel.topAnchor.constraint(equalTo: cardView.topAnchor, constant: 12),

            previewLabel.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 14),
            previewLabel.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -14),
            previewLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 6),

            dateLabel.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 14),
            dateLabel.bottomAnchor.constraint(equalTo: cardView.bottomAnchor, constant: -10),
        ])

        view = root
    }

    override var isSelected: Bool {
        didSet {
            cardView.layer?.borderColor = (isSelected ? NSColor.controlAccentColor : NSColor.separatorColor).cgColor
            cardView.layer?.borderWidth = isSelected ? 2 : 1
        }
    }

    func configure(with item: TextFileItem) {
        fileItem = item
        titleLabel.stringValue = item.name
        let trimmedPreview = item.preview.trimmingCharacters(in: .whitespacesAndNewlines)
        previewLabel.stringValue = trimmedPreview.isEmpty ? "Empty" : trimmedPreview
        dateLabel.stringValue = Self.dateFormatter.string(from: item.modifiedDate)
        view.menu = makeMenu()
    }

    private func makeMenu() -> NSMenu {
        let menu = NSMenu()

        let rename = NSMenuItem(title: "Rename", action: #selector(renameTapped), keyEquivalent: "")
        rename.target = self
        menu.addItem(rename)

        let reveal = NSMenuItem(title: "Reveal in Finder", action: #selector(revealTapped), keyEquivalent: "")
        reveal.target = self
        menu.addItem(reveal)

        menu.addItem(.separator())

        let delete = NSMenuItem(title: "Delete", action: #selector(deleteTapped), keyEquivalent: "")
        delete.target = self
        menu.addItem(delete)

        return menu
    }

    @objc private func renameTapped() {
        guard let fileItem else { return }
        delegate?.fileCardDidRequestRename(fileItem)
    }

    @objc private func revealTapped() {
        guard let fileItem else { return }
        delegate?.fileCardDidRequestReveal(fileItem)
    }

    @objc private func deleteTapped() {
        guard let fileItem else { return }
        delegate?.fileCardDidRequestDelete(fileItem)
    }
}
