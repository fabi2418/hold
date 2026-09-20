import SwiftUI

/// Farb- und Massangaben aus docs/04_REFERENZEN.md plus den vom Prototyp
/// nachgereichten Werten (P2-Korrektur).
enum Theme {
    // Farben
    static let panel = Color(red: 251 / 255, green: 251 / 255, blue: 253 / 255)        // #FBFBFD
    static let border = Color(red: 210 / 255, green: 210 / 255, blue: 215 / 255)       // #D2D2D7
    static let divider = Color(red: 229 / 255, green: 229 / 255, blue: 234 / 255)      // #E5E5EA
    static let footer = Color(red: 242 / 255, green: 242 / 255, blue: 247 / 255)       // #F2F2F7
    static let text = Color(red: 29 / 255, green: 29 / 255, blue: 31 / 255)            // #1D1D1F
    static let secondary = Color(red: 110 / 255, green: 110 / 255, blue: 115 / 255)    // #6E6E73
    static let accent = Color(red: 0 / 255, green: 100 / 255, blue: 210 / 255)         // #0064D2
    static let fieldText = Color(red: 58 / 255, green: 58 / 255, blue: 60 / 255)       // #3A3A3C
    static let descriptionField = Color(red: 245 / 255, green: 245 / 255, blue: 247 / 255) // #F5F5F7
    static let commandField = Color.white                                              // #FFFFFF
    static let dashedBorder = Color(red: 199 / 255, green: 199 / 255, blue: 204 / 255) // #C7C7CC
    static let selectionFill = Color(red: 232 / 255, green: 240 / 255, blue: 252 / 255)     // #E8F0FC

    // Panel
    static let panelWidth: CGFloat = 1080
    static let panelRadius: CGFloat = 16
    static let contentHeight: CGFloat = 470
    static let contentPaddingTop: CGFloat = 14
    static let contentPaddingSides: CGFloat = 22
    static let contentPaddingBottom: CGFloat = 18

    // Zeile (M5)
    static let descriptionWidth: CGFloat = 300
    static let copyButtonWidth: CGFloat = 44
    static let fieldHeight: CGFloat = 36
    static let fieldRadius: CGFloat = 8
    static let fieldPadding: CGFloat = 12
    static let rowGap: CGFloat = 12
    static let rowRadius: CGFloat = 10
    static let rowInset: CGFloat = 10
    static let badgeWidth: CGFloat = 56
}
