import SwiftUI

/// Primary entry/action screen — shows today's question, a "why it matters" swipe card,
/// and the share + save-answer flow.
struct GridView: View {
    @EnvironmentObject var appModel: AppModel
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss

    @State private var cardOffset: CGFloat = 0
    @State private var showWhyCard = false
    @State private var showSaveSheet = false
    @State private var showShareSheet = false
    @State private var copied = false

    private var prompt: DailyPrompt? { appModel.todayPrompt }
    private var isFav: Bool { prompt.map { appModel.isFavorite(promptID: $0.id) } ?? false }

    var body: some View {
        ZStack {
            QMBackground()
            VStack(spacing: 0) {
                // Question / Why card area
                ZStack {
                    questionCard
                        .opacity(showWhyCard ? 0 : 1)
                        .scaleEffect(showWhyCard ? 0.94 : 1)
                        .animation(.easeInOut(duration: 0.3), value: showWhyCard)

                    whyCard
                        .opacity(showWhyCard ? 1 : 0)
                        .scaleEffect(showWhyCard ? 1 : 0.94)
                        .animation(.easeInOut(duration: 0.3), value: showWhyCard)
                }
                .padding(.horizontal)
                .padding(.top, 20)

                // Swipe hint
                Button {
                    Haptics.soft()
                    withAnimation { showWhyCard.toggle() }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: showWhyCard ? "arrow.left" : "arrow.right")
                            .font(.caption)
                        Text(showWhyCard ? "Back to question" : "Why this question?")
                            .font(.subheadline)
                    }
                    .foregroundStyle(.secondary)
                }
                .padding(.top, 20)

                Spacer()

                // Action buttons
                VStack(spacing: 14) {
                    Button {
                        Haptics.tap()
                        shareText()
                    } label: {
                        HStack {
                            Image(systemName: "square.and.arrow.up")
                            Text(copied ? "Copied!" : "Share this question")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .prominentButton()

                    HStack(spacing: 14) {
                        Button {
                            Haptics.tap()
                            if let p = prompt { appModel.toggleFavorite(promptID: p.id) }
                        } label: {
                            Label(isFav ? "Saved" : "Save", systemImage: isFav ? "bookmark.fill" : "bookmark")
                                .frame(maxWidth: .infinity)
                        }
                        .softButton()

                        Button {
                            Haptics.tap()
                            if store.isPro { showSaveSheet = true }
                            else { showSaveSheet = true } // free: still let them save one answer
                        } label: {
                            Label("Log answer", systemImage: "pencil")
                                .frame(maxWidth: .infinity)
                        }
                        .softButton()
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 32)
            }
        }
        .navigationTitle("Today")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showSaveSheet) {
            SaveAnswerSheet(prompt: prompt)
                .environmentObject(appModel)
        }
    }

    private func shareText() {
        guard let text = prompt?.text else { return }
        UIPasteboard.general.string = text
        Haptics.success()
        withAnimation { copied = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation { copied = false }
        }
    }

    // MARK: Question card
    private var questionCard: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Image(systemName: "quote.opening")
                    .font(.title2)
                    .foregroundStyle(Color.qmAccent)
                Spacer()
                if let theme = prompt?.theme {
                    Text(theme.capitalized)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.qmAccent)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.qmAccent.opacity(0.12), in: Capsule())
                }
            }

            Text(prompt?.text ?? "No question for today yet.")
                .font(.title2.weight(.medium))
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)

            Spacer()
        }
        .frame(maxWidth: .infinity, minHeight: 220)
        .qmCard()
    }

    // MARK: Why card
    private var whyCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "lightbulb")
                    .font(.title2)
                    .foregroundStyle(Color.qmAccent)
                Text("Why it matters")
                    .font(.headline.weight(.semibold))
            }

            Text(whyText(for: prompt?.theme ?? "deep"))
                .font(.body)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Spacer()
        }
        .frame(maxWidth: .infinity, minHeight: 220)
        .qmCard()
    }

    private func whyText(for theme: String) -> String {
        switch theme {
        case "playful":
            return "Laughter and lightness build real bonds. Playful questions lower defences and create shared memories — the kind that still make you smile years later."
        case "gratitude":
            return "Naming what we're grateful for — out loud, to someone we care about — compounds the feeling and deepens appreciation in both people."
        default:
            return "Research shows that asking questions with genuine curiosity is one of the fastest ways to feel close to another person. One honest question beats hours of small talk."
        }
    }
}

// MARK: - Save Answer Sheet

struct SaveAnswerSheet: View {
    let prompt: DailyPrompt?
    @EnvironmentObject var appModel: AppModel
    @Environment(\.dismiss) private var dismiss

    @State private var personLabel = ""
    @State private var response = ""

    var body: some View {
        NavigationStack {
            ZStack {
                QMBackground()
                VStack(alignment: .leading, spacing: 20) {
                    if let text = prompt?.text {
                        Text(text)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .qmCard()
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Who did you ask?")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        TextField("e.g. Mum, Partner, Jake", text: $personLabel)
                            .textFieldStyle(.roundedBorder)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Their answer (or your exchange)")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        TextEditor(text: $response)
                            .frame(minHeight: 120)
                            .padding(8)
                            .background(Color.qmField, in: RoundedRectangle(cornerRadius: 12))
                    }

                    Spacer()

                    Button {
                        guard let p = prompt, !personLabel.isEmpty, !response.isEmpty else { return }
                        appModel.saveAnswer(promptID: p.id, personLabel: personLabel, response: response)
                        Haptics.success()
                        dismiss()
                    } label: {
                        Text("Save exchange")
                            .frame(maxWidth: .infinity)
                    }
                    .prominentButton()
                    .disabled(personLabel.isEmpty || response.isEmpty)
                }
                .padding()
            }
            .navigationTitle("Log an Exchange")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}
