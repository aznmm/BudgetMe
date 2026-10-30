import SwiftUI
import SwiftData

/// All cards as a Wallet-style stack.
struct WalletView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \CreditCard.sortOrder) private var cards: [CreditCard]
    @State private var isAddingCard = false
    @State private var isShowingSettings = false

    /// How much of each stacked card peeks out above the next one.
    private let peek: CGFloat = 62

    var body: some View {
        NavigationStack {
            ScrollView {
                if cards.isEmpty {
                    ContentUnavailableView {
                        Label("No Cards", systemImage: "creditcard")
                    } description: {
                        Text("Add a card to track its due date, rewards and credits.")
                    } actions: {
                        Button("Load My Cards from Notes") {
                            withAnimation { StarterData.load(into: context) }
                        }
                        .buttonStyle(.borderedProminent)
                        Button("Add a Card") { isAddingCard = true }
                    }
                    .padding(.top, 80)
                } else {
                    VStack(spacing: 0) {
                        ForEach(Array(cards.enumerated()), id: \.element.id) { index, card in
                            let isLast = index == cards.count - 1
                            NavigationLink(value: card) {
                                CardTile(card: card, isPaid: card.isPaid(monthKey: Date.now.monthKey))
                                    // Keep the full card height even when only the top peeks out.
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .buttonStyle(CardPressStyle())
                            .frame(height: isLast ? nil : peek, alignment: .top)
                            .zIndex(Double(index))
                            .contextMenu {
                                Button(
                                    card.isPaid(monthKey: Date.now.monthKey) ? "Mark Unpaid This Month" : "Mark Paid This Month",
                                    systemImage: "checkmark.circle"
                                ) {
                                    card.setPaid(!card.isPaid(monthKey: Date.now.monthKey), monthKey: Date.now.monthKey)
                                }
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)

                    Text("\(cards.count) cards · tap a card for details")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .padding(.top, 20)
                        .padding(.bottom, 32)
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Wallet")
            .navigationDestination(for: CreditCard.self) { CardDetailView(card: $0) }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Settings", systemImage: "gearshape") { isShowingSettings = true }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("Add Card", systemImage: "plus") { isAddingCard = true }
                }
            }
            .sheet(isPresented: $isAddingCard) { CardEditView(card: nil) }
            .sheet(isPresented: $isShowingSettings) { SettingsView() }
        }
    }
}

/// A gentle lift when a card is pressed.
private struct CardPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .offset(y: configuration.isPressed ? -4 : 0)
            .animation(.spring(duration: 0.25), value: configuration.isPressed)
    }
}
