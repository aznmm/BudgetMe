import SwiftUI
import SwiftData

struct RootView: View {
    @Query private var cards: [CreditCard]
    @Query private var bills: [Bill]
    @AppStorage(SettingsKey.remindersEnabled) private var remindersEnabled = false
    @AppStorage(SettingsKey.reminderDaysBefore) private var reminderDaysBefore = 2
    @AppStorage(SettingsKey.reminderMinuteOfDay) private var reminderMinuteOfDay = 540
    @AppStorage(SettingsKey.remindOnDueDate) private var remindOnDueDate = false
    @AppStorage(SettingsKey.appearance) private var appearance: AppAppearance = .automatic
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        TabView {
            DueView()
                .tabItem { Label("Due", systemImage: "calendar.badge.clock") }
            CreditsView()
                .tabItem { Label("Credits", systemImage: "gift") }
            BestCardView()
                .tabItem { Label("Best Card", systemImage: "sparkles") }
            WalletView()
                .tabItem { Label("Wallet", systemImage: "wallet.pass") }
        }
        .task { rescheduleReminders() }
        .onChange(of: reminderSignature) { rescheduleReminders() }
        .onChange(of: appearance, initial: true) { appearance.apply() }
        .onChange(of: scenePhase) {
            if scenePhase == .active {
                rescheduleReminders()
                appearance.apply()
            }
        }
    }

    private var payments: [ReminderPlan.Payment] {
        cards.map {
            ReminderPlan.Payment(id: "card-\($0.name)-\($0.dueDay)", name: $0.name, dueDay: $0.dueDay, paidPeriods: $0.paidPeriods, daysBefore: $0.reminderDaysBefore)
        } + bills.map {
            ReminderPlan.Payment(id: "bill-\($0.name)-\($0.dueDay)", name: $0.name, dueDay: $0.dueDay, paidPeriods: $0.paidPeriods, daysBefore: $0.reminderDaysBefore)
        }
    }

    private var options: ReminderPlan.Options {
        ReminderPlan.Options(daysBefore: reminderDaysBefore, minuteOfDay: reminderMinuteOfDay, alsoOnDueDate: remindOnDueDate)
    }

    /// Changes whenever anything that affects reminders changes.
    private var reminderSignature: String {
        let state = payments
            .map { "\($0.id):\($0.daysBefore ?? -1):\($0.paidPeriods.sorted().joined(separator: ","))" }
            .sorted()
            .joined(separator: "|")
        return "\(remindersEnabled)-\(reminderDaysBefore)-\(reminderMinuteOfDay)-\(remindOnDueDate)-\(state)"
    }

    private func rescheduleReminders() {
        ReminderScheduler.reschedule(payments, enabled: remindersEnabled, options: options)
    }
}

#Preview {
    RootView()
        .modelContainer(previewContainer)
}
