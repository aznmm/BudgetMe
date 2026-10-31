import SwiftData

/// An in-memory store filled with the starter cards, for SwiftUI previews.
@MainActor
let previewContainer: ModelContainer = {
    let container = try! ModelContainer(
        for: CreditCard.self, Benefit.self, Bill.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    StarterData.load(into: container.mainContext)
    return container
}()
