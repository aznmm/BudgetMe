import SwiftUI

/// The "Reminder" section when editing a card or bill: use the default notice from Settings, or pick its own.
struct ReminderSection: View {
    @Binding var isCustom: Bool
    @Binding var daysBefore: Int

    @AppStorage(SettingsKey.remindersEnabled) private var remindersEnabled = false
    @AppStorage(SettingsKey.reminderDaysBefore) private var defaultDaysBefore = 2

    var body: some View {
        Section {
            Toggle("Custom reminder", isOn: $isCustom.animation())
            if isCustom {
                Stepper(value: $daysBefore, in: 0...ReminderPlan.maxDaysBefore) {
                    Text(ReminderPlan.noticeText(daysBefore))
                }
            }
        } header: {
            Text("Reminder")
        } footer: {
            if !remindersEnabled {
                Text("Payment reminders are off. Turn them on in Settings.")
            } else if !isCustom {
                Text("Uses your default: \(ReminderPlan.noticeText(defaultDaysBefore).lowercased()).")
            }
        }
    }
}
