import UIKit

// Proof photos are resized and saved as files; tasks just store the file name.
enum ProofStore {
    private static let maxDimension: CGFloat = 1200
    private static let cache = NSCache<NSString, UIImage>()

    private static var folder: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Proofs", isDirectory: true)
    }

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

        // New name each time so the cache never shows an old photo.
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
