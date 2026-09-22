
import SwiftUI

// MARK: - Loader

@MainActor
@Observable
final class AirportCardModel {
    enum State {
        case loading
        case loaded(Metar, Airport?)
        case failed(String)
    }

    private(set) var state: State = .loading
    let icao: String

    init(icao: String) {
        self.icao = icao
    }

    func load() async {
        do {
            let metar = try await AWCClient.shared.metar(for: icao)
            // Runway data is a bonus. The card still works without it.
            let airport = try? await AWCClient.shared.airport(for: icao)
            state = .loaded(metar, airport)
        } catch {
            // On a failed refresh, keep showing the last good data.
            if case .loaded = state { return }
            state = .failed(error.localizedDescription)
        }
    }
}

// MARK: - Screen

struct AirportCardView: View {
    let icao: String
    @State private var model: AirportCardModel

    init(icao: String) {
        self.icao = icao
        _model = State(initialValue: AirportCardModel(icao: icao))
    }

    var body: some View {
        Group {
            switch model.state {
            case .loading:
                ProgressView()
            case .failed(let message):
                ContentUnavailableView {
                    Label("No weather for \(icao)", systemImage: "cloud.slash")
                } description: {
                    Text(message)
                } actions: {
                    Button("Try again") { Task { await model.load() } }
                }
            case .loaded(let metar, let airport):
                ScrollView {
                    AirportCardContent(metar: metar, airport: airport)
                        .padding()
                }
                .refreshable { await model.load() }
            }
        }
        .navigationTitle(icao)
        .navigationBarTitleDisplayMode(.inline)
        .task { await model.load() }
    }
}

// MARK: - Content

private struct AirportCardContent: View {
    let metar: Metar
    let airport: Airport?

    var body: some View {
        VStack(alignment: .leading, spacing: 28) {
            header
            conditions
            runways
            raw
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .center) {
                Text(metar.icaoId)
                    .font(.system(size: 44, weight: .bold))
                    .fontWidth(.condensed)
                Spacer()
                if let category = metar.flightCategory {
                    FlightCategoryBadge(category: category)
                }
            }
            if let name = metar.stationName {
                Text(name).foregroundStyle(.secondary)
            }
            Text("Observed \(metar.observedAt, format: .relative(presentation: .named))")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private var conditions: some View {
        VStack(spacing: 10) {
            LabeledContent("Wind", value: windText)
            LabeledContent("Visibility", value: visibilityText)
            LabeledContent("Ceiling", value: ceilingText)
            LabeledContent("Clouds", value: cloudsText)
            LabeledContent("Temp / dewpoint", value: temperatureText)
            LabeledContent("Altimeter", value: altimeterText)
            LabeledContent("Density altitude", value: densityAltitudeText)
        }
        .monospacedDigit()
    }

    private var runways: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Runways").font(.headline)
            if runwayEnds.isEmpty {
                Text("No runway data for this airport.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(runwayEnds) { end in
                    RunwayWindRow(
                        end: end,
                        wind: metar.wind,
                        isFavored: favored?.trueHeading == end.trueHeading
                    )
                }
            }
        }
    }

    private var raw: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Raw METAR").font(.headline)
            Text(metar.rawText)
                .font(.system(.callout, design: .monospaced))
                .textSelection(.enabled)
        }
    }

    // MARK: Runway ordering

    /// Most headwind first when the wind has a direction.
    private var runwayEnds: [Runway.End] {
        let ends = airport?.runways.flatMap(\.ends) ?? []
        guard !metar.wind.isCalm, case .trueDegrees(let direction) = metar.wind.direction else { return ends }
        return ends.sorted {
            WindCalc.components(windFromTrue: direction, speedKt: 1, runwayTrueHeading: $0.trueHeading).headwindKt >
            WindCalc.components(windFromTrue: direction, speedKt: 1, runwayTrueHeading: $1.trueHeading).headwindKt
        }
    }

    /// Parallel runways share a heading, so both get highlighted.
    /// Only call a runway favored when it gets a meaningful headwind.
    private var favored: Runway.End? {
        guard let best = WindCalc.favoredRunway(for: metar.wind, among: runwayEnds),
              case .trueDegrees(let direction) = metar.wind.direction,
              WindCalc.components(windFromTrue: direction, speedKt: Double(metar.wind.speedKt),
                                  runwayTrueHeading: best.trueHeading).headwindKt >= 2
        else { return nil }
        return best
    }

    // MARK: Formatting

    private var windText: String {
        let wind = metar.wind
        if wind.isCalm { return "Calm" }
        let speed = wind.gustKt.map { "\(wind.speedKt) gusting \($0) kt" } ?? "\(wind.speedKt) kt"
        switch wind.direction {
        case .trueDegrees(let degrees):
            return String(format: "%03d° true, ", degrees) + speed
        case .variable:
            return "Variable, " + speed
        }
    }

    private var visibilityText: String {
        guard let vis = metar.visibility else { return "—" }
        let miles = vis.statuteMiles.formatted(.number.precision(.fractionLength(0...2)))
        return vis.isGreaterThan ? "\(miles)+ SM" : "\(miles) SM"
    }

    private var ceilingText: String {
        guard let ceiling = metar.ceilingFeet else { return "None" }
        return "\(ceiling.formatted()) ft"
    }

    private var cloudsText: String {
        let layers = metar.clouds.compactMap { layer -> String? in
            guard let base = layer.base else { return nil }
            return "\(layer.cover) \(base.formatted())"
        }
        return layers.isEmpty ? "Clear" : layers.joined(separator: ", ")
    }

    private var temperatureText: String {
        guard let temp = metar.temperatureC, let dew = metar.dewpointC else { return "—" }
        return "\(Int(temp.rounded()))°C / \(Int(dew.rounded()))°C"
    }

    private var altimeterText: String {
        guard let inHg = metar.altimeterInHg else { return "—" }
        return String(format: "%.2f inHg", inHg)
    }

    private var densityAltitudeText: String {
        guard let elevation = airport?.elevationFeet ?? metar.elevationFeet,
              let altimeter = metar.altimeterInHg,
              let temp = metar.temperatureC else { return "—" }
        let da = DensityAltitude.compute(fieldElevationFt: elevation, altimeterInHg: altimeter, temperatureC: temp)
        let rounded = Int((da / 10).rounded()) * 10
        return "\(rounded.formatted()) ft"
    }
}

// MARK: - Flight category badge

struct FlightCategoryBadge: View {
    let category: FlightCategory

    var body: some View {
        Text(category.rawValue)
            .font(.subheadline.weight(.bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 5)
            .background(category.color, in: .capsule)
    }
}

extension FlightCategory {
    /// Standard aviation weather colors.
    var color: Color {
        switch self {
        case .vfr: .green
        case .mvfr: .blue
        case .ifr: .red
        case .lifr: Color(red: 0.8, green: 0.2, blue: 0.8)
        }
    }
}

#Preview {
    NavigationStack {
        AirportCardView(icao: "KDAB")
    }
}
