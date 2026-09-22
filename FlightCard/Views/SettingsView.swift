
//
//  AppearanceSetting.swift
//  FlightCard
//
//  Created by Benjamin Eccles on 9/22/26.
//


import SwiftUI

// MARK: - Stored settings

enum AppearanceSetting: String, CaseIterable, Identifiable {
    case system, light, dark

    var id: String { rawValue }

    var label: String {
        switch self {
        case .system: "System"
        case .light: "Light"
        case .dark: "Dark"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}

enum AltimeterUnit: String, CaseIterable, Identifiable {
    case inHg, hPa

    var id: String { rawValue }
}

/// Favorites live in AppStorage as "KDAB,KORL,KSFB".
enum Favorites {
    static let key = "favorites"
    static let defaultValue = "KDAB,KORL,KSFB,KBED"

    static func list(_ raw: String) -> [String] {
        raw.split(separator: ",").map(String.init).filter { !$0.isEmpty }
    }

    static func raw(_ list: [String]) -> String {
        list.joined(separator: ",")
    }
}

// MARK: - Screen

struct SettingsView: View {
    @AppStorage("appearance") private var appearance: AppearanceSetting = .dark
    @AppStorage("crosswindLimitKt") private var crosswindLimit = 15
    @AppStorage("altimeterUnit") private var altimeterUnit: AltimeterUnit = .inHg
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Appearance") {
                    Picker("Theme", selection: $appearance) {
                        ForEach(AppearanceSetting.allCases) { option in
                            Text(option.label).tag(option)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section {
                    Stepper(value: $crosswindLimit, in: 5...35) {
                        LabeledContent("Max crosswind", value: "\(crosswindLimit) kt")
                    }
                } header: {
                    Text("Personal minimums")
                } footer: {
                    Text("Runways where the crosswind, including gusts, is over this number get flagged. Use your personal minimum, not just the airplane's demonstrated crosswind.")
                }

                Section("Units") {
                    Picker("Altimeter", selection: $altimeterUnit) {
                        ForEach(AltimeterUnit.allCases) { unit in
                            Text(unit.rawValue).tag(unit)
                        }
                    }
                }

                Section {
                    LabeledContent("Weather data", value: "NOAA Aviation Weather Center")
                } header: {
                    Text("About")
                } footer: {
                    Text("For situational awareness only. Not a substitute for an official weather briefing.")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .preferredColorScheme(appearance.colorScheme)
        .tint(Theme.cyan)
    }
}

#Preview {
    SettingsView()
}
