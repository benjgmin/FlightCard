
import Testing
@testable import FlightCard

@MainActor
struct WindCalcTests {
    @Test func directHeadwind() {
        let c = WindCalc.components(windFromTrue: 70, speedKt: 10, runwayTrueHeading: 70)
        #expect(abs(c.headwindKt - 10) < 0.01)
        #expect(abs(c.crosswindKt) < 0.01)
    }

    @Test func directCrosswindFromRight() {
        let c = WindCalc.components(windFromTrue: 160, speedKt: 10, runwayTrueHeading: 70)
        #expect(abs(c.headwindKt) < 0.01)
        #expect(abs(c.crosswindKt - 10) < 0.01)
        #expect(c.crosswindFromRight)
    }

    @Test func tailwind() {
        let c = WindCalc.components(windFromTrue: 250, speedKt: 10, runwayTrueHeading: 70)
        #expect(c.isTailwind)
    }

    @Test func wrapsAcrossNorth() {
        // Wind 010, runway heading 350: 20° off, from the right.
        let c = WindCalc.components(windFromTrue: 10, speedKt: 10, runwayTrueHeading: 350)
        #expect(abs(c.headwindKt - 9.40) < 0.01)
        #expect(abs(c.crosswindKt - 3.42) < 0.01)
    }

    @Test func kdabToday() {
        // 05007G16KT on runway 07L (065 true): mostly headwind, slight left crosswind.
        let c = WindCalc.components(windFromTrue: 50, speedKt: 7, runwayTrueHeading: 65)
        #expect(abs(c.headwindKt - 6.76) < 0.01)
        #expect(abs(c.crosswindKt - (-1.81)) < 0.01)
    }

    @Test func variableWindHasNoFavoredRunway() {
        let wind = Wind(direction: .variable, speedKt: 5, gustKt: nil)
        let ends = [Runway.End(designator: "07", trueHeading: 65)]
        #expect(WindCalc.favoredRunway(for: wind, among: ends) == nil)
    }
}

@MainActor
struct DensityAltitudeTests {
    @Test func standardDayAtSeaLevel() {
        let da = DensityAltitude.compute(fieldElevationFt: 0, altimeterInHg: 29.92, temperatureC: 15)
        #expect(abs(da) < 1)
    }

    @Test func kdabHotAfternoon() {
        // 33 ft, 29.94, 29.4°C: roughly 1,750 ft density altitude.
        let da = DensityAltitude.compute(fieldElevationFt: 33, altimeterInHg: 29.94, temperatureC: 29.4)
        #expect((1700...1800).contains(da))
    }
}
