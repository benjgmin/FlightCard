import SwiftUI

// MARK: - Loader

@MainActor
@Observable
final class AirportCardModel {
    enum State {
        case loading
        case loaded(Metar, Airport?, Taf?)
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
            // Runway data and TAFs are bonuses. The card still works without them.
            let airport = try? await AWCClient.shared.airport(for: icao)
            let taf = try? await AWCClient.shared.taf(for: icao)
            state = .loaded(metar, airport, taf)
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
    @AppStorage(Favorites.key) private var favoritesRaw = Favorites.defaultValue
    @State private var showingDiagram = false

    private var isFavorite: Bool {
        Favorites.list(favoritesRaw).contains(icao)
    }

    private var isLoaded: Bool {
        if case .loaded = model.state { return true }
        return false
    }

    private func toggleFavorite() {
        var list = Favorites.list(favoritesRaw)
        if let index = list.firstIndex(of: icao) {
            list.remove(at: index)
        } else {
            list.append(icao)
        }
        favoritesRaw = Favorites.raw(list)
    }

    init(icao: String) {
        self.icao = icao
        _model = State(initialValue: AirportCardModel(icao: icao))
    }

    var body: some View {
        ZStack {
            Theme.panel.ignoresSafeArea()
            switch model.state {
            case .loading:
                ProgressView().tint(Theme.cyan)
            case .failed(let message):
                ContentUnavailableView {
                    Label("No weather for \(icao)", systemImage: "cloud.slash")
                } description: {
                    Text(message)
                } actions: {
                    Button("Try again") { Task { await model.load() } }
                }
            case .loaded(let metar, let airport, let taf):
                ScrollView(.vertical) {
                    AirportCardContent(metar: metar, airport: airport, taf: taf)
                        // Lock the card to the screen width so nothing can scroll sideways.
                        .containerRelativeFrame(.horizontal)
                }
                .scrollBounceBehavior(.basedOnSize, axes: .horizontal)
                .refreshable { await model.load() }
            }
        }
        .navigationTitle(icao)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Theme.panel, for: .navigationBar)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                // Only offer these once we know the airport has weather.
                if isLoaded {
                    Button { showingDiagram = true } label: {
                        Image(systemName: "map")
                    }
                    .accessibilityLabel("Airport diagram")

                    Button(action: toggleFavorite) {
                        Image(systemName: isFavorite ? "star.fill" : "star")
                    }
                    .accessibilityLabel(isFavorite ? "Remove from favorites" : "Add to favorites")
                }
            }
        }
        // Full screen so panning around the chart never dismisses it.
        .fullScreenCover(isPresented: $showingDiagram) {
            AirportDiagramView(icao: icao)
        }
        .task { await model.load() }
    }
}

// MARK: - Content

private struct AirportCardContent: View {
    let metar: Metar
    let airport: Airport?
    let taf: Taf?

    @AppStorage("crosswindLimitKt") private var crosswindLimit = 15
    @AppStorage("altimeterUnit") private var altimeterUnit: AltimeterUnit = .inHg

