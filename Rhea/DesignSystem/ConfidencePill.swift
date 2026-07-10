import SwiftUI

/// Small colored capsule showing a model-confidence percentage. Color comes from the shared
/// `Color.confidence(for:)` token so the red/orange/green thresholds are defined in one place.
struct ConfidencePill: View {
    let confidence: Double

    var body: some View {
        let pct = Int((confidence * 100).rounded())
        let color = Color.confidence(for: confidence)
        Text("\(pct)%")
            .font(.system(size: 9, weight: .semibold).monospacedDigit())
            .foregroundStyle(color)
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(color.opacity(0.12))
            .clipShape(Capsule())
    }
}
