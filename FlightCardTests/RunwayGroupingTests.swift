//
//  RunwayGroupingTests.swift
//  FlightCard
//
//  Created by Benjamin Eccles on 9/22/26.
//


import Testing
@testable import FlightCard

@MainActor
struct RunwayGroupingTests {
    private func end(_ designator: String, _ heading: Int) -> Runway.End {
        Runway.End(designator: designator, trueHeading: heading)
    }

    @Test func ordParallelsOneDegreeApartGroup() {
        // The bug: 04L/04R come back 1° apart and split into two labels.
        let ends = RunwayGrouping.snapParallels([end("04R", 44), end("04L", 43)])
        let groups = RunwayGrouping.groupByHeading(ends)
        #expect(groups.count == 1)
        #expect(groups[0].designator == "04L / 04R")
    }

    @Test func atlFiveParallelsGroupInOrder() {
        let ends = [end("10", 94), end("09R", 94), end("08L", 94), end("09L", 94), end("08R", 94)]
        let groups = RunwayGrouping.groupByHeading(RunwayGrouping.snapParallels(ends))
        #expect(groups.count == 1)
        #expect(groups[0].designator == "08L / 08R / 09L / 09R / 10")
    }

    @Test func bosRunwaysTenDegreesApartStaySeparate() {
        // 14 and 15R cross at a shallow angle but are different runways.
        let ends = [end("14", 125), end("15R", 135)]
        let groups = RunwayGrouping.groupByHeading(RunwayGrouping.snapParallels(ends))
        #expect(groups.count == 2)
    }

    @Test func centerRunwaySortsBetweenLeftAndRight() {
        let ends = [end("09R", 90), end("09C", 90), end("09L", 90)]
        #expect(RunwayGrouping.designators(sharing: 90, in: ends) == "09L / 09C / 09R")
    }

    @Test func groupsAcrossNorth() {
        // 359 and 001 are 2° apart, not 358.
        let ends = RunwayGrouping.snapParallels([end("36L", 359), end("36R", 1)])
        #expect(ends[0].trueHeading == ends[1].trueHeading)
    }

    @Test func angularDifferenceWraps() {
        #expect(RunwayGrouping.angularDifference(359, 1) == 2)
        #expect(RunwayGrouping.angularDifference(10, 350) == 20)
        #expect(RunwayGrouping.angularDifference(90, 270) == 180)
    }
}