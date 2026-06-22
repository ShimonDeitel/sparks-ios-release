import SwiftUI

struct PaywallView: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss

    private let benefits: [(icon: String, text: String)] = [
        ("archivebox", "Full searchable archive of every past daily question by theme"),
        ("text.bubble.fill", "Save answers and exchanges to build a private memory log per person"),
        ("star.fill", "Three bonus questions a day plus pick-your-theme decks and reminder time"),
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                QMBackground()
                ScrollView {
                    VStack(spacing: 28) {
                        // Header
                        VStack(spacing: 10) {
                            Image(systemName: "bubble.left.and.bubble.right.fill")
                                .font(.system(size: 56))
                                .foregroundStyle(Color.qmAccent)
                                .padding(.top, 32)

                            Text("Sparks Pro")
                                .font(.title.weight(.bold))

                            Text("\(store.displayPrice) / month. Auto-renews until you cancel.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }

                        // Benefit rows
                        VStack(spacing: 16) {
                            ForEach(benefits, id: \.text) { benefit in
                                HStack(alignment: .top, spacing: 16) {
                                    Image(systemName: benefit.icon)
                                        .font(.title3)
                                        .foregroundStyle(Color.qmAccent)
                                        .frame(width: 28)
                                    Text(benefit.text)
                                        .font(.subheadline)
                                        .fixedSize(horizontal: false, vertical: true)
                                    Spacer()
                                }
                            }
                        }
                        .qmCard()
                        .padding(.horizontal)

                        // CTA
                        VStack(spacing: 14) {
                            Button {
                                Task {
                                    await store.purchase()
                                }
                            } label: {
                                Group {
                                    if store.purchaseInFlight {
                                        ProgressView()
                                            .tint(.white)
                                    } else {
                                        Text("Unlock Sparks Pro")
                                    }
                                }
                                .frame(maxWidth: .infinity)
                            }
                            .prominentButton()
                            .disabled(store.purchaseInFlight)

                            Button {
                                Task { await store.restore() }
                            } label: {
                                Text("Restore purchase")
                                    .frame(maxWidth: .infinity)
                            }
                            .softButton()
                        }
                        .padding(.horizontal)

                        // Disclosure
                        VStack(spacing: 10) {
                            Text("Subscription automatically renews at \(store.displayPrice)/month unless cancelled at least 24 hours before the end of the current period. Manage or cancel anytime in your Apple Account settings.")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)

                            HStack(spacing: 20) {
                                Link("Terms", destination: URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!)
                                    .font(.caption2)
                                Link("Privacy", destination: URL(string: "https://shimondeitel.github.io/sparks-site/privacy.html")!)
                                    .font(.caption2)
                            }
                            .foregroundStyle(Color.qmAccent)
                        }
                        .padding(.horizontal, 24)
                        .padding(.bottom, 32)
                    }
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") { dismiss() }
                }
            }
            .onChange(of: store.isPro) { _, newValue in
                if newValue { dismiss() }
            }
        }
    }
}
