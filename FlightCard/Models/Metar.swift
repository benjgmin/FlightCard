import Foundation

/// One METAR observation from the AWC data API (`/metar?format=json`).
struct Metar: Decodable, Identifiable {
    let icaoId: String
    let stationName: String?
    let observedAt: Date
    let rawText: String
    let temperatureC: Double?
    let dewpointC: Double?
    let wind: Wind
    let visibility: Visibility?
    let altimeterHpa: Double?
    let elevationMeters: Double?
    let clouds: [CloudLayer]
    let flightCategory: FlightCategory?
    /// True when AWC left the category blank and we derived it from ceiling and visibility.
    let isFlightCategoryComputed: Bool

    var id: String { "\(icaoId)-\(observedAt.timeIntervalSince1970)" }

    /// Exact value from the raw METAR ("A2994"). Falls back to hPa for non-US stations.
    var altimeterInHg: Double? {
        if let match = rawText.firstMatch(of: #/\bA(\d{4})\b/#), let value = Double(match.1) {
            return value / 100
        }
        return altimeterHpa.map { $0 * 0.02953 }
    }

    /// "RMK ... LAST" means this is the station's last report until it reopens,
    /// so the data will go stale overnight without it being a station outage.
    var isLastReport: Bool {
        guard let remarks = rawText.range(of: " RMK ") else { return false }
        return rawText[remarks.upperBound...].contains(#/\bLAST\b/#)
    }

    /// AWC reports station elevation in meters.
    var elevationFeet: Double? { elevationMeters.map { $0 * 3.28084 } }

    var ceilingFeet: Int? { Metar.ceiling(from: clouds) }

    private enum CodingKeys: String, CodingKey {
        case icaoId, name, obsTime, rawOb, temp, dewp, wdir, wspd, wgst, visib, altim, elev, clouds, fltCat
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        icaoId = try c.decode(String.self, forKey: .icaoId)
        stationName = try c.decodeIfPresent(String.self, forKey: .name)
        observedAt = Date(timeIntervalSince1970: try c.decode(Double.self, forKey: .obsTime))
        rawText = try c.decode(String.self, forKey: .rawOb)
        temperatureC = try c.decodeIfPresent(Double.self, forKey: .temp)
        dewpointC = try c.decodeIfPresent(Double.self, forKey: .dewp)
        altimeterHpa = try c.decodeIfPresent(Double.self, forKey: .altim)
        elevationMeters = try c.decodeIfPresent(Double.self, forKey: .elev)
        clouds = try c.decodeIfPresent([CloudLayer].self, forKey: .clouds) ?? []
        let reportedCategory = try c.decodeIfPresent(String.self, forKey: .fltCat)
            .flatMap(FlightCategory.init(rawValue:))

        // wdir is a number normally, but "VRB" when variable.
        let speed = try c.decodeIfPresent(Int.self, forKey: .wspd) ?? 0
        let gust = try c.decodeIfPresent(Int.self, forKey: .wgst)
        let direction: Wind.Direction
        if let degrees = try? c.decode(Int.self, forKey: .wdir) {
            direction = .trueDegrees(degrees)
        } else {
            direction = .variable
        }
        wind = Wind(direction: direction, speedKt: speed, gustKt: gust)

        // visib is a number sometimes, a string like "10+" other times.
        if let miles = try? c.decode(Double.self, forKey: .visib) {
            visibility = Visibility(statuteMiles: miles, isGreaterThan: false)
        } else if let text = try? c.decode(String.self, forKey: .visib) {
            visibility = Visibility(parsing: text)
        } else {
            visibility = nil
        }

        // AWC sometimes leaves fltCat blank, even at big airports. Fall back to the
        // FAA definitions, but only when visibility is known: guessing VFR without
        // it would be worse than showing nothing.
        if let reportedCategory {
            flightCategory = reportedCategory
            isFlightCategoryComputed = false
        } else if let visibility {
            flightCategory = FlightCategory(ceilingFeet: Metar.ceiling(from: clouds),
                                            visibilitySM: visibility.statuteMiles)
            isFlightCategoryComputed = true
        } else {
            flightCategory = nil
            isFlightCategoryComputed = false
        }
    }

    /// Lowest broken, overcast, or obscured layer.
    static func ceiling(from clouds: [CloudLayer]) -> Int? {
        clouds
            .filter { ["BKN", "OVC", "OVX", "VV"].contains($0.cover) }
            .compactMap(\.base)
            .min()
    }
}

struct Wind: Equatable {
    enum Direction: Equatable {
        /// METAR winds are TRUE. ATIS and tower winds are MAGNETIC.
        case trueDegrees(Int)
        case variable
    }

    let direction: Direction
    let speedKt: Int
    let gustKt: Int?

    var isCalm: Bool { speedKt == 0 && gustKt == nil }
}

struct Visibility: Equatable {
    let statuteMiles: Double
    /// "10+" means better than 10 SM.
    let isGreaterThan: Bool

    init(statuteMiles: Double, isGreaterThan: Bool) {
        self.statuteMiles = statuteMiles
        self.isGreaterThan = isGreaterThan
    }

    /// Parses AWC strings like "10+", "1/2", "1 1/2".
    init?(parsing text: String) {
        let plus = text.hasSuffix("+")
        let cleaned = text.replacingOccurrences(of: "+", with: "")
            .trimmingCharacters(in: .whitespaces)
        var total = 0.0
        for part in cleaned.split(separator: " ") {
            let pieces = part.split(separator: "/")
            if pieces.count == 2, let n = Double(pieces[0]), let d = Double(pieces[1]), d != 0 {
                total += n / d
            } else if let whole = Double(part) {
                total += whole
            } else {
                return nil
            }
        }
        self.statuteMiles = total
        self.isGreaterThan = plus
    }
}

struct CloudLayer: Decodable, Equatable {
    let cover: String
    /// Feet AGL. Nil for CLR/SKC.
    let base: Int?
}

enum FlightCategory: String {
    case vfr = "VFR"
    case mvfr = "MVFR"
    case ifr = "IFR"
    case lifr = "LIFR"
}
