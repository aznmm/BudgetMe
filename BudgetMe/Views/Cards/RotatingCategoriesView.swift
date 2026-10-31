import SwiftUI
import SwiftData

/// Pick this quarter's rotating 5× categories for a card like Chase Freedom Flex or Discover it.
struct RotatingCategoriesView: View {
    @Environment(\.dismiss) private var dismiss
    @Query private var allCards: [CreditCard]

    let card: CreditCard

    @State private var selected: Set<CategoryChoice> = []
    @State private var addedNames: [String] = []
    @State private var newName = ""
    @State private var multiplier = 5.0
    @State private var hasCap = true
    @State private var cap = 1500.0
    @State private var isActivated = false
    @State private var didLoad = false

    private var quarterLabel: String { Cadence.quarterly.periodLabel(for: .now) }

    /// Custom categories from every card, plus any typed here.
    private var customNames: [String] {
        let saved = CategoryChoice.customNames(in: allCards.flatMap(\.rewardRates))
        let extra = addedNames.filter { name in !saved.contains { $0.caseInsensitiveCompare(name) == .orderedSame } }
        return saved + extra
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    ForEach(SpendCategory.allCases.filter { $0 != .everythingElse }) { category in
                        choiceRow(.builtIn(category))
                    }
                } header: {
                    Text("Categories")
                } footer: {
                    Text("Pick everything that earns \(multiplier.multiplierText) this quarter. The bonus adds to what a category already earns: the \(multiplier.multiplierText) includes the card's 1× everyday rate, so 3× dining becomes \((multiplier + 2).multiplierText), not \((multiplier + 3).multiplierText).")
                }

                Section {
                    ForEach(customNames, id: \.self) { name in
                        choiceRow(.custom(name))
                    }
                    HStack {
                        TextField("Add a store, e.g. Amazon", text: $newName)
                            .textInputAutocapitalization(.words)
                            .onSubmit(addName)
                        Button("Add", action: addName)
                            .disabled(newName.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                } header: {
                    Text("Stores and Your Categories")
                } footer: {
                    Text("Stores you add here also show up in Best Card.")
                }

                Section {
                    Stepper(value: $multiplier, in: 1...10, step: 0.5) {
                        LabeledContent("Earns", value: multiplier.multiplierText)
                    }
                    Toggle("Spending cap", isOn: $hasCap)
                    if hasCap {
                        HStack {
                            Text("Up to $")
                            TextField("1,500", value: $cap, format: .number)
                                .keyboardType(.decimalPad)
                            Text("a quarter")
                                .foregroundStyle(.secondary)
                        }
                    }
                    Toggle("Activated with my card issuer", isOn: $isActivated)
                } footer: {
                    Text("Most issuers make you activate rotating categories each quarter before they earn the bonus.")
                }
            }
            .navigationTitle("\(quarterLabel) 5× Categories")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .fontWeight(.semibold)
                }
            }
            .onAppear(perform: load)
        }
    }

    private func choiceRow(_ choice: CategoryChoice) -> some View {
        Button {
            if selected.contains(choice) {
                selected.remove(choice)
            } else {
                selected.insert(choice)
            }
        } label: {
            HStack {
                Label(choice.title, systemImage: choice.symbol)
                    .foregroundStyle(Color.primary)
                Spacer()
                if selected.contains(choice) {
                    Image(systemName: "checkmark")
                        .fontWeight(.semibold)
                        .foregroundStyle(.tint)
                }
            }
        }
    }

    private func addName() {
        let name = newName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        let existing = customNames.first { $0.caseInsensitiveCompare(name) == .orderedSame }
        if existing == nil { addedNames.append(name) }
        selected.insert(.custom(existing ?? name))
        newName = ""
    }

    private func load() {
        guard !didLoad else { return }
        didLoad = true
        let current = card.rotatingRates()
        selected = Set(current.map(\.choice))
        if let first = current.first {
            multiplier = first.multiplier
            hasCap = first.capPeriod != nil
            if let amount = first.capAmount { cap = amount }
        }
        isActivated = card.isRotatingActivated()
    }

    private func save() {
        // Keep the order of the lists on screen.
        let builtIn = SpendCategory.allCases.map { CategoryChoice.builtIn($0) }.filter { selected.contains($0) }
        let custom = customNames.map { CategoryChoice.custom($0) }.filter { selected.contains($0) }
        card.setRotatingCategories(builtIn + custom, multiplier: multiplier, cap: hasCap && cap > 0 ? cap : nil)
        card.setRotatingActivated(isActivated)
        dismiss()
    }
}
