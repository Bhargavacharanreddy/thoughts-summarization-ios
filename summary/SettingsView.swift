import SwiftUI
import FoundationModels

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(ThoughtsViewModel.self) private var viewModel

    @State private var openAITestState: TestState = .idle
    @State private var claudeTestState: TestState = .idle

    enum TestState: Equatable {
        case idle, testing, success, failure(String)
    }

    var body: some View {
        @Bindable var settings = viewModel.settings
        NavigationStack {
            Form {
                Section {
                    providerRow(
                        provider: .appleIntelligence,
                        icon: "apple.logo",
                        status: appleIntelligenceStatus,
                        settings: settings
                    )
                    providerRow(
                        provider: .openAI,
                        icon: "brain.head.profile",
                        status: apiKeyStatus(key: settings.openAIKey),
                        settings: settings
                    )
                    providerRow(
                        provider: .claude,
                        icon: "sparkle",
                        status: apiKeyStatus(key: settings.claudeKey),
                        settings: settings
                    )
                } header: {
                    Text("AI Provider")
                } footer: {
                    Text("Active: \(settings.selectedProvider.rawValue)")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                if settings.selectedProvider == .appleIntelligence {
                    appleIntelligenceSection
                }

                if settings.selectedProvider == .openAI {
                    Section {
                        SecureField("sk-...", text: $settings.openAIKey)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                        apiKeyFeedback(key: settings.openAIKey)

                        // Test button
                        if !settings.openAIKey.isEmpty {
                            testRow(
                                state: openAITestState,
                                label: "Test OpenAI Connection"
                            ) {
                                openAITestState = .testing
                                let ok = await settings.testOpenAIKey()
                                openAITestState = ok ? .success : .failure("Invalid key or no quota")
                            }
                        }
                    } header: {
                        Text("OpenAI API Key")
                    } footer: {
                        testFooter(openAITestState, successNote: "Key works. GPT-4o mini, Whisper, and DALL-E 3 are available.")
                    }
                }

                if settings.selectedProvider == .claude {
                    Section {
                        SecureField("sk-ant-...", text: $settings.claudeKey)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                        apiKeyFeedback(key: settings.claudeKey)

                        if !settings.claudeKey.isEmpty {
                            testRow(
                                state: claudeTestState,
                                label: "Test Claude Connection"
                            ) {
                                claudeTestState = .testing
                                let ok = await settings.testClaudeKey()
                                claudeTestState = ok ? .success : .failure("Invalid key or insufficient permissions")
                            }
                        }
                    } header: {
                        Text("Claude API Key")
                    } footer: {
                        testFooter(claudeTestState, successNote: "Key works. Claude Haiku is available.")
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    // MARK: - Test Row

    @ViewBuilder
    private func testRow(state: TestState, label: String, action: @escaping () async -> Void) -> some View {
        Button {
            Task { await action() }
        } label: {
            HStack {
                switch state {
                case .idle:
                    Label(label, systemImage: "network")
                        .foregroundStyle(.blue)
                case .testing:
                    HStack(spacing: 8) {
                        ProgressView().scaleEffect(0.8)
                        Text("Testing…").foregroundStyle(.secondary)
                    }
                case .success:
                    Label("Connected successfully", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                case .failure(let msg):
                    Label(msg, systemImage: "xmark.circle.fill")
                        .foregroundStyle(.red)
                }
            }
        }
        .disabled(state == .testing)
    }

    @ViewBuilder
    private func testFooter(_ state: TestState, successNote: String) -> some View {
        Group {
            switch state {
            case .success:
                Text(successNote)
                    .font(.footnote)
                    .foregroundStyle(.green)
            case .failure(let msg):
                Text("⚠️ \(msg). Check that the key is correct and your account has credits.")
                    .font(.footnote)
                    .foregroundStyle(.red)
            default:
                EmptyView()
            }
        }
    }

    // MARK: - Provider status

    private enum ProviderStatus {
        case ready
        case needsKey
        case unavailable(String)
    }

    private var appleIntelligenceStatus: ProviderStatus {
        if #available(iOS 26, *) {
            switch SystemLanguageModel.default.availability {
            case .available:
                return .ready
            case .unavailable(let reason):
                return .unavailable(unavailableMessage(reason))
            }
        } else {
            return .unavailable("Requires iOS 26")
        }
    }

    private func apiKeyStatus(key: String) -> ProviderStatus {
        key.isEmpty ? .needsKey : .ready
    }

    private func providerRow(provider: AppSettings.AIProvider, icon: String, status: ProviderStatus, settings: AppSettings) -> some View {
        Button {
            withAnimation(.snappy(duration: 0.2)) {
                settings.selectedProvider = provider
            }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.title3)
                    .frame(width: 28)
                    .foregroundStyle(settings.selectedProvider == provider ? .white : .primary)

                VStack(alignment: .leading, spacing: 2) {
                    Text(provider.rawValue)
                        .font(.body.weight(.medium))
                        .foregroundStyle(settings.selectedProvider == provider ? .white : .primary)
                    statusLabel(status)
                        .font(.caption)
                }

                Spacer()

                if settings.selectedProvider == provider {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.white)
                        .font(.title3)
                }
            }
            .padding(.vertical, 4)
        }
        .listRowBackground(
            settings.selectedProvider == provider
                ? RoundedRectangle(cornerRadius: 10).fill(statusColor(status))
                : nil
        )
    }

    @ViewBuilder
    private func statusLabel(_ status: ProviderStatus) -> some View {
        switch status {
        case .ready:
            Text("Ready")
                .foregroundStyle(.green)
        case .needsKey:
            Text("API key required")
                .foregroundStyle(.orange)
        case .unavailable(let message):
            Text(message)
                .foregroundStyle(.orange)
        }
    }

    private func statusColor(_ status: ProviderStatus) -> Color {
        switch status {
        case .ready: return .green
        case .needsKey: return .orange
        case .unavailable: return .gray
        }
    }

    @ViewBuilder
    private func apiKeyFeedback(key: String) -> some View {
        if key.isEmpty {
            Label("Enter your API key to enable this provider", systemImage: "key")
                .font(.caption)
                .foregroundStyle(.orange)
        } else {
            Label("API key saved (\(key.prefix(7))…)", systemImage: "checkmark.circle.fill")
                .font(.caption)
                .foregroundStyle(.green)
        }
    }

    @ViewBuilder
    private var appleIntelligenceSection: some View {
        if #available(iOS 26, *) {
            Section("Apple Intelligence") {
                switch SystemLanguageModel.default.availability {
                case .available:
                    Label("On-device model ready", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                case .unavailable(let reason):
                    Label(unavailableMessage(reason), systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                }
            }
        } else {
            Section("Apple Intelligence") {
                Label("Requires iOS 26 or later", systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
            }
        }
    }

    @available(iOS 26, *)
    private func unavailableMessage(_ reason: SystemLanguageModel.Availability.UnavailableReason) -> String {
        switch reason {
        case .deviceNotEligible:
            return "This device doesn't support Apple Intelligence."
        case .appleIntelligenceNotEnabled:
            return "Enable Apple Intelligence in Settings > Apple Intelligence & Siri."
        default:
            return "Apple Intelligence is not available."
        }
    }
}
