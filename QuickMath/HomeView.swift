import SwiftUI

struct HomeView: View {
    var forceScreen: String? = nil

    @EnvironmentObject var appModel: AppModel
    @EnvironmentObject var store: Store

    @State private var showSettings = false
    @State private var showPaywall = false
    @State private var showInsights = false

    var body: some View {
        ZStack {
            QMBackground()
            NavigationStack {
                ScrollView {
                    VStack(spacing: 24) {
                        // Today's question card
                        todayCard

                        // Stats row
                        HStack(spacing: 12) {
                            MetricTile(
                                value: "\(appModel.allPrompts.count)",
                                label: "Questions"
                            )
                            MetricTile(
                                value: "\(appModel.favorites.count)",
                                label: "Saved"
                            )
                            MetricTile(
                                value: "\(appModel.savedAnswers.count)",
                                label: "Exchanges"
                            )
                        }
                        .padding(.horizontal)

                        // Pro tile
                        Button {
                            Haptics.tap()
                            if store.isPro { showInsights = true }
                            else { showPaywall = true }
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(store.isPro ? "Sparks Pro" : "Unlock Sparks Pro")
                                        .font(.headline.weight(.semibold))
                                    Text(store.isPro
                                         ? "Archive, memory log & bonus questions"
                                         : "Full archive, memory log & bonus questions")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: store.isPro ? "star.fill" : "lock.fill")
                                    .foregroundStyle(Color.qmAccent)
                                    .font(.title3)
                            }
                        }
                        .qmCard()
                        .padding(.horizontal)

                        Spacer(minLength: 32)
                    }
                    .padding(.top, 8)
                }
                .navigationTitle("Sparks")
                .navigationBarTitleDisplayMode(.large)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button {
                            showSettings = true
                        } label: {
                            Image(systemName: "gearshape")
                                .foregroundStyle(Color.qmAccent)
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
                .environmentObject(appModel)
                .environmentObject(store)
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView()
                .environmentObject(store)
        }
        .sheet(isPresented: $showInsights) {
            InsightsView()
                .environmentObject(appModel)
                .environmentObject(store)
        }
        .onAppear {
            if forceScreen == "paywall" { showPaywall = true }
            if forceScreen == "insights" { showInsights = true }
        }
    }

    // MARK: Today's question card
    @ViewBuilder
    private var todayCard: some View {
        NavigationLink {
            GridView()
                .environmentObject(appModel)
                .environmentObject(store)
        } label: {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    themeTag(appModel.todayPrompt?.theme ?? "deep")
                    Spacer()
                    Text("Today")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                }

                Text(appModel.todayPrompt?.text ?? "Loading today's question…")
                    .font(.title3.weight(.medium))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)

                HStack {
                    Spacer()
                    Label("Open", systemImage: "arrow.right.circle")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Color.qmAccent)
                }
            }
        }
        .qmCard()
        .padding(.horizontal)
    }

    @ViewBuilder
    private func themeTag(_ theme: String) -> some View {
        Text(theme.capitalized)
            .font(.caption.weight(.semibold))
            .foregroundStyle(Color.qmAccent)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(Color.qmAccent.opacity(0.12), in: Capsule())
    }
}
