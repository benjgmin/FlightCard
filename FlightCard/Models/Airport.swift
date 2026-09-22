//
//  Airport.swift
//  FlightCard
//
//  Created by Benjamin Eccles on 9/22/26.
//


import Foundation

/// Airport reference data from the AWC data API (`/airport?format=json`).
struct Airport: Decodable {
    let icaoId: String
    let name: String
    let elevationMeters: Double?
    /// Raw magnetic variation, e.g. "05W".
    let magdec: String?
    let runways: [Runway]

    var elevationFeet: Double? { elevationMeters.map { $0 * 3.28084 } }

    /// Magnetic variation in degrees, east positive, west negative.
    /// magnetic = true - variation  (so 5°W: 065 true -> 070 magnetic)
    var magneticVariation: Double? {
        guard let magdec, let hemisphere = magdec.last,
              let value = Double(magdec.dropLast()) else { return nil }
        switch hemisphere {
        case "E": return value
        case "W": return -value
        default: return nil
        }
    }

    private enum CodingKeys: String, CodingKey {
        case icaoId, name, elev, magdec, runways
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        icaoId = try c.decode(String.self, forKey: .icaoId)
        name = (try c.decodeIfPresent(String.self, forKey: .name) ?? "")
            .trimmingCharacters(in: .whitespaces)
        elevationMeters = try? c.decode(Double.self, forKey: .elev)
        magdec = try? c.decode(String.self, forKey: .magdec)
        runways = (try? c.decode([Runway].self, forKey: .runways)) ?? []
    }
}

struct Runway: Decodable, Identifiable {
    /// e.g. "07L/25R"
    let id: String
    /// e.g. "10500x150"
    let dimension: String?
    let surface: String?
    /// TRUE heading of the first end listed in `id`.
    let alignment: Int?

    struct End: Identifiable {
        let designator: String
        let trueHeading: Int
        var id: String { designator }
    }

    /// Both ends with true headings. Empty for helipads or missing data.
    var ends: [End] {
        guard let alignment else { return [] }
        let names = id.split(separator: "/").map(String.init)
        guard names.count == 2 else { return [] }
        return [
            End(designator: names[0], trueHeading: alignment),
            End(designator: names[1], trueHeading: (alignment + 180) % 360),
        ]
    }

    var lengthFeet: Int? {
        dimension?.split(separator: "x").first.flatMap { Int($0) }
    }

    private enum CodingKeys: String, CodingKey {
        case id, dimension, surface, alignment
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        dimension = try? c.decode(String.self, forKey: .dimension)
        surface = try? c.decode(String.self, forKey: .surface)
        alignment = try? c.decode(Int.self, forKey: .alignment)
    }
}