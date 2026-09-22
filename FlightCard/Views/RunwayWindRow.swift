//
//  RunwayWindRow.swift
//  FlightCard
//
//  Created by Benjamin Eccles on 9/22/26.
//


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
                .frame(width: 56, alignment: .leading)

            if wind.isCalm {
                Text("Calm").foregroundStyle(.secondary)
            } else if let c = WindCalc.components(for: wind, runway: end) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(alongText(c.steady, gust: c.gust))
                        .foregroundStyle(c.steady.isTailwind ? .red : .primary)
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
        let label = steady.isTailwind ? "Tailwind" : "Headwind"
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