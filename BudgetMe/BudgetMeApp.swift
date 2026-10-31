import SwiftUI
import SwiftData

@main
struct BudgetMeApp: App {
    let container: ModelContainer = {
        let schema = Schema([CreditCard.self, Benefit.self, Bill.self])
        do {
            // `.automatic` syncs through the iCloud container in BudgetMe.entitlements.
            // If the iCloud capability is removed, the same code stores data on-device only.
            let config = ModelConfiguration(schema: schema, cloudKitDatabase: .automatic)
            return try ModelContainer(for: schema, configurations: config)
        } catch {
            print("CloudKit store unavailable (\(error)). Falling back to a local store.")
            let local = ModelConfiguration("BudgetMe-local", schema: schema, cloudKitDatabase: .none)
            do {
                return try ModelContainer(for: schema, configurations: local)
            } catch {
                fatalError("Could not create the data store: \(error)")
            }
        }
    }()

    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(container)
    }
}
