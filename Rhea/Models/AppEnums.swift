import Foundation

enum SidebarItem: String, CaseIterable, Identifiable {
    case receipts = "Receipts"
    case settings = "Settings"
    var id: String { rawValue }
}

/// Top-of-list filter tabs. `queued` is the default state when a receipt is added.
enum ReceiptFilter: String, CaseIterable, Identifiable {
    case all       = "All"
    case queued    = "Queued"
    case processed = "Processed"
    case confirmed = "Confirmed"
    case failed    = "Failed"
    var id: String { rawValue }
}
