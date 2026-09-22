import SwiftUI

struct RunwayWindRow: View {
    let end: Runway.End
    let wind: Wind
    let crosswindLimit: Int

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            Text(end.designator)
                .font(.display(24))
                .foregroundStyle(Theme.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .frame(width: 84, alignment: .leading)

            if wind.isCalm {
                Text("Calm").foregroundStyle(Theme.dim)
            } else if let c = WindCalc.components(for: wind, runway: end) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(alongText(c.steady, gust: c.gust))
                        .foregroundStyle(c.steady.headwindKt <= -2 ? Theme.caution : Theme.ink)
                    Text(crossText(c.steady, gust: c.gust))
                        .foregroundStyle(overLimit(c.steady, c.gust) ? Theme.warning : Theme.dim)
                }
                .font(.subheadline)
                .monospacedDigit()
            } else {
                Text("Variable wind").foregroundStyle(Theme.dim)
            }

            Spacer(minLength: 0)

            if let c = WindCalc.components(for: wind, runway: end), !wind.isCalm, overLimit(c.steady, c.gust) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(Theme.warning)
                    .accessibilityLabel("Over your crosswind limit")
            }
        }
        .padding(.vertical, 12)
    }

    /// Pilots use whole knots.
    private func knots(_ value: Double) -> Int {
        Int(abs(value).rounded())
    }

    private func overLimit(_ steady: WindComponents, _ gust: WindComponents?) -> Bool {
        max(abs(steady.crosswindKt), abs(gust?.crosswindKt ?? 0)).rounded() > Double(crosswindLimit)
    }

    private func alongText(_ steady: WindComponents, gust: WindComponents?) -> String {
        // Under 2 kt of head/tailwind isn't a meaningful runway difference.
        if abs(steady.headwindKt) < 2 { return "Near-direct crosswind" }
        let label = steady.headwindKt < 0 ? "Tailwind" : "Headwind"
        let base = "\(label) \(knots(steady.headwindKt)) kt"
        guard let gust, knots(gust.headwindKt) > knots(steady.headwindKt) else { return base }
        return base + ", gust \(knots(gust.headwindKt))"
    }

    private func crossText(_ steady: WindComponents, gust: WindComponents?) -> String {
        if knots(steady.crosswindKt) == 0 && knots(gust?.crosswindKt ?? 0) == 0 { return "No crosswind" }
        let side = steady.crosswindFromRight ? "right" : "left"
        var text = "Crosswind \(knots(steady.crosswindKt)) kt \(side)"
        if let gust, knots(gust.crosswindKt) > knots(steady.crosswindKt) {
            text += ", gust \(knots(gust.crosswindKt))"
        }
        return text
    }
}
