import Foundation

enum APIConfig {
    // Backend deployed on Render; for a local backend use "http://127.0.0.1:8000" (simulator)
    static let baseURL = URL(string: "https://cruz-roja-app.onrender.com")!

    // Demo user created by backend/scripts/seed.py until real sign-in exists
    static let demoUserID = UUID(uuidString: "00000000-0000-4000-8000-000000000001")!

    static let timeout: TimeInterval = 10

    // Cruz Roja operator number that receives the SMS; demo value
    static let operatorPhone = "8112345678"
}
