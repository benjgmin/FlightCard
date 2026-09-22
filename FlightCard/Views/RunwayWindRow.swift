import SwiftUI

struct RunwayWindRow: View {
    let end: Runway.End
    let wind: Wind
    let isFavored: Bool

    var body: some View {
        HStack(spacing: 14) {
            Text(end.designator)
                .font(.title3.weight(.semibold))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(width: 100, alignment: .leading)

            if wind.isCalm {
                Text("Calm").foregroundStyle(.secondary)
            } else if let c = WindCalc.components(for: wind, runway: end) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(alongText(c.steady, gust: c.gust))
                        .foregroundStyle(c.steady.headwindKt <= -2 ? .red : .primary)
                    Text(crossText(c.steady, gust: c.gust))
                        .foregroundStyle(.secondary)
                }
                .font(.subheadline)
                .monospacedDigit()
            } else {
                Text("Variable wind").foregroundStyle(.secondary)
            }

            Spacer()

            if isFavored {
                Text("Favored")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tint)
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .background(
            isFavored ? Color.accentColor.opacity(0.15) : Color.secondary.opacity(0.08),
            in: .rect(cornerRadius: 10)
        )
    }

    /// Pilots use whole knots.
    private func knots(_ value: Double) -> Int {
        Int(abs(value).rounded())
    }

    private func alongText(_ steady: WindComponents, gust: WindComponents?) -> String {
        // Under 2 kt of head/tailwind isn't a meaningful runway difference.
        if abs(steady.headwindKt) < 2 { return "Near-direct crosswind" }
        let label = steady.headwindKt < 0 ? "Tailwind" : "Headwind"
        let base = "\(label) \(knots(steady.headwindKt)) kt"
        guard let gust else { return base }
        return base + ", gust \(knots(gust.headwindKt))"
    }

    private func crossText(_ steady: WindComponents, gust: WindComponents?) -> String {
        let side = steady.crosswindFromRight ? "right" : "left"
        let base = "Crosswind \(knots(steady.crosswindKt)) kt \(side)"
        guard let gust else { return base }
        return base + ", gust \(knots(gust.crosswindKt))"
    }
}
