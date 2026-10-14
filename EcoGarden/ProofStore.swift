import UIKit

/// Photo proof for completed tasks. Photos are shrunk and kept as JPEG files on disk;
/// a task only remembers its file's name. (They used to be stored full-size inside
/// UserDefaults, which is rewritten on every change and isn't meant for images.)
enum ProofStore {
    /// Longest side of a saved photo, in pixels — plenty for viewing on a phone.
    private static let maxDimension: CGFloat = 1200
    private static let cache = NSCache<NSString, UIImage>()

    private static var folder: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Proofs", isDirectory: true)
    }

    /// Shrinks and saves a photo. Returns its file name, or nil if the data isn't a
    /// readable image or couldn't be written.
    static func save(_ imageData: Data) -> String? {
        guard let image = UIImage(data: imageData) else { return nil }
        let longestSide = max(image.size.width, image.size.height)
        guard longestSide > 0 else { return nil }

        let scale = min(1, maxDimension / longestSide)
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let resized = UIGraphicsImageRenderer(size: size, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
        guard let jpeg = resized.jpegData(compressionQuality: 0.8) else { return nil }

        // A fresh name every time, so a replaced photo can never show a stale cached image.
        let name = UUID().uuidString + ".jpg"
        do {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            try jpeg.write(to: folder.appendingPathComponent(name), options: .atomic)
            return name
        } catch {
            return nil
        }
    }

    static func image(named name: String) -> UIImage? {
        if let cached = cache.object(forKey: name as NSString) { return cached }
        guard let image = UIImage(contentsOfFile: folder.appendingPathComponent(name).path) else { return nil }
        cache.setObject(image, forKey: name as NSString)
        return image
    }

    static func delete(named name: String) {
        cache.removeObject(forKey: name as NSString)
        try? FileManager.default.removeItem(at: folder.appendingPathComponent(name))
    }
}
