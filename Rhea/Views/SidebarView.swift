import SwiftUI

struct SidebarView: View {
    var viewModel: ReceiptsViewModel

    private var selectionBinding: Binding<SidebarItem?> {
        Binding<SidebarItem?>(
            get: { viewModel.sidebarSelection },
            set: {
                viewModel.sidebarSelection = $0 ?? .receipts
                viewModel.selectedReceipt  = nil
            }
        )
    }

    var body: some View {
        List(selection: selectionBinding) {
            Section {
                ForEach(SidebarItem.allCases) { item in
                    Label(item.rawValue, systemImage: icon(for: item))
                        .badge(viewModel.badgeCount(for: item))
                        .tag(item)
                }
            } header: {
                Text("Library")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
                    .textCase(nil)
            }
        }
        .navigationTitle("Rhea")
        .navigationSplitViewColumnWidth(min: 170, ideal: 200)
    }

    private func icon(for item: SidebarItem) -> String {
        switch item {
        case .receipts: return "doc.richtext.fill"
        case .settings: return "gearshape"
        }
    }
}
