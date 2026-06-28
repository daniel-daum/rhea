import SwiftUI
import AppKit

struct SettingsView: View {
    var viewModel: ReceiptsViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                extractionSection
                postgresSection
                exportSection
                aboutSection
            }
            .padding(20)
        }
        .navigationTitle("Settings")
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Sections

    private var extractionSection: some View {
        SettingsCard(title: "AI Extraction", icon: "cpu") {
            VStack(spacing: 14) {
                ConfigField(
                    label: "LM Studio / oMLX Endpoint",
                    placeholder: "http://localhost:1234/v1/chat/completions",
                    hint: "OpenAI-compatible chat completions endpoint with vision support",
                    text: Binding(get: { viewModel.extractionEndpoint },
                                  set: { viewModel.extractionEndpoint = $0 })
                )
                ConfigField(
                    label: "Model Name",
                    placeholder: "local-model",
                    hint: "Name returned by your local server (e.g. llava-v1.6-mistral-7b)",
                    text: Binding(get: { viewModel.extractionModel },
                                  set: { viewModel.extractionModel = $0 })
                )
            }
        }
    }

    private var postgresSection: some View {
        SettingsCard(title: "PostgreSQL", icon: "server.rack") {
            VStack(spacing: 14) {
                HStack(alignment: .top, spacing: 12) {
                    ConfigField(
                        label: "Host",
                        placeholder: "localhost",
                        hint: nil,
                        text: Binding(get: { viewModel.postgresConfig.host },
                                      set: { viewModel.postgresConfig.host = $0 })
                    )
                    ConfigField(
                        label: "Port",
                        placeholder: "5432",
                        hint: nil,
                        text: Binding(
                            get: { "\(viewModel.postgresConfig.port)" },
                            set: { if let v = Int($0) { viewModel.postgresConfig.port = v } }
                        )
                    )
                    .frame(width: 90)
                }
                ConfigField(
                    label: "Database Name",
                    placeholder: "my_database",
                    hint: nil,
                    text: Binding(get: { viewModel.postgresConfig.dbname },
                                  set: { viewModel.postgresConfig.dbname = $0 })
                )
                ConfigField(
                    label: "Username",
                    placeholder: "postgres",
                    hint: nil,
                    text: Binding(get: { viewModel.postgresConfig.user },
                                  set: { viewModel.postgresConfig.user = $0 })
                )
                SecureConfigField(
                    label: "Password",
                    placeholder: "Leave blank if not required",
                    text: Binding(get: { viewModel.postgresConfig.password },
                                  set: { viewModel.postgresConfig.password = $0 })
                )

                HStack {
                    Spacer()
                    Button {
                        Task { await viewModel.testPostgresConnection() }
                    } label: {
                        Label("Test Connection", systemImage: "bolt.horizontal")
                    }
                    .buttonStyle(.bordered)
                    .disabled(viewModel.isExporting || !viewModel.postgresConfig.isConfigured)
                }

                schemaDisclosure
            }
        }
    }

    private var exportSection: some View {
        SettingsCard(title: "Export", icon: "square.and.arrow.up") {
            VStack(spacing: 16) {
                // Status banner
                if let status = viewModel.exportStatus {
                    HStack(spacing: 8) {
                        Image(systemName: status.isSuccess ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                            .foregroundStyle(status.isSuccess ? Color.green : Color.red)
                        Text(status.message)
                            .font(.callout)
                            .foregroundStyle(status.isSuccess ? Color.green : Color.red)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer()
                    }
                    .padding(12)
                    .background((status.isSuccess ? Color.green : Color.red).opacity(0.06))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder((status.isSuccess ? Color.green : Color.red).opacity(0.2), lineWidth: 0.5)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }

                // Export buttons
                HStack(spacing: 12) {
                    ExportButton(
                        label: "Export to CSV",
                        icon: "doc.text",
                        color: .blue,
                        loading: viewModel.isExporting
                    ) { Task { await viewModel.exportToCSV() } }

                    ExportButton(
                        label: "Export to Postgres",
                        icon: "server.rack",
                        color: .indigo,
                        loading: viewModel.isExporting,
                        disabled: !viewModel.postgresConfig.isConfigured
                    ) { Task { await viewModel.exportToPostgres() } }
                }

                // CSV file location
                if let url = viewModel.csvExportURL {
                    HStack(spacing: 6) {
                        Image(systemName: "doc.fill")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                        Text(url.path(percentEncoded: false))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Spacer()
                        Button("Reveal") {
                            NSWorkspace.shared.activateFileViewerSelecting([url])
                        }
                        .buttonStyle(.link)
                        .font(.caption)
                    }
                }
            }
        }
    }

    private var aboutSection: some View {
        SettingsCard(title: "About", icon: "info.circle") {
            VStack(spacing: 8) {
                InfoRow(label: "Phase",   value: "6 — Polish & Integration")
                InfoRow(label: "Build",   value: "Swift Package Manager")
                InfoRow(label: "Target",  value: "macOS 14+")
                InfoRow(label: "Model",   value: "OpenAI-compatible vision endpoint")
            }
        }
    }

    // MARK: - Schema disclosure

    @State private var showSchema = false
    @State private var schemaCopied = false

    private var schemaDisclosure: some View {
        DisclosureGroup(isExpanded: $showSchema) {
            VStack(alignment: .leading, spacing: 8) {
                ScrollView {
                    Text(postgresSchema)
                        .font(.system(size: 10, design: .monospaced))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(10)
                }
                .frame(height: 180)
                .background(Color.secondary.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.5)
                )
                .clipShape(RoundedRectangle(cornerRadius: 6))

                HStack(spacing: 10) {
                    Button {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(postgresSchema, forType: .string)
                        schemaCopied = true
                        Task { try? await Task.sleep(nanoseconds: 2_000_000_000); schemaCopied = false }
                    } label: {
                        Label(schemaCopied ? "Copied!" : "Copy DDL",
                              systemImage: schemaCopied ? "checkmark" : "doc.on.doc")
                    }
                    .buttonStyle(.link)
                    .font(.caption)
                    Text("·").foregroundStyle(.tertiary).font(.caption)
                    Text("psql -d <db> -f receipts.sql")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(.top, 8)
        } label: {
            Label("View Table Schema", systemImage: "tablecells")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
    }

    // Reuse schema defined in PostgresSQLExporter
    private var postgresSchema: String { Rhea.postgresSchema }
}

// MARK: - Reusable components

private struct SettingsCard<Content: View>: View {
    let title:   String
    let icon:    String
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label(title, systemImage: icon)
                .font(.headline)
                .foregroundStyle(.primary)

            Divider()

            content()
        }
        .padding(18)
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.04), radius: 4, x: 0, y: 1)
    }
}

