import Foundation

enum APIConfig {
    // Simulator reaches the Mac at 127.0.0.1; on a device use the Mac's LAN IP and run uvicorn with --host 0.0.0.0
    static let baseURL = URL(string: "http://127.0.0.1:8000")!

    // Demo user created by backend/scripts/seed.py until real sign-in exists
    static let demoUserID = UUID(uuidString: "00000000-0000-4000-8000-000000000001")!

    static let timeout: TimeInterval = 10
}
