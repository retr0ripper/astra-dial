import Foundation

/// A dotted numeric version such as "0.1.0" or a "v1.2" tag, compared component by
/// component. Missing trailing components count as zero, so "1.0" equals "1.0.0".
public struct AppVersion: Comparable, Hashable, Sendable, CustomStringConvertible {
    public let components: [Int]

    public init(components: [Int]) {
        self.components = components
    }

    /// Parses "1.2.3" with an optional leading "v". Pre-release suffixes aren't supported.
    public init?(_ string: String) {
        var text = Substring(string)
        if text.first == "v" || text.first == "V" { text = text.dropFirst() }
        let parts = text.split(separator: ".", omittingEmptySubsequences: false)
        let numbers = parts.compactMap { part in part.allSatisfy(\.isASCII) ? Int(part) : nil }
        guard !parts.isEmpty, numbers.count == parts.count, numbers.allSatisfy({ $0 >= 0 }) else { return nil }
        components = numbers
    }

    public var description: String { components.map(String.init).joined(separator: ".") }

    public static func < (lhs: AppVersion, rhs: AppVersion) -> Bool {
        let count = max(lhs.components.count, rhs.components.count)
        for index in 0..<count {
            let left = lhs.component(index), right = rhs.component(index)
            if left != right { return left < right }
        }
        return false
    }

    public static func == (lhs: AppVersion, rhs: AppVersion) -> Bool {
        lhs.trimmed == rhs.trimmed
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(trimmed)
    }

    private func component(_ index: Int) -> Int {
        index < components.count ? components[index] : 0
    }

    private var trimmed: [Int] {
        var result = components
        while result.last == 0 { result.removeLast() }
        return result
    }
}
