<div align="center">

# 🧠 Thoughts — Brain Dump & Summarize

**Capture every thought. Let AI make sense of it.**

[![Swift](https://img.shields.io/badge/Swift-6.0-orange?style=for-the-badge&logo=swift)](https://swift.org)
[![iOS](https://img.shields.io/badge/iOS-18%2B-blue?style=for-the-badge&logo=apple)](https://developer.apple.com/ios/)
[![SwiftUI](https://img.shields.io/badge/SwiftUI-✦-purple?style=for-the-badge)](https://developer.apple.com/xcode/swiftui/)
[![SwiftData](https://img.shields.io/badge/SwiftData-✦-teal?style=for-the-badge)](https://developer.apple.com/xcode/swiftdata/)
[![License](https://img.shields.io/badge/License-MIT-green?style=for-the-badge)](LICENSE)

*A beautiful iOS app to dump raw thoughts — by voice or text — and have AI categorize, summarize, and make sense of your day.*

</div>

---

## ✨ What It Does

Ever had 50 thoughts racing through your head and no way to make sense of them? **Thoughts** lets you:

1. **Brain dump** freely — speak or type whatever's on your mind, no structure needed
2. **AI categorizes** your thoughts automatically into meaningful groups
3. **Get a daily summary** — a clean digest of everything you captured throughout the day

No friction. Just think out loud, and let AI do the rest.

---

## 📱 Features

| Feature | Description |
|---|---|
| 🎙️ **Voice Input** | Tap to speak — auto-stops after 2 seconds of silence |
| ⌨️ **Text Input** | Quick-type thoughts directly |
| 🤖 **AI Categorization** | Groups related thoughts into named categories |
| 📋 **Daily Summary** | One-tap AI digest of your entire day's thoughts |
| 🌓 **Dark UI** | Deep purple/indigo animated interface |
| 💾 **Offline Storage** | All data stored locally via SwiftData |
| ⚙️ **Multi-Provider AI** | Switch between AI providers in settings |

---

## 🤖 AI Providers

The app supports **three AI backends** — switch between them in Settings:

```
┌─────────────────────────────────────────────────────┐
│                                                     │
│   🍎  Apple Intelligence   (iOS 26+, on-device)    │
│   🟢  OpenAI GPT           (requires API key)      │
│   🟣  Anthropic Claude     (requires API key)      │
│                                                     │
└─────────────────────────────────────────────────────┘
```

Apple Intelligence runs **fully on-device** — no data leaves your phone.

---

## 🏗️ Architecture

```
Thoughts/
├── Models.swift                 # SwiftData models (Thought, ThoughtCategory, DailySummary)
├── ThoughtsViewModel.swift      # Central state & business logic
├── AppSettings.swift            # AI provider config, persisted to UserDefaults
│
├── AI Services
│   ├── AIService.swift          # Protocol + shared JSON parser
│   ├── AppleIntelligenceService.swift
│   ├── ClaudeService.swift
│   └── OpenAIService.swift
│
├── Views
│   ├── ContentView.swift        # Tab container
│   ├── DumpView.swift           # Brain dump screen (main)
│   ├── CategoriesView.swift     # AI-grouped thought categories
│   ├── CategoryDetailView.swift # Thoughts within a category
│   ├── DailySummaryView.swift   # Daily AI digest
│   └── SettingsView.swift       # Provider & API key config
│
└── SpeechRecognizer.swift       # AVFoundation + SFSpeech, silence detection
```

**Stack:** SwiftUI · SwiftData · AVFoundation · Speech framework · FoundationModels (Apple Intelligence)

---

## 🚀 Getting Started

### Prerequisites
- Xcode 16+
- iOS 18+ device or simulator
- (Optional) OpenAI or Anthropic API key

### Setup

```bash
git clone https://github.com/Bhargavacharanreddy/thoughts-summarization-ios.git
cd thoughts-summarization-ios
open summary.xcodeproj
```

Hit **Run** — no additional dependencies or package installs needed.

### Configuring AI

1. Open the app → tap **Settings** (⚙️)
2. Choose your AI provider
3. Paste your API key (OpenAI or Claude) if using a cloud provider
4. For Apple Intelligence — requires iOS 26+ with the feature enabled on device

---

## 🎨 Design

- **Dark gradient theme** — deep indigo/purple palette
- **Animated mic button** — pulsing rings while recording
- **Live waveform** — 14-bar audio visualizer reacts to your voice
- **Thought cards** — slide-in animations, color-coded by input type (voice = purple, text = cyan)
- **Glass-morphism** input card with red glow border while recording

---

## 🔒 Privacy

| Data | Where it goes |
|---|---|
| Your thoughts | Stored locally on-device (SwiftData) |
| Voice audio | Processed on-device via Apple Speech API, never stored |
| AI requests | Sent to your chosen provider only (or fully on-device with Apple Intelligence) |
| API keys | Stored in UserDefaults on your device only |

---

## 📄 License

MIT — do whatever you want with it.

---

<div align="center">

Built with SwiftUI · Powered by AI · Runs on your iPhone

</div>
