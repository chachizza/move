import SwiftUI

enum MoveTheme {
    static let primary = Color("MovePrimary")
    static let accent = Color("MoveAccent")
    static let canvas = Color("MoveCanvas")
    static let background = Color("MoveBackground")
    static let text = Color("MoveText")
    static let muted = Color("MoveMuted")
}

extension MoveTheme {
    enum Preference: String, CaseIterable, Identifiable {
        case system
        case light
        case dark

        static let storageKey = "move.theme.preference"
        static let fallback: Preference = .system

        var id: String { rawValue }

        var displayName: String {
            switch self {
            case .system: return "Match System"
            case .light: return "Light"
            case .dark: return "Dark"
            }
        }

        var colorScheme: ColorScheme? {
            switch self {
            case .system: return nil
            case .light: return .light
            case .dark: return .dark
            }
        }
    }
}
