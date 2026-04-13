import SwiftUI

// MARK: - Main View

struct DumpView: View {
    @Environment(ThoughtsViewModel.self) private var viewModel
    @State private var speechRecognizer = SpeechRecognizer()
    @State private var inputText = ""
    @State private var showSettings = false

    var body: some View {
        NavigationStack {
            ZStack {
                SpaceBackground()
                VStack(spacing: 0) {
                    inputSection
                    separator
                    thoughtsSection
                }
            }
            .navigationTitle("Brain Dump")
            .navigationBarTitleDisplayMode(.large)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showSettings = true } label: {
                        Image(systemName: "gear")
                            .foregroundStyle(.white.opacity(0.7))
                    }
                }
            }
            .sheet(isPresented: $showSettings) { SettingsView() }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            speechRecognizer.onAutoStop = { stopAndSaveVoice() }
        }
    }

    // MARK: - Input Section

    private var inputSection: some View {
        VStack(spacing: 14) {
            inputCard
            controlsRow
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 14)
    }

    private var inputCard: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 20)
                .fill(.white.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .strokeBorder(
                            speechRecognizer.isRecording
                                ? Color.red.opacity(0.5)
                                : Color.white.opacity(0.12),
                            lineWidth: 1
                        )
                )
                .shadow(
                    color: speechRecognizer.isRecording ? .red.opacity(0.18) : .clear,
                    radius: 14
                )
                .animation(.easeInOut(duration: 0.3), value: speechRecognizer.isRecording)

            if speechRecognizer.isRecording {
                VStack(alignment: .leading, spacing: 10) {
                    WaveformView(
                        audioLevel: speechRecognizer.audioLevel,
                        isRecording: speechRecognizer.isRecording
                    )
                    Text(
                        speechRecognizer.transcript.isEmpty
                            ? "Listening…"
                            : speechRecognizer.transcript
                    )
                    .foregroundStyle(
                        speechRecognizer.transcript.isEmpty
                            ? .white.opacity(0.35)
                            : .white
                    )
                    .font(.body)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .animation(.default, value: speechRecognizer.transcript)
                }
                .padding(16)
                .transition(.opacity.combined(with: .move(edge: .top)))
            } else {
                TextField("What's on your mind?", text: $inputText, axis: .vertical)
                    .lineLimit(3...6)
                    .foregroundStyle(.white)
                    .tint(.nebula)
                    .font(.body)
                    .padding(16)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
        .frame(minHeight: 110)
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: speechRecognizer.isRecording)
    }

    private var controlsRow: some View {
        HStack(spacing: 14) {
            MicButton(isRecording: speechRecognizer.isRecording) {
                if speechRecognizer.isRecording {
                    stopAndSaveVoice()
                } else {
                    Task { await speechRecognizer.startRecording() }
                }
            }

            if speechRecognizer.isRecording {
                GradientButton(
                    label: "Save Voice",
                    icon: "checkmark.circle.fill",
                    colors: [.green, .teal],
                    shadowColor: .green,
                    action: stopAndSaveVoice
                )
                .transition(.move(edge: .trailing).combined(with: .opacity))
            } else {
                GradientButton(
                    label: "Add Thought",
                    icon: "plus.circle.fill",
                    colors: [Color.nebula, Color(red: 0.32, green: 0.18, blue: 0.78)],
                    shadowColor: .nebula,
                    action: submitText
                )
                .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .transition(.move(edge: .leading).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: speechRecognizer.isRecording)
    }

    // MARK: - Thoughts Section

    private var separator: some View {
        Rectangle()
            .fill(.white.opacity(0.07))
            .frame(height: 1)
    }

    private var thoughtsSection: some View {
        Group {
            if viewModel.todaysThoughts.isEmpty && !viewModel.isCleaningTranscript {
                emptyState
            } else {
                ScrollView {
                    LazyVStack(spacing: 10) {
                        // Cleaning indicator card
                        if viewModel.isCleaningTranscript {
                            CleaningCard()
                                .transition(.asymmetric(
                                    insertion: .move(edge: .trailing).combined(with: .opacity),
                                    removal: .scale(scale: 0.85).combined(with: .opacity)
                                ))
                        }
                        ForEach(viewModel.todaysThoughts) { thought in
                            ThoughtCard(thought: thought) {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                    viewModel.deleteThought(thought)
                                }
                            }
                            .transition(
                                .asymmetric(
                                    insertion: .move(edge: .trailing).combined(with: .opacity),
                                    removal: .scale(scale: 0.85).combined(with: .opacity)
                                )
                            )
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
                .animation(.spring(response: 0.4, dampingFraction: 0.8), value: viewModel.todaysThoughts.count)
                .animation(.spring(response: 0.4, dampingFraction: 0.8), value: viewModel.isCleaningTranscript)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Spacer()
            Image(systemName: "brain.head.profile")
                .font(.system(size: 64))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.nebula.opacity(0.55), .cosmicBlue.opacity(0.5)],
                        startPoint: .top, endPoint: .bottom
                    )
                )
            Text("No thoughts yet")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white.opacity(0.45))
            Text("Type or speak your thoughts above")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.28))
            Spacer()
        }
    }

    // MARK: - Actions

    private func submitText() {
        let text = inputText
        withAnimation { inputText = "" }
        viewModel.addThought(text, inputType: .text)
    }

    private func stopAndSaveVoice() {
        let result = speechRecognizer.stopRecording()
        let audioFileURL = speechRecognizer.lastRecordingFileURL
        guard !result.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            if let url = audioFileURL { try? FileManager.default.removeItem(at: url) }
            return
        }
        Task {
            await viewModel.cleanAndAddVoiceThought(transcript: result, audioFileURL: audioFileURL)
        }
    }
}

