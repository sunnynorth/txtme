import Foundation

struct TextFileItem: Hashable {
    var url: URL
    var modifiedDate: Date
    var preview: String

    var name: String {
        (url.lastPathComponent as NSString).deletingPathExtension
    }
}

enum TextFileManager {
    /// Lists all .txt files directly inside `folderURL`, sorted by most recently modified.
    static func listTextFiles(in folderURL: URL) -> [TextFileItem] {
        withSecurityScopedAccess(to: folderURL) {
            let fm = FileManager.default
            guard let urls = try? fm.contentsOfDirectory(
                at: folderURL,
                includingPropertiesForKeys: [.contentModificationDateKey],
                options: [.skipsHiddenFiles]
            ) else {
                return []
            }

            let items: [TextFileItem] = urls
                .filter { $0.pathExtension.lowercased() == "txt" }
                .map { url in
                    let content = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
                    let preview = String(content.prefix(500))
                    let modDate = (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?
                        .contentModificationDate ?? .distantPast
                    return TextFileItem(url: url, modifiedDate: modDate, preview: preview)
                }

            return items.sorted { $0.modifiedDate > $1.modifiedDate }
        }
    }

    /// Returns a URL for a new, non-colliding "Untitled.txt" (or "Untitled 2.txt", etc.) inside `folderURL`.
    static func uniqueFileURL(in folderURL: URL, base: String = "Untitled") -> URL {
        let fm = FileManager.default
        return withSecurityScopedAccess(to: folderURL) {
            var candidate = folderURL.appendingPathComponent("\(base).txt")
            var counter = 2
            while fm.fileExists(atPath: candidate.path) {
                candidate = folderURL.appendingPathComponent("\(base) \(counter).txt")
                counter += 1
            }
            return candidate
        }
    }

    @discardableResult
    static func createFile(at url: URL) -> Bool {
        withSecurityScopedAccess(to: url.deletingLastPathComponent()) {
            FileManager.default.createFile(atPath: url.path, contents: Data())
        }
    }

    static func deleteFile(at url: URL) {
        withSecurityScopedAccess(to: url.deletingLastPathComponent()) {
            try? FileManager.default.removeItem(at: url)
        }
    }

    static func read(_ url: URL) -> String {
        withSecurityScopedAccess(to: url.deletingLastPathComponent()) {
            (try? String(contentsOf: url, encoding: .utf8)) ?? ""
        }
    }

    static func write(_ text: String, to url: URL) {
        withSecurityScopedAccess(to: url.deletingLastPathComponent()) {
            try? text.write(to: url, atomically: true, encoding: .utf8)
        }
    }

    /// Renames the file at `url` to `newBaseName`.txt within the same folder, returning the new URL if successful.
    static func rename(_ url: URL, to newBaseName: String) -> URL? {
        let trimmed = newBaseName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let folder = url.deletingLastPathComponent()
        let newURL = folder.appendingPathComponent("\(trimmed).txt")
        guard newURL != url else { return url }
        return withSecurityScopedAccess(to: folder) {
            guard !FileManager.default.fileExists(atPath: newURL.path) else { return nil }
            do {
                try FileManager.default.moveItem(at: url, to: newURL)
                return newURL
            } catch {
                return nil
            }
        }
    }
}
