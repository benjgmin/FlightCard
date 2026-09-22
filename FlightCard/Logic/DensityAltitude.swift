//
//  DensityAltitude.swift
//  FlightCard
//
//  Created by Benjamin Eccles on 9/22/26.
//


import Foundation

enum DensityAltitude {
    /// PA = field elevation + (29.92 - altimeter) x 1000
    static func pressureAltitude(fieldElevationFt: Double, altimeterInHg: Double) -> Double {
        fieldElevationFt + (29.92 - altimeterInHg) * 1000
    }

    /// DA ≈ PA + 120 x (OAT - ISA temp), the standard E6B approximation.
    /// ISA temp drops 2°C per 1,000 ft from 15°C at sea level.
    static func compute(fieldElevationFt: Double, altimeterInHg: Double, temperatureC: Double) -> Double {
        let pa = pressureAltitude(fieldElevationFt: fieldElevationFt, altimeterInHg: altimeterInHg)
        let isaTempC = 15 - 2 * (pa / 1000)
        return pa + 120 * (temperatureC - isaTempC)
    }
}