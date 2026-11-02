import SwiftUI
import FoundationModels

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(ThoughtsViewModel.self) private var viewModel

    @State private var openAITestState: TestState = .idle
    @State private var claudeTestState: TestState = .idle
    @State private var pendingClear: ClearAction = .summaries
    @State private var showClearConfirm = false
    @State private var showClearDone = false
    @State private var guideProvider: AppSettings.AIProvider?
    @FocusState private var focusedKey: AppSettings.AIProvider?

    enum ClearAction: String, Identifiable {
        case summaries, tasks, everything
        var id: String { rawValue }

        var title: String {
            switch self {
            case .summaries: return "Clear Summaries & History"
            case .tasks: return "Clear Tasks"
            case .everything: return "Clear Everything"
            }
        }

        var message: String {
            switch self {
            case .summaries: return "Deletes all thoughts, categories, daily summaries and their images. This can't be undone."
            case .tasks: return "Deletes all tasks. This can't be undone."
            case .everything: return "Deletes all thoughts, categories, summaries, images and tasks. Your AI provider and API keys are kept. This can't be undone."
            }
        }

        var doneMessage: String {
            switch self {
            case .summaries: return "All summaries, history and thoughts have been deleted."
            case .tasks: return "All tasks have been deleted."
            case .everything: return "All your data has been deleted. Your AI provider and API keys are still set."
            }
        }
    }

    enum TestState: Equatable {
        case idle, testing, success, failure(String)
    }

    var body: some View {
        @Bindable var settings = viewModel.settings
        NavigationStack {
            ScrollViewReader { proxy in
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
                    if settings.needsAPIKey {
                        Label("\(settings.selectedProvider.rawValue) is selected but needs your API key. Add it below to start using it.",
                              systemImage: "key.fill")
                            .font(.footnote)
                            .foregroundStyle(.orange)
                    } else {
                        Text("Active: \(settings.selectedProvider.rawValue)")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                if settings.selectedProvider == .appleIntelligence {
                    appleIntelligenceSection
                }

                if settings.selectedProvider == .openAI {
                    Section {
                        SecureField("Paste your OpenAI key (sk-...)", text: $settings.openAIKey)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .focused($focusedKey, equals: .openAI)
                            .listRowBackground(missingKeyHighlight(settings.openAIKey))
                        apiKeyFeedback(key: settings.openAIKey)
                        keyGuideRow(.openAI)

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
                    .id(AppSettings.AIProvider.openAI)
                }

                if settings.selectedProvider == .claude {
                    Section {
                        SecureField("Paste your Claude key (sk-ant-...)", text: $settings.claudeKey)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .focused($focusedKey, equals: .claude)
                            .listRowBackground(missingKeyHighlight(settings.claudeKey))
                        apiKeyFeedback(key: settings.claudeKey)
                        keyGuideRow(.claude)

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
                    .id(AppSettings.AIProvider.claude)
                }

                dataSection
            }
            .onChange(of: focusedKey) { _, provider in
                guard let provider else { return }
                withAnimation { proxy.scrollTo(provider, anchor: .center) }
            }
            }
            .scrollContentBackground(.hidden)
            .background(Color.spaceBg)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(Color.nebula)
                }
            }
        }
        .preferredColorScheme(.dark)
        .spaceDialog(
            isPresented: $showClearConfirm,
            icon: "trash.fill",
            tint: .red,
            title: "\(pendingClear.title)?",
            message: pendingClear.message,
            buttons: [
                SpaceDialogButton(title: pendingClear.title, role: .destructive) { performClear(pendingClear) },
                .cancel(),
            ]
        )
        .task { await focusMissingKey() }
        .sheet(item: $guideProvider, onDismiss: { Task { await focusMissingKey() } }) { provider in
            APIKeyGuideSheet(
                provider: provider,
                alreadyConsented: viewModel.settings.hasConsented(to: provider)
            ) {
                withAnimation(.snappy(duration: 0.2)) {
                    viewModel.settings.consentedProviders.insert(provider)
                    viewModel.settings.selectedProvider = provider
                }
            }
        }
        .spaceDialog(
            isPresented: $showClearDone,
            icon: "sparkles",
            tint: .auroraTeal,
            title: "All Clear",
            message: pendingClear.doneMessage,
            buttons: [SpaceDialogButton(title: "Done")]
        )
    }

    // MARK: - Data

    private var dataSection: some View {
        Section {
            ForEach([ClearAction.summaries, .tasks, .everything]) { action in
                Button(role: .destructive) {
                    pendingClear = action
                    showClearConfirm = true
                } label: {
                    Label(action.title, systemImage: action == .everything ? "trash.fill" : "trash")
                }
            }
            .disabled(viewModel.isBusy)
        } header: {
            Text("Data")
        } footer: {
            if viewModel.isBusy {
                Text("Wait for the current AI task to finish before clearing data.")
                    .font(.footnote)
            }
        }
    }

    private func performClear(_ action: ClearAction) {
        switch action {
        case .summaries: viewModel.clearSummariesAndHistory()
        case .tasks: viewModel.clearTasks()
        case .everything: viewModel.clearEverything()
        }
        showClearDone = true
    }

    // MARK: - Key Guide

    /// Points the user at the key field when the selected provider still has no key.
    private func focusMissingKey() async {
        guard viewModel.settings.needsAPIKey else { return }
        // Let sheet dismissal / row animation settle so focus and scrolling stick.
        try? await Task.sleep(for: .milliseconds(450))
        focusedKey = viewModel.settings.selectedProvider
    }

    private func missingKeyHighlight(_ key: String) -> some View {
        RoundedRectangle(cornerRadius: 10)
            .fill(key.isEmpty ? Color.orange.opacity(0.12) : Color(.secondarySystemGroupedBackground))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(key.isEmpty ? Color.orange.opacity(0.6) : .clear, lineWidth: 1)
            )
    }

    private func keyGuideRow(_ provider: AppSettings.AIProvider) -> some View {
        Button {
            guideProvider = provider
        } label: {
            Label("How to get an API key", systemImage: "questionmark.circle")
                .foregroundStyle(Color.nebula)
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
            guard settings.hasConsented(to: provider) else {
                guideProvider = provider
                return
            }
            withAnimation(.snappy(duration: 0.2)) {
                settings.selectedProvider = provider
            }
            Task { await focusMissingKey() }
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
