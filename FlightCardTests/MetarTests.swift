
import Foundation
import Testing
@testable import FlightCard

@MainActor
struct MetarTests {
    private func decode(_ json: String) throws -> Metar {
        try JSONDecoder().decode(Metar.self, from: Data(json.utf8))
    }

    @Test func usesReportedCategoryWhenPresent() throws {
        let metar = try decode(#"""
        {"icaoId":"KDAB","obsTime":1790099580,"rawOb":"METAR KDAB 221753Z 05007KT 10SM SCT024 29/23 A2994",
         "visib":"10+","clouds":[{"cover":"SCT","base":2400}],"fltCat":"VFR"}
        """#)
        #expect(metar.flightCategory == .vfr)
        #expect(!metar.isFlightCategoryComputed)
    }

    @Test func computesCategoryWhenAWCLeavesItBlank() throws {
        // The KBED/KBOS case: no fltCat, so derive it. BKN008 is IFR.
        let metar = try decode(#"""
        {"icaoId":"KBED","obsTime":1790099580,"rawOb":"METAR KBED 221756Z 04011KT 4SM BR BKN008 18/17 A3038",
         "visib":4,"clouds":[{"cover":"BKN","base":800}]}
        """#)
        #expect(metar.flightCategory == .ifr)
        #expect(metar.isFlightCategoryComputed)
    }

    @Test func noCategoryWithoutVisibility() throws {
        // Guessing VFR with unknown visibility would be worse than showing nothing.
        let metar = try decode(#"""
        {"icaoId":"KXYZ","obsTime":1790099580,"rawOb":"METAR KXYZ 221756Z AUTO 04011KT A3038",
         "clouds":[]}
        """#)
        #expect(metar.flightCategory == nil)
    }

    @Test func detectsLastReport() throws {
        let metar = try decode(#"""
        {"icaoId":"KOMN","obsTime":1790099580,"rawOb":"METAR KOMN 222250Z 08010KT 7SM VCSH FEW023 29/26 A2991 RMK LAST",
         "visib":7,"clouds":[{"cover":"FEW","base":2300}],"fltCat":"VFR"}
        """#)
        #expect(metar.isLastReport)
    }

    @Test func normalReportIsNotLast() throws {
        let metar = try decode(#"""
        {"icaoId":"KDAB","obsTime":1790099580,"rawOb":"METAR KDAB 221753Z 05007KT 10SM SCT024 29/23 A2994 RMK AO2 SLP139",
         "visib":"10+","clouds":[],"fltCat":"VFR"}
        """#)
        #expect(!metar.isLastReport)
    }

    @Test func altimeterComesFromRawGroup() throws {
        // AWC's hPa value rounds; the raw A-group is exact.
        let metar = try decode(#"""
        {"icaoId":"KDAB","obsTime":1790099580,"rawOb":"METAR KDAB 221753Z 05007KT 10SM 29/23 A2994",
         "altim":1014,"visib":"10+","clouds":[]}
        """#)
        #expect(metar.altimeterInHg == 29.94)
    }
}
