//
//  Taf.swift
//  FlightCard
//
//  Created by Benjamin Eccles on 9/22/26.
//


import Foundation

/// Terminal forecast from the AWC data API (`/taf?format=json`).
struct Taf: Decodable {
    let icaoId: String
    let rawText: String
    let periods: [TafPeriod]

    private enum CodingKeys: String, CodingKey {
        case icaoId
        case rawText = "rawTAF"
        case periods = "fcsts"
    }

    /// TEMPO/PROB groups only list what changes, so fill the gaps
    /// from the prevailing forecast in effect when they start.
    func flightCategory(for period: TafPeriod) -> FlightCategory {
        guard !period.isPrevailing,
              let base = periods.last(where: { $0.isPrevailing && $0.start <= period.start })
        else {
            return FlightCategory(ceilingFeet: period.ceilingFeet, visibilitySM: period.visibility?.statuteMiles)
        }
        let visibility = period.visibility ?? base.visibility
        let ceiling = period.hasSkyInfo ? period.ceilingFeet : base.ceilingFeet
        return FlightCategory(ceilingFeet: ceiling, visibilitySM: visibility?.statuteMiles)
    }
}

struct TafPeriod: Decodable, Identifiable {
    enum Change: Equatable {
        case prevailing          // initial group or FM
        case becoming            // BECMG
        case temporary           // TEMPO
        case probability(Int)    // PROB30 / PROB40
    }

    let id = UUID()
    let start: Date
    let end: Date
    let change: Change
    let wind: Wind?
    let visibility: Visibility?
    let clouds: [CloudLayer]
    let verticalVisibility: Int?
    let weather: String?

    var isPrevailing: Bool { change == .prevailing || change == .becoming }
    var hasSkyInfo: Bool { !clouds.isEmpty || verticalVisibility != nil }

    var ceilingFeet: Int? {
        let layers = clouds
            .filter { ["BKN", "OVC", "OVX"].contains($0.cover) }
            .compactMap(\.base)
        return (layers + [verticalVisibility].compactMap { $0 }).min()
    }

    private enum CodingKeys: String, CodingKey {
        case timeFrom, timeTo, fcstChange, probability, wdir, wspd, wgst, visib, clouds, vertVis, wxString
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        start = Date(timeIntervalSince1970: try c.decode(Double.self, forKey: .timeFrom))
        end = Date(timeIntervalSince1970: try c.decode(Double.self, forKey: .timeTo))

        switch try? c.decode(String.self, forKey: .fcstChange) {
        case "BECMG": change = .becoming
        case "TEMPO": change = .temporary
        case "PROB": change = .probability((try? c.decode(Int.self, forKey: .probability)) ?? 30)
        default: change = .prevailing
        }

        // Change groups often omit wind entirely.
        if let speed = try? c.decode(Int.self, forKey: .wspd) {
            let gust = try? c.decode(Int.self, forKey: .wgst)
            let direction: Wind.Direction = (try? c.decode(Int.self, forKey: .wdir)).map { .trueDegrees($0) } ?? .variable
            wind = Wind(direction: direction, speedKt: speed, gustKt: gust)
        } else {
            wind = nil
        }

        if let miles = try? c.decode(Double.self, forKey: .visib) {
            visibility = Visibility(statuteMiles: miles, isGreaterThan: false)
        } else if let text = try? c.decode(String.self, forKey: .visib) {
            visibility = Visibility(parsing: text)
        } else {
            visibility = nil
        }

        clouds = (try? c.decode([CloudLayer].self, forKey: .clouds)) ?? []
        verticalVisibility = try? c.decode(Int.self, forKey: .vertVis)
        weather = try? c.decode(String.self, forKey: .wxString)
    }
}

extension FlightCategory {
    /// FAA definitions. LIFR: ceiling < 500 or vis < 1. IFR: < 1,000 or < 3.
    /// MVFR: 1,000–3,000 or 3–5. VFR: above both.
    init(ceilingFeet: Int?, visibilitySM: Double?) {
        let ceiling = ceilingFeet ?? .max
        let vis = visibilitySM ?? .infinity
        if ceiling < 500 || vis < 1 {
            self = .lifr
        } else if ceiling < 1000 || vis < 3 {
            self = .ifr
        } else if ceiling <= 3000 || vis <= 5 {
            self = .mvfr
        } else {
            self = .vfr
        }
    }
}