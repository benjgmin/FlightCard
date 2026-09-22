//
//  WindComponents.swift
//  FlightCard
//
//  Created by Benjamin Eccles on 9/22/26.
//


import Foundation

struct WindComponents: Equatable {
    /// Positive = headwind, negative = tailwind.
    let headwindKt: Double
    /// Positive = from the right, negative = from the left.
    let crosswindKt: Double

    var isTailwind: Bool { headwindKt < -0.5 }
    var crosswindFromRight: Bool { crosswindKt > 0 }
}

enum WindCalc {
    /// Both inputs must use the same reference. METAR wind and AWC runway
    /// alignment are both TRUE, so no magnetic conversion is needed here.
    static func components(windFromTrue: Int, speedKt: Double, runwayTrueHeading: Int) -> WindComponents {
        let angle = Double(windFromTrue - runwayTrueHeading) * .pi / 180
        return WindComponents(
            headwindKt: speedKt * cos(angle),
            crosswindKt: speedKt * sin(angle)
        )
    }

    /// Steady and gust components for one runway end. Nil when wind is variable.
    static func components(for wind: Wind, runway: Runway.End) -> (steady: WindComponents, gust: WindComponents?)? {
        guard case .trueDegrees(let direction) = wind.direction else { return nil }
        let steady = components(windFromTrue: direction, speedKt: Double(wind.speedKt), runwayTrueHeading: runway.trueHeading)
        let gust = wind.gustKt.map {
            components(windFromTrue: direction, speedKt: Double($0), runwayTrueHeading: runway.trueHeading)
        }
        return (steady, gust)
    }

    /// Runway end with the most headwind. Nil when calm or variable.
    static func favoredRunway(for wind: Wind, among ends: [Runway.End]) -> Runway.End? {
        guard !wind.isCalm, case .trueDegrees(let direction) = wind.direction else { return nil }
        return ends.max { a, b in
            components(windFromTrue: direction, speedKt: 1, runwayTrueHeading: a.trueHeading).headwindKt <
            components(windFromTrue: direction, speedKt: 1, runwayTrueHeading: b.trueHeading).headwindKt
        }
    }
}