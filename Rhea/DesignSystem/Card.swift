import SwiftUI

/// Visual weight of a `Card`'s header and chrome.
enum CardVariant {
    /// Small caption-weight header, tinted fill, no divider — dense in-form cards
    /// (`ReceiptEditForm`).
    case compact
    /// Headline header with a divider, plain background, and a subtle shadow — settings
    /// sections (`SettingsView`).
    case section
}

/// Shared card chrome: icon + title header (with optional trailing text), optional divider,
/// and rounded-rect background/border. Replaces the separate card builders that used to be
/// duplicated between `ReceiptEditForm` and `SettingsView`.
struct Card<Content: View>: View {
    let title: String
    let systemImage: String
    var variant: CardVariant = .compact
    var trailing: String? = nil
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: variant == .compact ? 10 : 14) {
            header
            if variant == .section {
                Divider()
            }
            content()
        }
        .padding(variant == .compact ? 14 : 18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(variant == .compact ? AnyShapeStyle(Color.cardFill) : AnyShapeStyle(.background))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.cardBorder, lineWidth: 0.5))
        .shadow(color: variant == .section ? .black.opacity(0.04) : .clear,
                radius: variant == .section ? 4 : 0, x: 0, y: 1)
    }

    private var header: some View {
        HStack {
            Label(title, systemImage: systemImage)
                .font(variant == .compact ? .caption.weight(.semibold) : .headline)
                .foregroundStyle(variant == .compact ? Color.secondary : Color.primary)
                .textCase(nil)
            Spacer()
            if let trailing {
                Text(trailing).font(.caption).foregroundStyle(.tertiary)
            }
        }
    }
}