// MARK: - Mic Button

struct MicButton: View {
    let isRecording: Bool
    let onTap: () -> Void

    @State private var ring1Scale: CGFloat = 1
    @State private var ring1Opacity: Double = 0
    @State private var ring2Scale: CGFloat = 1
    @State private var ring2Opacity: Double = 0
    @State private var iconBounce: CGFloat = 1

    var body: some View {
        ZStack {
            // Animated pulse rings (visible only when recording)
            Circle()
                .stroke(Color.red.opacity(ring1Opacity), lineWidth: 2)
                .frame(width: 58, height: 58)
                .scaleEffect(ring1Scale)

            Circle()
                .stroke(Color.red.opacity(ring2Opacity), lineWidth: 1.5)
                .frame(width: 58, height: 58)
                .scaleEffect(ring2Scale)

            // Core button
            Button(action: onTap) {
                ZStack {
                    Circle()
                        .fill(
                            isRecording
                                ? LinearGradient(
                                    colors: [.red, Color(red: 1, green: 0.32, blue: 0.18)],
                                    startPoint: .topLeading, endPoint: .bottomTrailing
                                )
                                : LinearGradient(
                                    colors: [Color.nebula, Color(red: 0.32, green: 0.15, blue: 0.76)],
                                    startPoint: .topLeading, endPoint: .bottomTrailing
                                )
                        )
                        .frame(width: 56, height: 56)
                        .shadow(
                            color: isRecording ? .red.opacity(0.55) : .nebula.opacity(0.45),
                            radius: isRecording ? 16 : 8,
                            y: 4
                        )

                    Image(systemName: isRecording ? "stop.fill" : "mic.fill")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(.white)
                        .scaleEffect(iconBounce)
                }
            }
            .animation(.easeInOut(duration: 0.25), value: isRecording)
        }
        .frame(width: 72, height: 56)
        .onChange(of: isRecording) { _, recording in
            // Icon bounce
            withAnimation(.spring(response: 0.2, dampingFraction: 0.45)) { iconBounce = 0.78 }
            withAnimation(.spring(response: 0.35, dampingFraction: 0.55).delay(0.12)) { iconBounce = 1.0 }

            if recording {
                startPulse()
            } else {
                stopPulse()
            }
        }
    }

    private func startPulse() {
        ring1Scale = 1; ring1Opacity = 0.65
        ring2Scale = 1; ring2Opacity = 0.40
        withAnimation(.easeOut(duration: 1.1).repeatForever(autoreverses: false)) {
            ring1Scale = 1.85; ring1Opacity = 0
        }
        withAnimation(.easeOut(duration: 1.1).repeatForever(autoreverses: false).delay(0.45)) {
            ring2Scale = 1.85; ring2Opacity = 0
        }
    }

