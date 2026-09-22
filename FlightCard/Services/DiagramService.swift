
import Foundation

nonisolated enum DiagramError: LocalizedError {
    case notFound(String)
    case badIndex
    case badResponse

    var errorDescription: String? {
        switch self {
        case .notFound(let id): return "The FAA doesn't publish an airport diagram for \(id). Diagrams exist for US towered and larger airports."
        case .badIndex: return "Couldn't read the FAA chart index."
        case .badResponse: return "Couldn't download the diagram from the FAA."
        }
    }
}

nonisolated struct DiagramIndex: Sendable {
    let cycle: String
    /// ICAO and FAA identifiers -> PDF file name.
    let pdfByAirport: [String: String]
}

/// Finds official FAA airport diagrams (d-TPP, chart code APD).
/// The index lists every US terminal chart for the current 28-day cycle.
@MainActor
final class DiagramService {
    static let shared = DiagramService()

    private let indexURL = URL(string: "https://nfdc.faa.gov/webContent/dtpp/current.xml")!
    private var index: DiagramIndex?
    private var loading: Task<DiagramIndex, Error>?

    func diagramURL(for icao: String) async throws -> URL {
        let index = try await loadIndex()
        let id = icao.uppercased()
        guard let pdf = index.pdfByAirport[id],
              let url = URL(string: "https://aeronav.faa.gov/d-tpp/\(index.cycle)/\(pdf)") else {
            throw DiagramError.notFound(id)
        }
        return url
    }

    private func loadIndex() async throws -> DiagramIndex {
        if let index { return index }
        if let loading { return try await loading.value }

        let url = indexURL
        // Big file, so download and parse off the main thread.
        let task = Task.detached(priority: .userInitiated) { () throws -> DiagramIndex in
            let (data, response) = try await URLSession.shared.data(from: url)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw DiagramError.badIndex }
            return try DiagramIndexParser.parse(data)
        }
        loading = task
        defer { loading = nil }
        let result = try await task.value
        index = result
        return result
    }
}

/// Streams the d-TPP XML and keeps only airport diagram (APD) records.
nonisolated final class DiagramIndexParser: NSObject, XMLParserDelegate {
    private var cycle = ""
    private var icaoIdent: String?
    private var faaIdent: String?
    private var chartCode = ""
    private var pdfName = ""
    private var userAction = ""
    private var text = ""
    private var result: [String: String] = [:]

    static func parse(_ data: Data) throws -> DiagramIndex {
        let delegate = DiagramIndexParser()
        let parser = XMLParser(data: data)
        parser.delegate = delegate
        guard parser.parse(), !delegate.cycle.isEmpty else { throw DiagramError.badIndex }
        return DiagramIndex(cycle: delegate.cycle, pdfByAirport: delegate.result)
    }

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?,
                qualifiedName qName: String?, attributes: [String: String] = [:]) {
        switch elementName {
        case "digital_tpp":
            cycle = attributes["cycle"] ?? ""
        case "airport_name":
            icaoIdent = attributes["icao_ident"].flatMap { $0.isEmpty ? nil : $0 }
            faaIdent = attributes["apt_ident"].flatMap { $0.isEmpty ? nil : $0 }
        case "record":
            chartCode = ""
            pdfName = ""
            userAction = ""
        default:
            break
        }
        text = ""
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        text += string
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?,
                qualifiedName qName: String?) {
        let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
        switch elementName {
        case "chart_code":
            chartCode = value
        case "pdf_name":
            pdfName = value
        case "useraction":
            userAction = value
        case "record":
            // "D" marks a chart deleted this cycle.
            guard chartCode == "APD", !pdfName.isEmpty, userAction != "D" else { break }
            for id in [icaoIdent, faaIdent].compactMap({ $0 }) where result[id] == nil {
                result[id] = pdfName
            }
        case "airport_name":
            icaoIdent = nil
            faaIdent = nil
        default:
            break
        }
        text = ""
    }
}