private struct ConfigField: View {
    let label:       String
    let placeholder: String
    let hint:        String?
    @Binding var text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(label)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.primary)
            TextField(placeholder, text: $text)
                .textFieldStyle(.roundedBorder)
                .font(.callout)
            if let h = hint {
                Text(h)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
    }
}

private struct SecureConfigField: View {
    let label:       String
    let placeholder: String
    @Binding var text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(label)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.primary)
            SecureField(placeholder, text: $text)
                .textFieldStyle(.roundedBorder)
                .font(.callout)
        }
    }
}

private struct ExportButton: View {
    let label:    String
    let icon:     String
    let color:    Color
    var loading:  Bool    = false
    var disabled: Bool    = false
    let action:   () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if loading {
                    ProgressView().controlSize(.small).tint(color)
                } else {
                    Image(systemName: icon).foregroundStyle(color)
                }
                Text(label).font(.callout.weight(.medium))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(color.opacity(0.08))
            .overlay(
                RoundedRectangle(cornerRadius: 9)
                    .strokeBorder(color.opacity(0.3), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 9))
        }
        .buttonStyle(.plain)
        .disabled(loading || disabled)
        .opacity(disabled ? 0.45 : 1)
    }
}

private struct InfoRow: View {
    let label: String
    let value: String
    var body: some View {
        HStack {
            Text(label).foregroundStyle(.secondary).font(.callout)
            Spacer()
            Text(value).foregroundStyle(.primary).font(.callout)
        }
    }
}
