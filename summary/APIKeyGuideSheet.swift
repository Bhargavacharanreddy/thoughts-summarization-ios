import SwiftUI

/// Explains how to create an API key for a cloud provider, links to its website, and asks
/// for consent before any thoughts are sent to that provider.
struct APIKeyGuideSheet: View {
    let provider: AppSettings.AIProvider
    let alreadyConsented: Bool
    let onAgree: () -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    private var guide: Guide { Guide(provider: provider) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Text("To use \(provider.rawValue), you need your own API key. It's billed to your \(guide.companyName) account, not to this app.")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.7))

                    VStack(alignment: .leading, spacing: 14) {
                        ForEach(Array(guide.steps.enumerated()), id: \.offset) { index, step in
                            HStack(alignment: .top, spacing: 12) {
                                Text("\(index + 1)")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(.white)
                                    .frame(width: 24, height: 24)
                                    .background(Circle().fill(Color.nebula.opacity(0.6)))
                                Text(step)
                                    .font(.subheadline)
                                    .foregroundStyle(.white.opacity(0.85))
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }

                    Button {
                        openURL(guide.keysURL)
                    } label: {
                        Label("Open \(guide.companyName) Website", systemImage: "safari")
                            .font(.body.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color.nebula)

                    VStack(alignment: .leading, spacing: 8) {
                        Label("Your privacy", systemImage: "lock.shield")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.85))
                        Text("When \(provider.rawValue) is selected, your thoughts, voice recordings and summaries are sent to \(guide.companyName) to be processed, under \(guide.companyName)'s privacy policy. Nothing is sent until you add a key. Your key is stored securely in this device's Keychain.")
                            .font(.footnote)
                            .foregroundStyle(.white.opacity(0.55))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(14)
                    .background(RoundedRectangle(cornerRadius: 14).fill(.white.opacity(0.06)))
                }
                .padding(20)
            }
            .background(Color.spaceBg)
            .navigationTitle("Get a \(provider.rawValue) Key")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .safeAreaInset(edge: .bottom) {
                if !alreadyConsented {
                    Button {
                        onAgree()
                        dismiss()
                    } label: {
                        Text("Agree & Use \(provider.rawValue)")
                            .font(.body.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.green)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 8)
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(alreadyConsented ? "Done" : "Not Now") { dismiss() }
                        .foregroundStyle(Color.nebula)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

private struct Guide {
    let companyName: String
    let keysURL: URL
    let steps: [String]

    init(provider: AppSettings.AIProvider) {
        switch provider {
        case .claude:
            companyName = "Anthropic"
            keysURL = URL(string: "https://console.anthropic.com/settings/keys")!
            steps = [
                "Tap \"Open Anthropic Website\" below.",
                "Sign in, or create a free account.",
                "Go to Billing and buy some credits. Keys don't work without credit.",
                "Go to API Keys and tap \"Create Key\". Copy the key (it starts with sk-ant-).",
                "Come back to this app and paste it into the Claude API Key field.",
            ]
        default:
            companyName = "OpenAI"
            keysURL = URL(string: "https://platform.openai.com/api-keys")!
            steps = [
                "Tap \"Open OpenAI Website\" below.",
                "Sign in, or create a free account.",
                "Go to Billing and add a payment method and some credit. Keys don't work without credit.",
                "Go to API Keys and tap \"Create new secret key\". Copy the key (it starts with sk-).",
                "Come back to this app and paste it into the OpenAI API Key field.",
            ]
        }
    }
}
