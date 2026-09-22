//
//  AWCClient.swift
//  FlightCard
//
//  Created by Benjamin Eccles on 9/22/26.
//


import Foundation

enum AWCError: LocalizedError {
    case invalidIdentifier(String)
    case noData(String)
    case badStatus(Int)

    var errorDescription: String? {
        switch self {
        case .invalidIdentifier(let id): return "\(id) isn't a valid airport identifier."
        case .noData(let id): return "No current report for \(id)."
        case .badStatus(let code): return "Aviation Weather Center returned HTTP \(code)."
        }
    }
}

/// Talks to https://aviationweather.gov/api/data
/// Rules: max 100 requests/min, send a custom User-Agent, 204 = valid request with no data.
@MainActor
final class AWCClient {
    static let shared = AWCClient()

    private let baseURL = URL(string: "https://aviationweather.gov/api/data")!
    private let session: URLSession
    private var cache: [URL: (fetchedAt: Date, data: Data)] = [:]

    // TODO: put your real email or repo link here.
    private let userAgent = "FlightCard/1.0 (github.com/benjgmin/FlightCard)"

    init(session: URLSession = .shared) {
        self.session = session
    }

    func metar(for icao: String) async throws -> Metar {
        let results: [Metar] = try await fetch("metar", ids: icao, maxAge: 120)
        guard let first = results.first else { throw AWCError.noData(icao.uppercased()) }
        return first
    }

    func airport(for icao: String) async throws -> Airport {
        // Reference data changes rarely, so cache it for a day.
        let results: [Airport] = try await fetch("airport", ids: icao, maxAge: 86_400)
        guard let first = results.first else { throw AWCError.noData(icao.uppercased()) }
        return first
    }

    private func fetch<T: Decodable>(_ endpoint: String, ids: String, maxAge: TimeInterval) async throws -> [T] {
        let id = ids.trimmingCharacters(in: .whitespaces).uppercased()
        guard (3...4).contains(id.count), id.allSatisfy({ $0.isLetter || $0.isNumber }) else {
            throw AWCError.invalidIdentifier(ids)
        }

        var components = URLComponents(
            url: baseURL.appendingPathComponent(endpoint),
            resolvingAgainstBaseURL: false
        )!
        components.queryItems = [
            URLQueryItem(name: "ids", value: id),
            URLQueryItem(name: "format", value: "json"),
        ]
        let url = components.url!

        if let hit = cache[url], Date().timeIntervalSince(hit.fetchedAt) < maxAge {
            return try JSONDecoder().decode([T].self, from: hit.data)
        }

        var request = URLRequest(url: url)
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw AWCError.badStatus(-1) }
        if http.statusCode == 204 { return [] }
        guard (200..<300).contains(http.statusCode) else { throw AWCError.badStatus(http.statusCode) }

        cache[url] = (Date(), data)
        return try JSONDecoder().decode([T].self, from: data)
    }
}
