import SwiftUI

/// Shared spacing scale. Use these instead of ad hoc padding/spacing literals wherever the
/// value is generic whitespace rather than layout-specific math (e.g. fixed column widths).
enum Spacing {
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
    static let lg: CGFloat = 16
    static let xl: CGFloat = 20
    static let xxl: CGFloat = 24
}
