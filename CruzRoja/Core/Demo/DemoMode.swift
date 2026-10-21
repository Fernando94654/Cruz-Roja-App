import Foundation

// Screenshot mode: launch with -demo report, -demo family, etc.
enum DemoMode {
    static let current = UserDefaults.standard.string(forKey: "demo") ?? ""

    static func isActive(_ names: String...) -> Bool {
        names.contains(current)
    }
}
