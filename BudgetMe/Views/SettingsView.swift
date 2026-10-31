import SwiftUI
import SwiftData
import CloudKit
import UIKit
import UniformTypeIdentifiers

struct SettingsView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase
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
    @State private var notificationsBlocked = false
    @State private var isShowingBlockedAlert = false
    @State private var isImportingBackup = false
    @State private var pendingRestore: Backup?
    @State private var backupMessage: String?

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
                                if !granted {
                                    remindersEnabled = false
                                    isShowingBlockedAlert = true
                                }
                                notificationsBlocked = await ReminderScheduler.isBlocked()
                            }
                        }
                        .alert("Notifications Are Off", isPresented: $isShowingBlockedAlert) {
                            Button("Open iPhone Settings") { openNotificationSettings() }
                            Button("Not Now", role: .cancel) {}
                        } message: {
                            Text("BudgetMe isn't allowed to send notifications. Turn them on in Settings › Notifications › BudgetMe, then switch reminders on again.")
                        }
                    if remindersEnabled && notificationsBlocked {
                        VStack(alignment: .leading, spacing: 6) {
                            Label("Notifications are turned off for BudgetMe in iPhone Settings, so no reminders will arrive.", systemImage: "exclamationmark.triangle.fill")
                                .font(.subheadline)
                                .foregroundStyle(.orange)
                            Button("Open iPhone Settings") { openNotificationSettings() }
                                .font(.subheadline.weight(.semibold))
                        }
                        .padding(.vertical, 2)
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
                    Button("Copy Backup", systemImage: "doc.on.doc") { copyBackup() }
                    if let backupFile {
                        ShareLink(item: backupFile, preview: SharePreview("BudgetMe Backup")) {
                            Label("Save or Share Backup File", systemImage: "square.and.arrow.up")
                        }
                    }
                    Button("Restore from Copied Backup", systemImage: "doc.on.clipboard") { restoreFromClipboard() }
                    Button("Restore from File", systemImage: "folder") { isImportingBackup = true }
                } header: {
                    Text("Backup")
                } footer: {
                    Text("To move everything to another device, tap Copy Backup here, then Restore from Copied Backup there. A Mac and iPhone signed in to the same Apple ID share a clipboard. Restoring replaces everything in the app.")
                }
                .fileImporter(isPresented: $isImportingBackup, allowedContentTypes: [.json]) { result in
                    readBackupFile(result)
                }
                .confirmationDialog(
                    "Replace everything with this backup?",
                    isPresented: Binding(get: { pendingRestore != nil }, set: { if !$0 { pendingRestore = nil } }),
                    titleVisibility: .visible,
                    presenting: pendingRestore
                ) { backup in
                    Button("Replace All Data", role: .destructive) { restore(backup) }
                } message: { backup in
                    Text("The backup has \(backup.summary), saved \(backup.exportedAt.formatted(date: .abbreviated, time: .shortened)). Everything in the app now will be replaced.")
                }
                .alert(
                    "Backup",
                    isPresented: Binding(get: { backupMessage != nil }, set: { if !$0 { backupMessage = nil } })
                ) {
                    Button("OK", role: .cancel) {}
                } message: {
                    Text(backupMessage ?? "")
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
            .task { notificationsBlocked = await ReminderScheduler.isBlocked() }
            .onChange(of: scenePhase) {
                // Coming back from iPhone Settings: check again.
                guard scenePhase == .active else { return }
                Task { notificationsBlocked = await ReminderScheduler.isBlocked() }
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

    private var backupFile: BackupFile? {
        (try? Backup(cards: cards, bills: bills, credits: benefits).encoded()).map { BackupFile(data: $0) }
    }

    private func copyBackup() {
        guard let data = try? Backup(cards: cards, bills: bills, credits: benefits).encoded(),
              let text = String(data: data, encoding: .utf8)
        else {
            backupMessage = "Couldn't make a backup."
            return
        }
        UIPasteboard.general.string = text
        backupMessage = "Backup copied. On your other device, open Settings and tap Restore from Copied Backup."
    }

    private func restoreFromClipboard() {
        guard let text = UIPasteboard.general.string, let data = text.data(using: .utf8) else {
            backupMessage = "There's nothing on the clipboard. Tap Copy Backup on the other device first."
            return
        }
        do {
            pendingRestore = try Backup.decode(data)
        } catch {
            backupMessage = "The clipboard doesn't hold a BudgetMe backup. Tap Copy Backup on the other device first."
        }
    }

    private func readBackupFile(_ result: Result<URL, Error>) {
        guard case .success(let url) = result else {
            backupMessage = "Couldn't open that file."
            return
        }
        // Files picked from outside the app need permission to be read.
        let isAccessing = url.startAccessingSecurityScopedResource()
        defer { if isAccessing { url.stopAccessingSecurityScopedResource() } }
        do {
            pendingRestore = try Backup.decode(Data(contentsOf: url))
        } catch {
            backupMessage = error.localizedDescription
        }
    }

    private func restore(_ backup: Backup) {
        do {
            try backup.restore(into: context)
            backupMessage = "Restored \(backup.summary)."
        } catch {
            backupMessage = "Couldn't restore the backup: \(error.localizedDescription)"
        }
    }

    private func openNotificationSettings() {
        if let url = URL(string: UIApplication.openNotificationSettingsURLString) {
            openURL(url)
        }
    }

    private func eraseAll() {
        benefits.forEach { context.delete($0) }
        cards.forEach { context.delete($0) }
        bills.forEach { context.delete($0) }
        try? context.save()
    }
}
