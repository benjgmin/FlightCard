import SwiftUI

struct SearchView: View {
    @AppStorage(Favorites.key) private var favoritesRaw = Favorites.defaultValue
    @AppStorage("appearance") private var appearance: AppearanceSetting = .dark

    @State private var query = ""
    @State private var path: [String] = []
    @State private var showingSettings = false
    @State private var isSearching = false
    @State private var editMode: EditMode = .inactive

    private var favorites: [String] { Favorites.list(favoritesRaw) }

    var body: some View {
        NavigationStack(path: $path) {
            List {
                if favorites.isEmpty {
                    ContentUnavailableView(
                        "No favorites",
                        systemImage: "star",
                        description: Text("Search for an airport, then tap the star to add it here.")
                    )
                    .listRowBackground(Color.clear)
                } else {
                    Section {
                        ForEach(favorites, id: \.self) { icao in
                            NavigationLink(value: icao) {
                                FavoriteRow(icao: icao)
                            }
                            .listRowBackground(Theme.bezel)
                        }
                        .onDelete(perform: delete)
                        .onMove(perform: move)
                    } header: {
                        Text("Favorites")
                            .foregroundStyle(Theme.dim)
                    }
                }
            }
            .environment(\.editMode, $editMode)
            .scrollContentBackground(.hidden)
            .background(Theme.panel)
            .navigationTitle("FlightCard")
            .toolbarBackground(Theme.panel, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if !favorites.isEmpty {
                        Button(editMode.isEditing ? "Done" : "Edit") {
                            withAnimation { editMode = editMode.isEditing ? .inactive : .active }
                        }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                    .accessibilityLabel("Settings")
                }
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView()
            }
            .searchable(text: $query, isPresented: $isSearching, prompt: "Airport ICAO, like KDAB")
            // Search hides the nav bar (and the Done button), so leave edit mode first.
            .onChange(of: isSearching) { _, searching in
                if searching { editMode = .inactive }
            }
            // Covers tapping a favorite while the search field is open, too.
            .onChange(of: path) { _, newPath in
                if !newPath.isEmpty { isSearching = false }
            }
            .onChange(of: favoritesRaw) {
                if favorites.isEmpty { editMode = .inactive }
            }
            .textInputAutocapitalization(.characters)
            .autocorrectionDisabled()
            .onSubmit(of: .search, submit)
            .navigationDestination(for: String.self) { icao in
                AirportCardView(icao: icao)
            }
        }
        .tint(Theme.cyan)
        .preferredColorScheme(appearance.colorScheme)
    }

    private func submit() {
        let id = query.trimmingCharacters(in: .whitespaces).uppercased()
        guard !id.isEmpty else { return }
        // Close search on the way in, so Back lands on the home screen.
        isSearching = false
        query = ""
        path.append(id)
    }

    private func delete(at offsets: IndexSet) {
        var list = favorites
        list.remove(atOffsets: offsets)
        favoritesRaw = Favorites.raw(list)
    }

    private func move(from source: IndexSet, to destination: Int) {
        var list = favorites
        list.move(fromOffsets: source, toOffset: destination)
        favoritesRaw = Favorites.raw(list)
    }
}

/// Shows live category and wind so you can scan all favorites at once.
private struct FavoriteRow: View {
    let icao: String
    @State private var metar: Metar?
    @State private var failed = false

    var body: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 2) {
                Text(icao)
                    .font(.display(28))
                    .foregroundStyle(Theme.ink)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(Theme.dim)
                    .lineLimit(1)
            }
            Spacer()
            if let metar {
                VStack(alignment: .trailing, spacing: 5) {
                    if let category = metar.flightCategory {
                        FlightCategoryBadge(category: category, compact: true)
                    }
                    Text(metar.wind.shorthand)
                        .font(.caption)
                        .monospacedDigit()
                        .foregroundStyle(Theme.cyan)
                }
            } else if !failed {
                ProgressView().tint(Theme.dim)
            }
        }
        .padding(.vertical, 4)
        .task(id: icao) {
            do {
                metar = try await AWCClient.shared.metar(for: icao)
            } catch {
                failed = true
            }
        }
    }

    private var subtitle: String {
        if let name = metar?.stationName { return name }
        return failed ? "No current report" : "Loading"
    }
}

#Preview {
    SearchView()
}
