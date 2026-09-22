import SwiftUI
import Playgrounds

struct ContentView: View {
    var body: some View {
        Text("Hello, world!")
            .padding()
            .task {
                do {
                    let metar = try await AWCClient.shared.metar(for: "KDAB")
                    let airport = try await AWCClient.shared.airport(for: "KDAB")
                    print(metar.rawText, metar.wind, airport.runways.flatMap(\.ends).map(\.designator))
                } catch { print("AWC error:", error) }
            }
    }
}

#Preview {
    ContentView()
}

#Playground {
    _ = 1 + 2
}
