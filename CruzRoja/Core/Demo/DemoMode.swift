import Foundation

// Screenshot mode: launch with -demo report, -demo family, etc.
enum DemoMode {
    static let current = UserDefaults.standard.string(forKey: "demo") ?? ""

    // Presentation mode: no server and no sign in, every screen uses sample data.
    // Set it to false to use the real backend
    static let offline = false

    static func isActive(_ names: String...) -> Bool {
        names.contains(current)
    }
}
