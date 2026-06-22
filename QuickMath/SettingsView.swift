import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var appModel: AppModel
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss

    @AppStorage("quickmath.theme") private var themeRaw = AppTheme.system.rawValue
    @State private var showPaywall = false
    @State private var showDeleteConfirm = false

    var body: some View {
        NavigationStack {
            ZStack {
                QMBackground()
                List {
                    // MARK: Pro
                    Section("Subscription") {
                        if store.isPro {
                            HStack {
                                Image(systemName: "checkmark.seal.fill")
                                    .foregroundStyle(Color.qmAccent)
                                Text("Sparks Pro — Active")
                                    .font(.headline)
                            }
                            Link(destination: URL(string: "https://apps.apple.com/account/subscriptions")!) {
                                Label("Manage subscription", systemImage: "arrow.up.right")
                            }
                            .foregroundStyle(Color.qmAccent)
                        } else {
                            Button {
                                showPaywall = true
                            } label: {
                                HStack {
                                    Image(systemName: "lock.open.fill")
                                        .foregroundStyle(Color.qmAccent)
                                    Text("Unlock Sparks Pro")
                                        .font(.headline)
                                        .foregroundStyle(Color.qmAccent)
                                }
                            }
                            Button {
                                Task { await store.restore() }
                            } label: {
                                Label("Restore purchase", systemImage: "arrow.clockwise")
                            }
                            .foregroundStyle(.primary)
                        }
                    }
                    .listRowBackground(Color.qmCard)

                    // MARK: Appearance
                    Section("Appearance") {
                        Picker("Theme", selection: $themeRaw) {
                            ForEach(AppTheme.allCases) { theme in
                                Text(theme.label).tag(theme.rawValue)
                            }
                        }
                        .pickerStyle(.menu)
                    }
                    .listRowBackground(Color.qmCard)

                    // MARK: Reminders
                    Section("Reminders") {
                        NavigationLink {
                            ReminderSettingsView()
                        } label: {
                            Label("Daily reminder", systemImage: "bell")
                        }
                    }
                    .listRowBackground(Color.qmCard)

                    // MARK: Legal
                    Section("Legal") {
                        Link(destination: URL(string: "https://shimondeitel.github.io/sparks-site/privacy.html")!) {
                            Label("Privacy Policy", systemImage: "hand.raised")
                        }
                        .foregroundStyle(.primary)
                        Link(destination: URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!) {
                            Label("Terms of Service", systemImage: "doc.text")
                        }
                        .foregroundStyle(.primary)
                    }
                    .listRowBackground(Color.qmCard)

                    // MARK: Data
                    Section("Data") {
                        Button(role: .destructive) {
                            showDeleteConfirm = true
                        } label: {
                            Label("Delete all data", systemImage: "trash")
                        }
                    }
                    .listRowBackground(Color.qmCard)
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(isPresented: $showPaywall) {
                PaywallView().environmentObject(store)
            }
            .confirmationDialog(
                "Delete all saved data?",
                isPresented: $showDeleteConfirm,
                titleVisibility: .visible
            ) {
                Button("Delete everything", role: .destructive) {
                    appModel.deleteAllData()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This removes all saved answers, favourites, and re-seeds the question library. This cannot be undone.")
            }
        }
    }
}

// MARK: - Reminder sub-screen

struct ReminderSettingsView: View {
    @State private var enabled = false
    @State private var time = Date(timeIntervalSinceReferenceDate: 8 * 3600) // 8 AM

    var body: some View {
        ZStack {
            QMBackground()
            Form {
                Section {
                    Toggle("Daily reminder", isOn: $enabled)
                        .onChange(of: enabled) { _, on in
                            if on {
                                Task {
                                    let ok = await Reminders.requestAuthorization()
                                    if ok { scheduleReminder() }
                                    else { enabled = false }
                                }
                            } else {
                                Reminders.cancel()
                            }
                        }

                    if enabled {
                        DatePicker("Time", selection: $time, displayedComponents: .hourAndMinute)
                            .onChange(of: time) { _, _ in scheduleReminder() }
                    }
                } footer: {
                    Text("A gentle nudge to share today's question with someone you care about.")
                }
            }
            .scrollContentBackground(.hidden)
        }
        .navigationTitle("Reminder")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func scheduleReminder() {
        let cal = Calendar.current
        let h = cal.component(.hour, from: time)
        let m = cal.component(.minute, from: time)
        Reminders.schedule(hour: h, minute: m)
    }
}
