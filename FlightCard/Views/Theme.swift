import SwiftUI
import UIKit

/// Glass-cockpit palette with light and dark variants. Cyan for wind (like G1000
/// selected values), amber for caution, red for warnings. Flight category colors stay FAA standard.
enum Theme {
    static let panel = adaptive(light: 0xF3F5F8, dark: 0x10151C)
    static let bezel = adaptive(light: 0xFFFFFF, dark: 0x1C232D)
    static let hairline = adaptive(light: 0x000000, dark: 0xFFFFFF, lightAlpha: 0.08, darkAlpha: 0.09)
    static let ink = adaptive(light: 0x111820, dark: 0xF2F5F8)
    static let dim = adaptive(light: 0x5E6978, dark: 0x8F9CAD)
    static let cyan = adaptive(light: 0x0077B6, dark: 0x40D1FF)
    static let caution = adaptive(light: 0xB26A00, dark: 0xFFC238)
    static let warning = adaptive(light: 0xD1342F, dark: 0xFF5C54)

    private static func adaptive(light: UInt32, dark: UInt32,
                                 lightAlpha: CGFloat = 1, darkAlpha: CGFloat = 1) -> Color {
        let lightColor = uiColor(light, alpha: lightAlpha)
        let darkColor = uiColor(dark, alpha: darkAlpha)
        return Color(UIColor { traits in
            traits.userInterfaceStyle == .dark ? darkColor : lightColor
        })
    }

    private static func uiColor(_ hex: UInt32, alpha: CGFloat) -> UIColor {
        UIColor(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: alpha
        )
    }
}

extension Font {
    /// Condensed bold, like runway markings and airport signage.
    static func display(_ size: CGFloat) -> Font {
        .system(size: size, weight: .bold).width(.condensed)
    }
}

struct SectionTitle: View {
    let title: String
    var detail: String? = nil

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.title3.weight(.semibold))
                .foregroundStyle(Theme.ink)
            Spacer()
            if let detail {
                Text(detail)
                    .font(.footnote)
                    .foregroundStyle(Theme.dim)
            }
        }
    }
}

extension Wind {
    /// Pilot shorthand: "030/10G20", "VRB/05", "Calm".
    var shorthand: String {
        if isCalm { return "Calm" }
        let gust = gustKt.map { "G\($0)" } ?? ""
        switch direction {
        case .trueDegrees(let degrees):
            return String(format: "%03d/%02d", degrees, speedKt) + gust
        case .variable:
            return String(format: "VRB/%02d", speedKt) + gust
        }
    }
}
