import Foundation
import SwiftData
import CoreTransferable
import UniformTypeIdentifiers

/// Everything in the app as JSON, to move it to another device or keep a copy.
struct Backup: Codable {
    var version = 1
    var exportedAt = Date()
    var cards: [CardRecord] = []
    var bills: [BillRecord] = []
    /// Credits that aren't on any card.
    var otherCredits: [CreditRecord] = []

    struct CardRecord: Codable {
        var name: String
        var issuer: String
        var lastFour: String
        var theme: String
        var dueDay: Int
        var paidPeriods: [String]
        var rewardRates: [RewardRate]
        var perks: [String]
        var notes: String
        var reminderDaysBefore: Int?
        var pointValue: Double?
        var annualFee: Double?
        var noForeignFee: Bool?
        var network: String?
        var showInBestCard: Bool?
        var capsReached: [String]?
        var hasRotatingCategories: Bool?
        var rotatingActivated: [String]?
        var design: String?
        /// The card's picture as JPEG, if you added one.
        var imageData: Data?
        var sortOrder: Int
        var createdAt: Date
        var credits: [CreditRecord]
    }

    struct CreditRecord: Codable {
        var name: String
        var amount: Double?
        var cadence: String
        var usedPeriods: [String]
        var note: String
        var createdAt: Date
    }

    struct BillRecord: Codable {
        var name: String
        var amount: Double?
        var dueDay: Int
        var symbol: String
        var paidPeriods: [String]
        var reminderDaysBefore: Int?
        var createdAt: Date
    }

    enum Problem: LocalizedError {
        case notABackup

        var errorDescription: String? { "That isn't a BudgetMe backup." }
    }
}

extension Backup {
    init(cards: [CreditCard], bills: [Bill], credits: [Benefit]) {
        self.cards = cards.sorted { $0.sortOrder < $1.sortOrder }.map { CardRecord($0) }
        self.bills = bills.map { BillRecord($0) }
        self.otherCredits = credits.filter { $0.card == nil }.map { CreditRecord($0) }
    }

    /// "10 cards, 9 credits and 1 bill"
    var summary: String {
        let creditCount = cards.reduce(otherCredits.count) { $0 + $1.credits.count }
        func count(_ number: Int, _ noun: String) -> String { "\(number) \(noun)\(number == 1 ? "" : "s")" }
        return "\(count(cards.count, "card")), \(count(creditCount, "credit")) and \(count(bills.count, "bill"))"
    }

    func encoded() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(self)
    }

    static func decode(_ data: Data) throws -> Backup {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        do {
            return try decoder.decode(Backup.self, from: data)
        } catch {
            throw Problem.notABackup
        }
    }

    /// Replaces everything in `context` with this backup.
    func restore(into context: ModelContext) throws {
        try context.fetch(FetchDescriptor<Benefit>()).forEach { context.delete($0) }
        try context.fetch(FetchDescriptor<CreditCard>()).forEach { context.delete($0) }
        try context.fetch(FetchDescriptor<Bill>()).forEach { context.delete($0) }

        for record in cards {
            let card = CreditCard(
                name: record.name,
                issuer: record.issuer,
                lastFour: record.lastFour,
                theme: CardTheme(rawValue: record.theme) ?? .graphite,
                dueDay: record.dueDay,
                rewardRates: record.rewardRates,
                perks: record.perks,
                sortOrder: record.sortOrder
            )
            context.insert(card)
            card.paidPeriods = record.paidPeriods
            card.notes = record.notes
            card.reminderDaysBefore = record.reminderDaysBefore
            card.pointValue = record.pointValue
            card.annualFee = record.annualFee
            card.noForeignFee = record.noForeignFee
            card.networkRaw = record.network
            card.showInBestCard = record.showInBestCard ?? true
            card.capsReached = record.capsReached ?? []
            card.hasRotatingCategories = record.hasRotatingCategories
            card.rotatingActivated = record.rotatingActivated ?? []
            card.designRaw = record.design
            card.cardImageData = record.imageData
            card.createdAt = record.createdAt
            for credit in record.credits {
                let benefit = credit.insert(into: context)
                benefit.card = card
            }
        }
        for credit in otherCredits {
            _ = credit.insert(into: context)
        }
        for record in bills {
            let bill = Bill(name: record.name, amount: record.amount, dueDay: record.dueDay, symbol: record.symbol)
            context.insert(bill)
            bill.paidPeriods = record.paidPeriods
            bill.reminderDaysBefore = record.reminderDaysBefore
            bill.createdAt = record.createdAt
        }
        try context.save()
    }
}

extension Backup.CardRecord {
    init(_ card: CreditCard) {
        self.init(
            name: card.name,
            issuer: card.issuer,
            lastFour: card.lastFour,
            theme: card.themeRaw,
            dueDay: card.dueDay,
            paidPeriods: card.paidPeriods,
            rewardRates: card.rewardRates,
            perks: card.perks,
            notes: card.notes,
            reminderDaysBefore: card.reminderDaysBefore,
            pointValue: card.pointValue,
            annualFee: card.annualFee,
            noForeignFee: card.noForeignFee,
            network: card.networkRaw,
            showInBestCard: card.showInBestCard,
            capsReached: card.capsReached,
            hasRotatingCategories: card.hasRotatingCategories,
            rotatingActivated: card.rotatingActivated,
            design: card.designRaw,
            imageData: card.cardImageData,
            sortOrder: card.sortOrder,
            createdAt: card.createdAt,
            credits: card.sortedBenefits.map { Backup.CreditRecord($0) }
        )
    }
}

extension Backup.CreditRecord {
    init(_ benefit: Benefit) {
        self.init(
            name: benefit.name,
            amount: benefit.amount,
            cadence: benefit.cadenceRaw,
            usedPeriods: benefit.usedPeriods,
            note: benefit.note,
            createdAt: benefit.createdAt
        )
    }

    func insert(into context: ModelContext) -> Benefit {
        let benefit = Benefit(name: name, amount: amount, cadence: Cadence(rawValue: cadence) ?? .monthly, note: note)
        context.insert(benefit)
        benefit.usedPeriods = usedPeriods
        benefit.createdAt = createdAt
        return benefit
    }
}

extension Backup.BillRecord {
    init(_ bill: Bill) {
        self.init(
            name: bill.name,
            amount: bill.amount,
            dueDay: bill.dueDay,
            symbol: bill.symbol,
            paidPeriods: bill.paidPeriods,
            reminderDaysBefore: bill.reminderDaysBefore,
            createdAt: bill.createdAt
        )
    }
}

/// A backup as a .json file for the share sheet.
struct BackupFile: Transferable {
    let data: Data

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .json) { $0.data }
            .suggestedFileName("BudgetMe Backup.json")
    }
}
