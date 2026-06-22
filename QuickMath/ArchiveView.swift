import SwiftUI

/// Pro feature — searchable archive of all past questions, memory log of saved answers,
/// theme decks, and bonus questions.
struct InsightsView: View {
    @EnvironmentObject var appModel: AppModel
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss

    @State private var searchText = ""
    @State private var selectedTheme: String? = nil
    @State private var selectedTab: InsightsTab = .archive

    enum InsightsTab: String, CaseIterable, Identifiable {
        case archive = "Archive"
        case answers = "Memory Log"
        case bonus   = "Bonus"
        var id: String { rawValue }
        var icon: String {
            switch self {
            case .archive: return "calendar"
            case .answers: return "text.bubble"
            case .bonus:   return "star"
            }
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                QMBackground()
                VStack(spacing: 0) {
                    // Tab bar
                    HStack(spacing: 0) {
                        ForEach(InsightsTab.allCases) { tab in
                            Button {
                                Haptics.tap()
                                withAnimation { selectedTab = tab }
                            } label: {
                                VStack(spacing: 4) {
                                    Image(systemName: tab.icon)
                                        .font(.caption)
                                    Text(tab.rawValue)
                                        .font(.caption2.weight(.medium))
                                }
                                .foregroundStyle(selectedTab == tab ? Color.qmAccent : .secondary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                            }
                        }
                    }
                    .background(Color.qmCard)

                    Divider()

                    switch selectedTab {
                    case .archive:
                        archiveTab
                    case .answers:
                        answersTab
                    case .bonus:
                        bonusTab
                    }
                }
            }
            .navigationTitle("Sparks Pro")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    // MARK: Archive tab
    private var archiveTab: some View {
        VStack(spacing: 0) {
            // Search + filter
            VStack(spacing: 10) {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    TextField("Search questions", text: $searchText)
                }
                .padding(10)
                .background(Color.qmField, in: RoundedRectangle(cornerRadius: 12))

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        themeFilterPill(nil, label: "All")
                        themeFilterPill("deep", label: "Deep")
                        themeFilterPill("playful", label: "Playful")
                        themeFilterPill("gratitude", label: "Gratitude")
                    }
                    .padding(.horizontal, 2)
                }
            }
            .padding(.horizontal)
            .padding(.top, 12)
            .padding(.bottom, 8)

            // List
            let filtered = filteredPrompts
            if filtered.isEmpty {
                Spacer()
                Text("No questions match")
                    .foregroundStyle(.secondary)
                Spacer()
            } else {
                List(filtered, id: \.id) { prompt in
                    ArchiveRowView(prompt: prompt, isFav: appModel.isFavorite(promptID: prompt.id))
                        .environmentObject(appModel)
                        .listRowBackground(Color.qmCard)
                        .listRowSeparatorTint(Color.qmHair)
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
            }
        }
    }

    @ViewBuilder
    private func themeFilterPill(_ theme: String?, label: String) -> some View {
        let active = selectedTheme == theme
        Button {
            Haptics.tap()
            withAnimation { selectedTheme = (active ? nil : theme) }
        } label: {
            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(active ? .white : Color.qmAccent)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(active ? Color.qmAccent : Color.qmAccent.opacity(0.12), in: Capsule())
        }
    }

    private var filteredPrompts: [DailyPrompt] {
        appModel.allPrompts
            .filter { selectedTheme == nil || $0.theme == selectedTheme }
            .filter { searchText.isEmpty || $0.text.localizedCaseInsensitiveContains(searchText) }
    }

    // MARK: Answers tab
    private var answersTab: some View {
        Group {
            if appModel.savedAnswers.isEmpty {
                VStack(spacing: 16) {
                    Spacer()
                    Image(systemName: "text.bubble")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                    Text("No exchanges saved yet.")
                        .foregroundStyle(.secondary)
                    Text("Log an answer from today's question card.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
            } else {
                List {
                    ForEach(appModel.savedAnswers, id: \.id) { answer in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(answer.personLabel)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(Color.qmAccent)
                            Text(answer.response)
                                .font(.subheadline)
                            Text(answer.date, style: .date)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 4)
                        .listRowBackground(Color.qmCard)
                    }
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
            }
        }
    }

    // MARK: Bonus tab
    private var bonusTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text("3 bonus questions for today")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)

                ForEach(appModel.bonusPrompts, id: \.id) { prompt in
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text(prompt.theme.capitalized)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(Color.qmAccent)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Color.qmAccent.opacity(0.12), in: Capsule())
                            Spacer()
                        }
                        Text(prompt.text)
                            .font(.body.weight(.medium))
                            .fixedSize(horizontal: false, vertical: true)

                        Button {
                            Haptics.tap()
                            UIPasteboard.general.string = prompt.text
                        } label: {
                            Label("Copy", systemImage: "doc.on.doc")
                                .font(.caption)
                        }
                        .foregroundStyle(Color.qmAccent)
                    }
                    .qmCard()
                    .padding(.horizontal)
                }

                Spacer(minLength: 32)
            }
            .padding(.top, 16)
        }
    }
}

// MARK: - Archive Row

struct ArchiveRowView: View {
    let prompt: DailyPrompt
    let isFav: Bool
    @EnvironmentObject var appModel: AppModel

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text(prompt.text)
                    .font(.subheadline)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 6) {
                    Text(prompt.theme.capitalized)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(Color.qmAccent)
                    Text(prompt.dateKey)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            Button {
                Haptics.tap()
                appModel.toggleFavorite(promptID: prompt.id)
            } label: {
                Image(systemName: isFav ? "bookmark.fill" : "bookmark")
                    .foregroundStyle(isFav ? Color.qmAccent : .secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
    }
}
