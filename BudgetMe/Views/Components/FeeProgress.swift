import SwiftUI

/// How much of a card's annual fee its credits have earned back: "$120 of $325" with a bar.
struct FeeProgress: View {
    let fee: Double
    let earned: Double

    private var isCovered: Bool { earned >= fee }

    private var status: String {
        if earned > fee { return "+\((earned - fee).currencyText) ahead" }
        if isCovered { return "Fee covered" }
        return "\((fee - earned).currencyText) to go"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text("\(earned.currencyText) of \(fee.currencyText)")
                    .font(.body.weight(.semibold).monospacedDigit())
                Spacer(minLength: 8)
                Label(status, systemImage: isCovered ? "checkmark.seal.fill" : "hourglass")
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(isCovered ? Color.green : Color.secondary)
            }
            ProgressView(value: min(earned, fee), total: fee)
                .tint(isCovered ? .green : .orange)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    List {
        FeeProgress(fee: 325, earned: 120)
        FeeProgress(fee: 95, earned: 150)
    }
}
