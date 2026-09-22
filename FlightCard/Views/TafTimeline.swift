import SwiftUI

/// Forecast periods as color-coded segments on a Zulu time axis.
/// Prevailing conditions on top, TEMPO/PROB groups in a dashed lane below.
struct TafTimeline: View {
    let taf: Taf
    @State private var selectedID: UUID?

    private let mainHeight: CGFloat = 32
    private let changeHeight: CGFloat = 16
    private let laneGap: CGFloat = 8

    private var start: Date { taf.periods.map(\.start).min() ?? .now }
    private var end: Date { taf.periods.map(\.end).max() ?? .now }
    private var prevailing: [TafPeriod] { taf.periods.filter(\.isPrevailing) }
    private var changes: [TafPeriod] { taf.periods.filter { !$0.isPrevailing } }

    private var lanesHeight: CGFloat {
        changes.isEmpty ? mainHeight : mainHeight + laneGap + changeHeight
    }

    /// Tapped period, or whatever is in effect right now.
    private var selected: TafPeriod? {
        if let selectedID, let period = taf.periods.first(where: { $0.id == selectedID }) {
            return period
        }
        return prevailing.last { $0.start <= .now } ?? prevailing.first
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionTitle(title: "Forecast", detail: "Tap a period")

            GeometryReader { geo in
                let width = geo.size.width
                ZStack(alignment: .topLeading) {
                    ForEach(prevailing) { period in
                        segment(period, width: width, y: 0, height: mainHeight)
                    }
                    ForEach(changes) { period in
                        segment(period, width: width, y: mainHeight + laneGap, height: changeHeight)
                    }
                    if (start...end).contains(Date.now) {
                        Rectangle()
                            .fill(Theme.cyan)
                            .frame(width: 2, height: lanesHeight + 8)
                            .position(x: x(.now, width), y: lanesHeight / 2)
                            .allowsHitTesting(false)
                    }
                    ForEach(ticks, id: \.self) { tick in
                        Text(TafFormat.zulu.string(from: tick))
                            .font(.caption2)
                            .monospacedDigit()
                            .foregroundStyle(Theme.dim)
                            .fixedSize()
                            .position(x: min(max(x(tick, width), 14), width - 14), y: lanesHeight + 16)
                    }
                }
                .frame(width: width, height: lanesHeight + 26, alignment: .topLeading)
            }
            .frame(height: lanesHeight + 26)

            if let selected {
                PeriodDetail(period: selected, category: taf.flightCategory(for: selected))
            }

            Text(taf.rawText)
                .font(.system(.footnote, design: .monospaced))
                .foregroundStyle(Theme.dim)
                .textSelection(.enabled)
        }
    }

    private func segment(_ period: TafPeriod, width: CGFloat, y: CGFloat, height: CGFloat) -> some View {
        let category = taf.flightCategory(for: period)
        let x0 = x(period.start, width)
        let barWidth = max(x(period.end, width) - x0 - 2, 4)
        let isSelected = period.id == selected?.id

        return Group {
            if period.isPrevailing {
                RoundedRectangle(cornerRadius: 5)
                    .fill(category.color.opacity(isSelected ? 1 : 0.5))
                    .overlay {
                        if barWidth > 44 {
                            Text(category.rawValue)
                                .font(.caption2.weight(.heavy))
                                .fontWidth(.condensed)
                                .foregroundStyle(.white.opacity(isSelected ? 1 : 0.8))
                        }
                    }
            } else {
                RoundedRectangle(cornerRadius: 4)
                    .strokeBorder(category.color,
                                  style: StrokeStyle(lineWidth: isSelected ? 2 : 1, dash: [4, 3]))
            }
        }
        .frame(width: barWidth, height: height)
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.snappy) { selectedID = period.id }
        }
        .position(x: x0 + barWidth / 2 + 1, y: y + height / 2)
    }

    private func x(_ date: Date, _ width: CGFloat) -> CGFloat {
        let total = end.timeIntervalSince(start)
        guard total > 0 else { return 0 }
        let fraction = min(max(date.timeIntervalSince(start) / total, 0), 1)
        return width * CGFloat(fraction)
    }

    /// Every 6 hours on the Zulu clock (00Z, 06Z, 12Z, 18Z).
    private var ticks: [Date] {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .gmt
        var components = calendar.dateComponents([.year, .month, .day, .hour], from: start)
        components.minute = 0
        guard var tick = calendar.date(from: components) else { return [] }
        var result: [Date] = []
        while tick <= end {
            if tick >= start, calendar.component(.hour, from: tick) % 6 == 0 {
                result.append(tick)
            }
            tick = tick.addingTimeInterval(3600)
        }
        return result
    }
}

private enum TafFormat {
    static let zulu: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH'Z'"
        formatter.timeZone = .gmt
        return formatter
    }()
}

private struct PeriodDetail: View {
    let period: TafPeriod
    let category: FlightCategory

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("\(TafFormat.zulu.string(from: period.start))–\(TafFormat.zulu.string(from: period.end))")
                    .font(.headline)
                    .monospacedDigit()
                Text(period.start.formatted(.dateTime.weekday(.abbreviated).hour()))
                    .font(.subheadline)
                    .foregroundStyle(Theme.dim)
                Spacer()
                FlightCategoryBadge(category: category, compact: true)
            }
            if let label = changeLabel {
                Text(label)
                    .font(.footnote)
                    .foregroundStyle(Theme.caution)
            }
            HStack(alignment: .top, spacing: 0) {
                item("Wind", period.wind?.shorthand ?? "No change")
                item("Visibility", visibilityText)
                item("Sky", skyText)
            }
            if let weather = period.weather {
                Text("Weather: \(weather)")
                    .font(.footnote)
                    .foregroundStyle(Theme.dim)
            }
        }
        .foregroundStyle(Theme.ink)
        .padding(14)
        .background(Theme.bezel, in: .rect(cornerRadius: 12))
    }

    private func item(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .font(.caption)
                .foregroundStyle(Theme.dim)
            Text(value)
                .font(.subheadline.weight(.medium))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var changeLabel: String? {
        switch period.change {
        case .prevailing: nil
        case .becoming: "Becoming. Conditions change gradually during this window."
        case .temporary: "Temporary. Expect these conditions on and off, not the whole time."
        case .probability(let percent): "\(percent)% chance of these conditions."
        }
    }

    private var visibilityText: String {
        guard let vis = period.visibility else { return "No change" }
        let miles = vis.statuteMiles.formatted(.number.precision(.fractionLength(0...2)))
        return vis.isGreaterThan ? "\(miles)+ SM" : "\(miles) SM"
    }

    private var skyText: String {
        if let ceiling = period.ceilingFeet { return "Ceiling \(ceiling.formatted())" }
        if let lowest = period.clouds.first, let base = lowest.base {
            return "\(lowest.cover) \(base.formatted())"
        }
        return period.hasSkyInfo ? "Clear" : "No change"
    }
}
