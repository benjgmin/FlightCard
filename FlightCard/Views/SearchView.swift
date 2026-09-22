
import SwiftUI

struct SearchView: View {
    @State private var query = ""
    @State private var path: [String] = []

    private let favorites = ["KDAB", "KORL", "KSFB", "KBED"]

    var body: some View {
        NavigationStack(path: $path) {
            List {
                Section("Favorites") {
                    ForEach(favorites, id: \.self) { icao in
                        NavigationLink(icao, value: icao)
                            .font(.body.weight(.medium))
                            .monospaced()
                    }
                }
            }
            .navigationTitle("FlightCard")
            .searchable(text: $query, prompt: "Airport ICAO, like KDAB")
            .textInputAutocapitalization(.characters)
            .autocorrectionDisabled()
            .onSubmit(of: .search, submit)
            .navigationDestination(for: String.self) { icao in
                AirportCardView(icao: icao)
            }
        }
    }

    private func submit() {
        let id = query.trimmingCharacters(in: .whitespaces).uppercased()
        guard !id.isEmpty else { return }
        path.append(id)
        query = ""
    }
}

#Preview {
    SearchView()
}
