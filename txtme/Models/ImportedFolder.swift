import Foundation

struct ImportedFolder: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var bookmarkData: Data
}

/// Runs `perform` while the security-scoped resource at `url` is accessible.
func withSecurityScopedAccess<T>(to url: URL, perform: () throws -> T) rethrows -> T {
    let accessing = url.startAccessingSecurityScopedResource()
    defer { if accessing { url.stopAccessingSecurityScopedResource() } }
    return try perform()
}

final class FolderStore {
    static let shared = FolderStore()

    private let defaultsKey = "com.txtme.importedFolders"
    private(set) var folders: [ImportedFolder] = []

    private init() {
        load()
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: defaultsKey),
              let decoded = try? JSONDecoder().decode([ImportedFolder].self, from: data) else { return }
        folders = decoded
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(folders) else { return }
        UserDefaults.standard.set(data, forKey: defaultsKey)
    }

    @discardableResult
    func addFolder(url: URL) -> ImportedFolder? {
        if let existing = folders.first(where: { resolveURL(for: $0) == url }) {
            return existing
        }
        guard let bookmark = try? url.bookmarkData(
            options: [.withSecurityScope],
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        ) else {
            return nil
        }
        let folder = ImportedFolder(id: UUID(), name: url.lastPathComponent, bookmarkData: bookmark)
        folders.append(folder)
        persist()
        return folder
    }

    func removeFolder(_ folder: ImportedFolder) {
        folders.removeAll { $0.id == folder.id }
        persist()
    }

    /// Resolves the folder's bookmark to a URL, refreshing the stored bookmark if it was stale.
    func resolveURL(for folder: ImportedFolder) -> URL? {
        var isStale = false
        guard let url = try? URL(
            resolvingBookmarkData: folder.bookmarkData,
            options: [.withSecurityScope],
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        ) else {
            return nil
        }

        if isStale, let refreshed = try? url.bookmarkData(
            options: [.withSecurityScope],
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        ), let idx = folders.firstIndex(where: { $0.id == folder.id }) {
            folders[idx].bookmarkData = refreshed
            persist()
        }
        return url
    }
}