    private func stopPulse() {
        withAnimation(.easeOut(duration: 0.25)) {
            ring1Scale = 1; ring1Opacity = 0
            ring2Scale = 1; ring2Opacity = 0
        }
    }
}

// MARK: - Gradient Button

struct GradientButton: View {
    let label: String
    let icon: String
    let colors: [Color]
    let shadowColor: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                Text(label).fontWeight(.semibold)
            }
            .font(.system(size: 16))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 13)
            .background(LinearGradient(colors: colors, startPoint: .leading, endPoint: .trailing))
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: shadowColor.opacity(0.45), radius: 10, y: 4)
        }
    }
}

// MARK: - Waveform

struct WaveformView: View {
    let audioLevel: Float
    let isRecording: Bool

    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<14, id: \.self) { i in
                WaveformBar(audioLevel: audioLevel, index: i, isRecording: isRecording)
            }
        }
        .frame(height: 32)
    }
}

struct WaveformBar: View {
    let audioLevel: Float
    let index: Int
    let isRecording: Bool

    @State private var barHeight: CGFloat = 3

    var body: some View {
        Capsule()
            .fill(
                LinearGradient(
                    colors: [Color.orange.opacity(0.75), Color.red],
                    startPoint: .bottom,
                    endPoint: .top
                )
            )
            .frame(width: 3, height: barHeight)
            .onChange(of: audioLevel) { _, level in
                guard isRecording else { return }
                let variance = CGFloat.random(in: 0.35...1.65)
                let target = max(3, CGFloat(level) * 28 * variance)
                withAnimation(.easeInOut(duration: 0.11)) { barHeight = target }
            }
            .onChange(of: isRecording) { _, active in
                if active {
                    withAnimation(
                        .easeInOut(duration: 0.25)
                        .delay(Double(index) * 0.04)
                    ) {
                        barHeight = CGFloat.random(in: 5...18)
                    }
                } else {
                    withAnimation(.easeOut(duration: 0.3)) { barHeight = 3 }
                }
            }
    }
}

// MARK: - Cleaning Card

struct CleaningCard: View {
    @State private var dots = ""
    private let timer = Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.nebula.opacity(0.15))
                    .frame(width: 40, height: 40)
                ProgressView()
                    .tint(.nebula)
                    .scaleEffect(0.8)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text("Refining voice note\(dots)")
                    .foregroundStyle(.white.opacity(0.88))
                    .font(.body)
                Text("AI is cleaning up your transcription")
                    .font(.caption2)
                    .foregroundStyle(.nebula.opacity(0.7))
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(.white.opacity(0.055))
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .strokeBorder(Color.nebula.opacity(0.3), lineWidth: 1)
                )
        )
        .onReceive(timer) { _ in
            dots = dots.count >= 3 ? "" : dots + "."
        }
    }
}

// MARK: - Thought Card

struct ThoughtCard: View {
    let thought: Thought
    let onDelete: () -> Void

    @State private var appeared = false

    private var isVoice: Bool { thought.inputType == .voice }
    private var accent: Color { isVoice ? .nebula : .auroraTeal }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Icon bubble
            ZStack {
                Circle()
                    .fill(accent.opacity(0.15))
                    .frame(width: 40, height: 40)
                Image(systemName: isVoice ? "waveform" : "text.bubble")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(accent)
            }

            VStack(alignment: .leading, spacing: 5) {
                Text(thought.content)
                    .foregroundStyle(.white.opacity(0.88))
                    .font(.body)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 6) {
                    Text(isVoice ? "Voice" : "Text")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(accent.opacity(0.9))
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2)
                        .background(accent.opacity(0.14))
                        .clipShape(Capsule())

                    Text(thought.timestamp, style: .time)
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.28))
                }
            }

            Spacer(minLength: 0)

            Button(action: onDelete) {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.white.opacity(0.35))
                    .padding(7)
                    .background(.white.opacity(0.08))
                    .clipShape(Circle())
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(.white.opacity(0.055))
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .strokeBorder(accent.opacity(0.22), lineWidth: 1)
                )
        )
        .opacity(appeared ? 1 : 0)
        .offset(x: appeared ? 0 : 22)
        .onAppear {
            withAnimation(.spring(response: 0.45, dampingFraction: 0.78)) {
                appeared = true
            }
        }
    }
}
