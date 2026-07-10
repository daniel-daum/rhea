import SwiftUI

/// Small filled dot carrying a line item's category color (see `Color.category(for:)`).
struct CategoryDot: View {
    let category: String

    var body: some View {
        Circle()
            .fill(Color.category(for: category).opacity(0.85))
            .frame(width: 6, height: 6)
    }
}
