import SwiftUI

/// Semantic color tokens. Every color used more than once for the same *meaning* (confidence
/// tier, processing status, category, card chrome) routes through here instead of a bare
/// system color, so the mapping is defined once and both appearances (light/dark) stay in sync
/// automatically via the underlying dynamic system colors.
extension Color {

    // MARK: - Confidence tiers

    static let confidenceHigh:   Color = .green
    static let confidenceMedium: Color = .orange
    static let confidenceLow:    Color = .red

    static func confidence(for value: Double) -> Color {
        if value >= 0.85 { return .confidenceHigh }
        if value >= 0.60 { return .confidenceMedium }
        return .confidenceLow
    }

    // MARK: - Receipt status

    static func status(for status: ReceiptStatus, confirmed: Bool) -> Color {
        switch status {
        case .done:       return confirmed ? .statusConfirmed : .statusProcessed
        case .failed:     return .statusFailed
        case .inProgress: return .statusProcessing
        case .queued:     return .statusQueued
        }
    }

    static let statusQueued:     Color = .secondary
    static let statusProcessing: Color = .orange
    static let statusProcessed:  Color = .blue
    static let statusConfirmed:  Color = .green
    static let statusFailed:     Color = .red

    // MARK: - Line-item category

    static func category(for raw: String) -> Color {
        let s = raw.uppercased()
        if s.contains("PRODUCE")                          { return .green }
        if s.contains("MEAT") || s.contains("SEAFOOD")     { return .pink }
        if s.contains("LIQUOR") || s.contains("BEER") || s.contains("WINE") { return .purple }
        if s.contains("DELI")                              { return .orange }
        if s.contains("BAK")                               { return .brown }
        if s.contains("FROZEN") || s.contains("REFRIG")    { return .teal }
        if s.contains("DAIRY")                             { return .indigo }
        if s.contains("GROC")                              { return .mint }
        return .gray
    }

    // MARK: - Accents

    /// The blue accent used for the model's read-only suggestions (AI common-name badge).
    static let aiAccent: Color = .blue
    static let csvAccent: Color = .blue
    static let postgresAccent: Color = .indigo

    /// Success/error banners and destructive affordances (export status, error panes, delete).
    static let successAccent: Color = .green
    static let errorAccent: Color = .red
    static let destructiveAccent: Color = .red

    // MARK: - Card chrome

    static let cardFill:   Color = Color.primary.opacity(0.045)
    static let cardBorder: Color = Color.primary.opacity(0.08)
}
