import Foundation

struct AspectRatio {
    let width: Int
    let height: Int

    init?(width: Int, height: Int) {
        guard width > 0, height > 0 else { return nil }
        self.width = width
        self.height = height
    }

    init?(_ string: String) {
        let parts = string.split(separator: ":").compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }
        guard parts.count == 2 else { return nil }
        self.init(width: parts[0], height: parts[1])
    }

    /// The ratio of a pixel size, reduced to lowest terms (e.g. 640×360 → 16:9).
    init?(reducing size: CGSize) {
        var a = Int(size.width), b = Int(size.height)
        guard a > 0, b > 0 else { return nil }
        while b != 0 { (a, b) = (b, a % b) }
        self.init(width: Int(size.width) / a, height: Int(size.height) / a)
    }

    var value: CGFloat { CGFloat(width) / CGFloat(height) }
    var title: String { "\(width):\(height)" }

    static let landscape = [(1, 1), (5, 4), (4, 3), (3, 2), (16, 10), (16, 9), (21, 9)].map { AspectRatio(width: $0.0, height: $0.1)! }
    static let portrait = [(4, 5), (3, 4), (2, 3), (9, 16)].map { AspectRatio(width: $0.0, height: $0.1)! }

    private static let customKey = "CustomAspectRatios"

    static var custom: [AspectRatio] {
        get { (UserDefaults.standard.stringArray(forKey: customKey) ?? []).compactMap { AspectRatio($0) } }
        set { UserDefaults.standard.set(newValue.map(\.title), forKey: customKey) }
    }

    static var presets: [AspectRatio] { landscape + portrait + custom }
}

extension AspectRatio: Equatable {
    // 16:9 and 32:18 are the same ratio.
    static func == (a: AspectRatio, b: AspectRatio) -> Bool {
        a.width * b.height == a.height * b.width
    }
}

