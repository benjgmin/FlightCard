//
//  TafTests.swift
//  FlightCard
//
//  Created by Benjamin Eccles on 9/22/26.
//


import Foundation
import Testing
@testable import FlightCard

@MainActor
struct TafTests {
    // Real KDAB TAF from the AWC API, trimmed. The last group is swapped
    // for a TEMPO thunderstorm so partial change groups get tested too.
    private let json = #"""
    [{"icaoId":"KDAB","rawTAF":"TAF KDAB 221734Z 2218/2318 07008KT P6SM VCSH SCT030 SCT050 FM222000 05006KT P6SM FEW025 FEW060 SCT250 FM230100 00000KT P6SM FEW020 SCT100 SCT200 FM231300 01006KT P6SM SCT020 SCT120 SCT250","fcsts":[
      {"timeFrom":1790100000,"timeTo":1790107200,"fcstChange":null,"probability":null,"wdir":70,"wspd":8,"wgst":null,"visib":"6+","vertVis":null,"wxString":"VCSH","clouds":[{"cover":"SCT","base":3000,"type":null},{"cover":"SCT","base":5000,"type":null}]},
      {"timeFrom":1790107200,"timeTo":1790125200,"fcstChange":"FM","probability":null,"wdir":50,"wspd":6,"wgst":null,"visib":"6+","vertVis":null,"wxString":null,"clouds":[{"cover":"FEW","base":2500,"type":null}]},
      {"timeFrom":1790125200,"timeTo":1790168400,"fcstChange":"FM","probability":null,"wdir":0,"wspd":0,"wgst":null,"visib":"6+","vertVis":null,"wxString":null,"clouds":[{"cover":"FEW","base":2000,"type":null}]},
      {"timeFrom":1790168400,"timeTo":1790186400,"fcstChange":"TEMPO","probability":null,"wdir":null,"wspd":null,"wgst":null,"visib":2,"vertVis":null,"wxString":"TSRA","clouds":[{"cover":"BKN","base":800,"type":null}]}
    ]}]
    """#

    private func decode() throws -> Taf {
        try #require(try JSONDecoder().decode([Taf].self, from: Data(json.utf8)).first)
    }

    @Test func decodesAllPeriods() throws {
        let taf = try decode()
        #expect(taf.periods.count == 4)
        #expect(taf.periods[0].change == .prevailing)
        #expect(taf.periods[1].change == .prevailing)
        #expect(taf.periods[3].change == .temporary)
    }

    @Test func calmWind() throws {
        let taf = try decode()
        #expect(taf.periods[2].wind?.isCalm == true)
    }

    @Test func tempoWithoutWindDecodes() throws {
        let taf = try decode()
        #expect(taf.periods[3].wind == nil)
        #expect(taf.flightCategory(for: taf.periods[3]) == .ifr)
    }

    @Test func categoryThresholds() {
        #expect(FlightCategory(ceilingFeet: nil, visibilitySM: 10) == .vfr)
        #expect(FlightCategory(ceilingFeet: 3000, visibilitySM: 10) == .mvfr)
        #expect(FlightCategory(ceilingFeet: 900, visibilitySM: 10) == .ifr)
        #expect(FlightCategory(ceilingFeet: 400, visibilitySM: 10) == .lifr)
        #expect(FlightCategory(ceilingFeet: nil, visibilitySM: 0.5) == .lifr)
    }
}