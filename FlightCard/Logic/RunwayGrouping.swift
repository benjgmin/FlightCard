//
//  RunwayGrouping.swift
//  FlightCard
//
//  Created by Benjamin Eccles on 9/22/26.
//


import Foundation

/// Groups parallel runways so they share one label and one row.
/// Lives outside the views so it can be tested: this is the logic that broke at ORD.
enum RunwayGrouping {
    /// Snaps ends within `tolerance` degrees to one heading. The data can list
    /// real parallels a degree apart (ORD 04L/04R), which would otherwise split them.
    static func snapParallels(_ ends: [Runway.End], tolerance: Int = 3) -> [Runway.End] {
        var clusters: [Int] = []
        return ends.map { end in
            if let match = clusters.first(where: { angularDifference($0, end.trueHeading) <= tolerance }) {
                return Runway.End(designator: end.designator, trueHeading: match)
            }
            clusters.append(end.trueHeading)
            return end
        }
    }

    /// One entry per heading, keeping input order: "04L / 04R".
    static func groupByHeading(_ ends: [Runway.End]) -> [Runway.End] {
        var seen: Set<Int> = []
        return ends.compactMap { end in
            guard seen.insert(end.trueHeading).inserted else { return nil }
            return Runway.End(designator: designators(sharing: end.trueHeading, in: ends),
                              trueHeading: end.trueHeading)
        }
    }

    /// Every designator on a heading, in L/C/R order.
    static func designators(sharing heading: Int, in ends: [Runway.End]) -> String {
        ends.filter { $0.trueHeading == heading }
            .map(\.designator)
            .sorted(by: designatorOrder)
            .joined(separator: " / ")
    }

    /// 04L before 04R, 09L/09C/09R before 10L/10C/10R.
    static func designatorOrder(_ a: String, _ b: String) -> Bool {
        func key(_ designator: String) -> (Int, Int) {
            let number = Int(designator.prefix { $0.isNumber }) ?? 0
            let side: Int = switch designator.last ?? " " {
            case "L": 0
            case "C": 1
            case "R": 2
            default: 1
            }
            return (number, side)
        }
        return key(a) < key(b)
    }

    /// Shortest way around the compass: 359 and 001 are 2 degrees apart.
    static func angularDifference(_ a: Int, _ b: Int) -> Int {
        let diff = abs(a - b) % 360
        return min(diff, 360 - diff)
    }
}