import SwiftUI

extension Color {
    // Brand manual: PMS 485 and black
    static let brandRed = Color(red: 238/255, green: 20/255, blue: 10/255) // #EE140A
}

extension Font {
    // Helvetica Bold, the institutional typeface
    static func brand(_ size: CGFloat) -> Font {
        .custom("HelveticaNeue-Bold", size: size)
    }
}
