import SwiftUI

/// Brand palette shared across all screens, so a color change happens in
/// exactly one place.
extension Color {
    /// #FFAC00
    static let brandOrange = Color(red: 1.0, green: 0.675, blue: 0.0)
    /// #AD00FF
    static let brandPurple = Color(red: 0.678, green: 0.0, blue: 1.0)
    /// #680099
    static let brandPurpleDark = Color(red: 0.408, green: 0.0, blue: 0.6)
    /// #3D008C — full-screen background of the journey creation flow.
    static let brandDeepPurple = Color(red: 0.24, green: 0.0, blue: 0.55)
}

extension LinearGradient {
    /// Purple capsule-button gradient (#AD00FF → #680099), as on the welcome
    /// screen's "Continue to Journey" button.
    static func brandPurpleButton(
        startPoint: UnitPoint = .leading,
        endPoint: UnitPoint = .trailing
    ) -> LinearGradient {
        LinearGradient(
            colors: [.brandPurple, .brandPurpleDark],
            startPoint: startPoint,
            endPoint: endPoint
        )
    }

    /// The brand gradient (#FFAC00 → #AD00FF).
    static func brand(
        startPoint: UnitPoint = .leading,
        endPoint: UnitPoint = .trailing
    ) -> LinearGradient {
        LinearGradient(
            colors: [.brandOrange, .brandPurple],
            startPoint: startPoint,
            endPoint: endPoint
        )
    }
}
