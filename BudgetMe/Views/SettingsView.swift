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
                        Stepper(value: $reminderDaysBefore, in: 0...7) {
                            Text(reminderDaysBefore == 0
                                 ? "On the due date"
                                 : "\(reminderDaysBefore) day\(reminderDaysBefore == 1 ? "" : "s") before")
                        }
                    }
                } header: {
                    Text("Reminders")
                } footer: {
                    Text("A 9 AM notification for anything still unpaid.")
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

    private func eraseAll() {
        benefits.forEach { context.delete($0) }
        cards.forEach { context.delete($0) }
        bills.forEach { context.delete($0) }
        try? context.save()
    }
}
