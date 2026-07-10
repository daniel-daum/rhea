import SwiftUI

/// Capsule pill: a status dot (or spinner) + label, with optional trailing detail text.
/// Shared chrome for `ReceiptListView`'s status column.
struct StatusBadge: View {
    let label: String
    let color: Color
    var showSpinner: Bool = false
    var trailing: String? = nil

    var body: some View {
        HStack(spacing: 5) {
            if showSpinner {
                ProgressView().controlSize(.small)
            } else {
                Circle()
                    .fill(color)
                    .frame(width: 6, height: 6)
                    .shadow(color: color.opacity(0.6), radius: 2.5, x: 0, y: 0)
            }
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(color)
            if let trailing {
                Text(trailing)
                    .font(.system(size: 10, weight: .semibold).monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(color.opacity(0.1))
        .clipShape(Capsule())
    }
}
