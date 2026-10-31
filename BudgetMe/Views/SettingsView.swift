import SwiftUI
import SwiftData
import CloudKit

struct SettingsView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query private var cards: [CreditCard]
    @Query private var bills: [Bill]
    @Query private var benefits: [Benefit]

    @AppStorage(SettingsKey.firstPayday) private var firstPayday = 1
    @AppStorage(SettingsKey.secondPayday) private var secondPayday = 15
    @AppStorage(SettingsKey.remindersEnabled) private var remindersEnabled = false
    @AppStorage(SettingsKey.reminderDaysBefore) private var reminderDaysBefore = 2
    @AppStorage(SettingsKey.reminderMinuteOfDay) private var reminderMinuteOfDay = 540
    @AppStorage(SettingsKey.remindOnDueDate) private var remindOnDueDate = false
    @AppStorage(SettingsKey.appearance) private var appearance: AppAppearance = .automatic

    @State private var iCloudStatus: CKAccountStatus?
    @State private var isConfirmingStarter = false
    @State private var isConfirmingErase = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("First payday", selection: $firstPayday) {
                        ForEach(1...31, id: \.self) { Text($0.ordinal).tag($0) }
                    }
                    Picker("Second payday", selection: $secondPayday) {
                        ForEach(1...31, id: \.self) { Text($0.ordinal).tag($0) }
                    }
                } header: {
                    Text("Paydays")
                } footer: {
                    Text("Each payment is grouped under the latest payday on or before its due date.")
                }

                Section {
                    Toggle("Payment reminders", isOn: $remindersEnabled)
                        .onChange(of: remindersEnabled) {
                            guard remindersEnabled else { return }
                            Task {
                                let granted = await ReminderScheduler.requestAuthorization()
                                if !granted { remindersEnabled = false }
                            }
                        }
                    if remindersEnabled {
                        Stepper(value: $reminderDaysBefore, in: 0...ReminderPlan.maxDaysBefore) {
                            Text(ReminderPlan.noticeText(reminderDaysBefore))
                        }
                        DatePicker("Time", selection: reminderTime, displayedComponents: .hourAndMinute)
                        Toggle("Also remind on the due date", isOn: $remindOnDueDate)
                    }
                } header: {
                    Text("Reminders")
                } footer: {
                    Text(remindersEnabled
                         ? "Cards and bills use these unless you give them their own reminder when editing them. Nothing is sent once a payment is marked paid."
                         : "A notification for anything still unpaid.")
                }

                Section {
                    Picker("Appearance", selection: $appearance) {
                        ForEach(AppAppearance.allCases) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.segmented)
                } header: {
                    Text("Appearance")
                } footer: {
                    Text("Automatic matches your iPhone's Light or Dark setting.")
                }

                Section("iCloud") {
                    LabeledContent("Sync") {
                        switch iCloudStatus {
                        case .available:
                            Label("On", systemImage: "checkmark.icloud.fill").foregroundStyle(.green)
                        case .noAccount:
                            Label("Off", systemImage: "icloud.slash").foregroundStyle(.orange)
                        case .none:
                            ProgressView()
                        default:
                            Label("Unavailable", systemImage: "exclamationmark.icloud").foregroundStyle(.orange)
                        }
                    }
                    LabeledContent("Cards", value: "\(cards.count)")
                    LabeledContent("Credits", value: "\(benefits.count)")
                    LabeledContent("Bills", value: "\(bills.count)")
                }

                Section {
                    Button("Load Cards from My Notes") { isConfirmingStarter = true }
                    Button("Erase All Data", role: .destructive) { isConfirmingErase = true }
                } header: {
                    Text("Data")
                } footer: {
                    Text("Loads the cards, credits and due dates from your original notes.")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .task {
                // The container ID lives in Info.plist (CloudKitContainer). Leaving it empty means
                // "local only" and keeps CloudKit from being touched without the iCloud capability.
                guard let id = Bundle.main.object(forInfoDictionaryKey: "CloudKitContainer") as? String, !id.isEmpty else {
                    iCloudStatus = .noAccount
                    return
                }
                iCloudStatus = (try? await CKContainer(identifier: id).accountStatus()) ?? .couldNotDetermine
            }
            .confirmationDialog("Load cards from your notes?", isPresented: $isConfirmingStarter, titleVisibility: .visible) {
                Button("Load") { StarterData.load(into: context) }
            } message: {
                Text(cards.isEmpty ? "Adds 10 cards, 9 credits and 1 bill." : "You already have cards — this will add the starter set alongside them.")
            }
            .confirmationDialog("Erase everything?", isPresented: $isConfirmingErase, titleVisibility: .visible) {
                Button("Erase All Data", role: .destructive) { eraseAll() }
            } message: {
                Text("Deletes all cards, credits and bills. This can't be undone.")
            }
        }
    }

    /// The reminder time as a Date for the time picker, stored as minutes after midnight.
    private var reminderTime: Binding<Date> {
        Binding(
            get: {
                Calendar.current.date(bySettingHour: reminderMinuteOfDay / 60, minute: reminderMinuteOfDay % 60, second: 0, of: .now) ?? .now
            },
            set: { date in
                let parts = Calendar.current.dateComponents([.hour, .minute], from: date)
                reminderMinuteOfDay = (parts.hour ?? 9) * 60 + (parts.minute ?? 0)
            }
        )
    }

    private func eraseAll() {
        benefits.forEach { context.delete($0) }
        cards.forEach { context.delete($0) }
        bills.forEach { context.delete($0) }
        try? context.save()
    }
}
