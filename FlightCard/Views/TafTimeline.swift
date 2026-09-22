//
//  TafTimeline.swift
//  FlightCard
//
//  Created by Benjamin Eccles on 9/22/26.
//


import SwiftUI

struct TafTimeline: View {
    let taf: Taf

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Forecast").font(.headline)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 10) {
                    ForEach(taf.periods) { period in
                        TafPeriodCard(period: period, category: taf.flightCategory(for: period))
                    }
                }
            }

            Text(taf.rawText)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
        }
    }
}

private struct TafPeriodCard: View {
    let period: TafPeriod
    let category: FlightCategory

    private var isTemporary: Bool { !period.isPrevailing }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(category.rawValue)
                .font(.caption.weight(.bold))
                .foregroundStyle(category.color)

            VStack(alignment: .leading, spacing: 1) {
                Text("\(Self.zulu.string(from: period.start))–\(Self.zulu.string(from: period.end))")
                    .font(.subheadline.weight(.semibold))
                Text(period.start.formatted(.dateTime.weekday(.abbreviated).hour()))
                    .foregroundStyle(.secondary)
            }

            if let label = changeLabel {
                Text(label).foregroundStyle(.secondary).italic()
            }

            Divider()

            if let wind = period.wind { Text(windText(wind)) }
            if let vis = period.visibility { Text(visibilityText(vis)) }
            ForEach(Array(period.clouds.prefix(2).enumerated()), id: \.offset) { _, layer in
                if let base = layer.base { Text("\(layer.cover) \(base.formatted())") }
            }
            if let vv = period.verticalVisibility { Text("VV \(vv.formatted())") }
            if let weather = period.weather { Text(weather).foregroundStyle(.secondary) }
        }
        .font(.caption)
        .monospacedDigit()
        .padding(12)
        .frame(width: 150, alignment: .leading)
        .background {
            if isTemporary {
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(category.color.opacity(0.6), style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
            } else {
                RoundedRectangle(cornerRadius: 10)
                    .fill(category.color.opacity(0.12))
            }
        }
    }

    private static let zulu: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH'Z'"
        formatter.timeZone = .gmt
        return formatter
    }()

    private var changeLabel: String? {
        switch period.change {
        case .prevailing: nil
        case .becoming: "Becoming"
        case .temporary: "Temporary"
        case .probability(let percent): "\(percent)% chance"
        }
    }

    private func windText(_ wind: Wind) -> String {
        if wind.isCalm { return "Calm" }
        let gust = wind.gustKt.map { "G\($0)" } ?? ""
        switch wind.direction {
        case .trueDegrees(let degrees): return String(format: "%03d° %d", degrees, wind.speedKt) + gust + " kt"
        case .variable: return "VRB \(wind.speedKt)" + gust + " kt"
        }
    }

    private func visibilityText(_ vis: Visibility) -> String {
        let miles = vis.statuteMiles.formatted(.number.precision(.fractionLength(0...2)))
        return vis.isGreaterThan ? "\(miles)+ SM" : "\(miles) SM"
    }
}