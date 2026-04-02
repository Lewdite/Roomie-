import Foundation
import FirebaseFirestore
import UIKit

@MainActor
final class ExpenseViewModel: ObservableObject {

    @Published var expenses: [Expense] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var selectedMonth: String = Date().monthKey

    private let service: ExpenseServiceProtocol
    private let ocrService = OCRService()
    private var listener: ListenerRegistration?

    var householdId: String

    init(householdId: String, service: ExpenseServiceProtocol = ExpenseService()) {
        self.householdId = householdId
        self.service = service
        startListening()
    }

    deinit { listener?.remove() }

    // MARK: - Listening

    func startListening() {
        listener?.remove()
        listener = service.listenToExpenses(householdId: householdId, month: selectedMonth) { [weak self] updated in
            self?.expenses = updated
        }
    }

    func changeMonth(to month: String) {
        selectedMonth = month
        startListening()
    }

    // MARK: - Add Expense

    func addExpense(
        title: String,
        amount: Double,
        category: ExpenseCategory,
        paidBy: String,
        splitAmong: [String],
        isRecurring: Bool,
        recurrenceFrequency: RecurrenceFrequency?,
        receiptImage: UIImage?
    ) async {
        isLoading = true
        defer { isLoading = false }

        let expenseId = UUID().uuidString
        var imageURL: String? = nil
        var imageExpiresAt: Date? = nil

        if let image = receiptImage,
           let imageData = image.jpegData(compressionQuality: 0.5) {
            do {
                let result = try await service.uploadReceiptImage(imageData, householdId: householdId, expenseId: expenseId)
                imageURL = result.url
                imageExpiresAt = result.expiresAt
            } catch {
                errorMessage = "Receipt upload failed: \(error.localizedDescription)"
            }
        }

        let settlements = buildSettlements(paidBy: paidBy, splitAmong: splitAmong, amount: amount)

        let expense = Expense(
            id: expenseId,
            householdId: householdId,
            title: title,
            amount: amount,
            paidBy: paidBy,
            splitAmong: splitAmong,
            category: category,
            isRecurring: isRecurring,
            recurrenceFrequency: recurrenceFrequency,
            imageURL: imageURL,
            imageExpiresAt: imageExpiresAt,
            month: selectedMonth,
            settlements: settlements,
            createdBy: paidBy,
            createdAt: Date()
        )

        do {
            try await service.addExpense(expense)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func markSettled(expense: Expense, settlementId: String) async {
        do {
            try await service.markSettled(
                householdId: householdId,
                expenseId: expense.id,
                settlementId: settlementId
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func deleteExpense(_ expense: Expense) async {
        do {
            try await service.deleteExpense(householdId: householdId, expenseId: expense.id)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - OCR

    func extractReceiptData(from image: UIImage) async -> OCRService.OCRResult? {
        try? await ocrService.extractText(from: image)
    }

    // MARK: - Summary

    /// Net balance per user for the selected month: positive = owed money, negative = owes money
    func balanceSummary(memberIds: [String]) -> [String: Double] {
        var balances: [String: Double] = Dictionary(uniqueKeysWithValues: memberIds.map { ($0, 0.0) })
        for expense in expenses {
            // Payer is owed the others' shares
            let share = expense.sharePerPerson
            for memberId in expense.splitAmong where memberId != expense.paidBy {
                balances[expense.paidBy, default: 0] += share
                balances[memberId, default: 0] -= share
            }
            // Apply settled payments
            for settlement in expense.settlements where settlement.isSettled {
                balances[settlement.fromUserId, default: 0] += settlement.amount
                balances[settlement.toUserId, default: 0] -= settlement.amount
            }
        }
        return balances
    }

    var totalMonthlyExpenses: Double {
        expenses.reduce(0) { $0 + $1.amount }
    }

    // MARK: - Private

    private func buildSettlements(paidBy: String, splitAmong: [String], amount: Double) -> [Settlement] {
        let share = amount / Double(splitAmong.count)
        return splitAmong
            .filter { $0 != paidBy }
            .map { memberId in
                Settlement(
                    id: UUID().uuidString,
                    fromUserId: memberId,
                    toUserId: paidBy,
                    amount: share,
                    isSettled: false,
                    settledAt: nil
                )
            }
    }
}

private extension Date {
    var monthKey: String {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM"
        return fmt.string(from: self)
    }
}