    var body: some View {
        VStack(alignment: .leading, spacing: 36) {
            header
            windSection
            conditionsSection
            if !otherRunways.isEmpty {
                runwaysSection
            }
            if let taf {
                TafTimeline(taf: taf)
            }
            rawSection
        }
        .foregroundStyle(Theme.ink)
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 40)
    }

    // MARK: Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .center) {
                Text(metar.icaoId).font(.display(56))
                Spacer()
                if let category = metar.flightCategory {
                    FlightCategoryBadge(category: category)
                }
            }
            if let name = metar.stationName {
                Text(name)
                    .font(.subheadline)
                    .foregroundStyle(Theme.dim)
            }
            Text("Observed \(metar.observedAt, format: .relative(presentation: .named))")
                .font(.footnote)
                .foregroundStyle(Theme.dim)
            if reportAgeMinutes > 70 {
                Label("This report is \(reportAgeMinutes) minutes old. The station may be down.",
                      systemImage: "exclamationmark.triangle.fill")
                    .font(.footnote)
                    .foregroundStyle(Theme.caution)
            }
        }
    }

    /// METARs are hourly, so anything past ~70 minutes means a missed report.
    private var reportAgeMinutes: Int {
        Int(Date().timeIntervalSince(metar.observedAt) / 60)
    }

    // MARK: Wind

    private var windSection: some View {
        VStack(alignment: .leading, spacing: 22) {
            WindDial(wind: metar.wind, runwayEnds: groupedRunways, favoredHeading: favored?.trueHeading)
                .frame(maxWidth: 320)
                .frame(maxWidth: .infinity)
            favoredSummary
        }
    }

    private var favoredSummary: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let favored, let c = WindCalc.components(for: metar.wind, runway: favored) {
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Text("Runway")
                        .foregroundStyle(Theme.dim)
                    // Big parallel groups (ATL has five) get a smaller size so they fit.
                    let designators = parallelDesignators(for: favored)
                    let isLargeGroup = designators.components(separatedBy: " / ").count > 2
                    Text(designators)
                        .font(.display(isLargeGroup ? 24 : 36))
                        .lineLimit(2)
                        .minimumScaleFactor(0.8)
                    Spacer()
                    Text("Favored")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Theme.cyan)
                }
                HStack(spacing: 0) {
                    readout("Headwind", knotsText(c.steady.headwindKt, gust: c.gust?.headwindKt))
                    verticalRule
                    readout(abs(c.steady.crosswindKt) < 0.5 ? "Crosswind"
                                : (c.steady.crosswindFromRight ? "Crosswind, right" : "Crosswind, left"),
                            knotsText(c.steady.crosswindKt, gust: c.gust?.crosswindKt),
                            tint: exceedsLimit(c.steady, c.gust) ? Theme.warning : nil)
                    verticalRule
                    readout("Wind", metar.wind.shorthand, tint: Theme.cyan)
                }
                if exceedsLimit(c.steady, c.gust) {
                    Label("Crosswind is over your \(crosswindLimit) kt limit.",
                          systemImage: "exclamationmark.triangle.fill")
                        .font(.footnote)
                        .foregroundStyle(Theme.warning)
                }
            } else {
                Text(noFavoredText)
                    .font(.title2.weight(.semibold))
                Text(windText)
                    .foregroundStyle(Theme.dim)
            }
        }
    }

    private func readout(_ label: String, _ value: String, tint: Color? = nil) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(value)
                .font(.title3.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(tint ?? Theme.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(.caption)
                .foregroundStyle(Theme.dim)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var verticalRule: some View {
        Rectangle()
            .fill(Theme.hairline)
            .frame(width: 1, height: 38)
            .padding(.horizontal, 12)
    }

    private func exceedsLimit(_ steady: WindComponents, _ gust: WindComponents?) -> Bool {
        let worst = max(abs(steady.crosswindKt), abs(gust?.crosswindKt ?? 0))
        return worst.rounded() > Double(crosswindLimit)
    }

    // MARK: Conditions

    private var conditionsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionTitle(title: "Conditions")
            Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 18) {
                GridRow {
                    cell("Visibility", visibilityText)
                    cell("Ceiling", ceilingText)
                }
                GridRow {
                    cell("Temp / dewpoint", temperatureText)
                    cell("Altimeter", altimeterText)
                }
                GridRow {
                    cell("Density altitude", densityAltitudeText)
                    cell("Field elevation", elevationText)
                }
                GridRow {
                    cell("Clouds", cloudsText)
                        .gridCellColumns(2)
                }
            }
            if let note = fogNote {
                Label(note, systemImage: "cloud.fog.fill")
                    .font(.footnote)
                    .foregroundStyle(Theme.caution)
            }
        }
    }

    private func cell(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .font(.caption)
                .foregroundStyle(Theme.dim)
            Text(value)
                .font(.body.weight(.medium))
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// A tight temp/dewpoint spread in otherwise decent weather is a fog setup.
    private var fogNote: String? {
        guard let temp = metar.temperatureC, let dew = metar.dewpointC,
              metar.flightCategory == .vfr || metar.flightCategory == .mvfr else { return nil }
        let spread = Int((temp - dew).rounded())
        guard spread <= 2 else { return nil }
        return "Temp/dewpoint spread is \(spread)°C. Fog or low clouds can form quickly."
    }

    // MARK: Runways

    private var runwaysSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            SectionTitle(title: favored == nil ? "Runways" : "Other runways")
            ForEach(otherRunways) { end in
                RunwayWindRow(end: end, wind: metar.wind, crosswindLimit: crosswindLimit)
                if end.id != otherRunways.last?.id {
                    Rectangle().fill(Theme.hairline).frame(height: 1)
                }
            }
        }
    }

    /// Most headwind first when the wind has a direction. Parallels whose headings
    /// differ by a degree or two in the data (ORD's 04L/04R) get snapped to one
    /// heading so they always group together.
    private var runwayEnds: [Runway.End] {
        let ends = RunwayGrouping.snapParallels(airport?.runways.flatMap(\.ends) ?? [])
        guard !metar.wind.isCalm, case .trueDegrees(let direction) = metar.wind.direction else { return ends }
        return ends.sorted {
            WindCalc.components(windFromTrue: direction, speedKt: 1, runwayTrueHeading: $0.trueHeading).headwindKt >
            WindCalc.components(windFromTrue: direction, speedKt: 1, runwayTrueHeading: $1.trueHeading).headwindKt
        }
    }

    /// Parallels share a heading, so they get one entry: "25R / 25L".
    private var groupedRunways: [Runway.End] {
        RunwayGrouping.groupByHeading(runwayEnds)
    }

    /// The favored runway already has the summary above, so skip it here.
    private var otherRunways: [Runway.End] {
        groupedRunways.filter { $0.trueHeading != favored?.trueHeading }
    }

    /// Only call a runway favored when it gets a meaningful headwind.
    private var favored: Runway.End? {
        guard let best = WindCalc.favoredRunway(for: metar.wind, among: runwayEnds),
              case .trueDegrees(let direction) = metar.wind.direction,
              WindCalc.components(windFromTrue: direction, speedKt: Double(metar.wind.speedKt),
                                  runwayTrueHeading: best.trueHeading).headwindKt >= 2
        else { return nil }
        return best
    }

    private func parallelDesignators(for end: Runway.End) -> String {
        RunwayGrouping.designators(sharing: end.trueHeading, in: runwayEnds)
    }

    private var noFavoredText: String {
        if runwayEnds.isEmpty { return "No runway data" }
        if metar.wind.isCalm { return "Calm wind, any runway" }
        if case .variable = metar.wind.direction { return "Variable wind" }
        return "Crosswind on every runway"
    }

    // MARK: Raw

    private var rawSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionTitle(title: "Raw METAR")
            Text(metar.rawText)
                .font(.system(.footnote, design: .monospaced))
                .foregroundStyle(Theme.dim)
                .textSelection(.enabled)
        }
    }

    // MARK: Formatting

    /// Drops the gust when it rounds to the same number ("1 kt", not "1 G1 kt").
    private func knotsText(_ steady: Double, gust: Double?) -> String {
        let s = Int(abs(steady).rounded())
        guard let gust else { return "\(s) kt" }
        let g = Int(abs(gust).rounded())
        return g > s ? "\(s) G\(g) kt" : "\(s) kt"
    }

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
        return "\(Int(temp.rounded()))° / \(Int(dew.rounded()))°C"
    }

    private var altimeterText: String {
        switch altimeterUnit {
        case .inHg:
            guard let inHg = metar.altimeterInHg else { return "—" }
            return String(format: "%.2f inHg", inHg)
        case .hPa:
            guard let hPa = metar.altimeterHpa ?? metar.altimeterInHg.map({ $0 / 0.02953 }) else { return "—" }
            return "\(Int(hPa.rounded())) hPa"
        }
    }

    private var fieldElevationFeet: Double? {
        airport?.elevationFeet ?? metar.elevationFeet
    }

    private var elevationText: String {
        guard let elevation = fieldElevationFeet else { return "—" }
        return "\(Int(elevation.rounded()).formatted()) ft"
    }

    private var densityAltitudeText: String {
        guard let elevation = fieldElevationFeet,
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
    var compact = false

    var body: some View {
        Text(category.rawValue)
            .font((compact ? Font.caption : .subheadline).weight(.heavy))
            .fontWidth(.condensed)
            .foregroundStyle(.white)
            .padding(.horizontal, compact ? 8 : 12)
            .padding(.vertical, compact ? 3 : 5)
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
    .preferredColorScheme(.dark)
}
