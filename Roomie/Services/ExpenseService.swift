import Foundation
import FirebaseFirestore
import FirebaseStorage

protocol ExpenseServiceProtocol {
    func fetchExpenses(householdId: String, month: String) async throws -> [Expense]
    func addExpense(_ expense: Expense) async throws
    func updateExpense(_ expense: Expense) async throws
    func deleteExpense(householdId: String, expenseId: String) async throws
    func markSettled(householdId: String, expenseId: String, settlementId: String) async throws
    func uploadReceiptImage(_ imageData: Data, householdId: String, expenseId: String) async throws -> (url: String, expiresAt: Date)
    func listenToExpenses(householdId: String, month: String, onChange: @escaping ([Expense]) -> Void) -> ListenerRegistration
}

final class ExpenseService: ExpenseServiceProtocol {

    private let db = Firestore.firestore()
    private let storage = Storage.storage()

    private func expensesRef(householdId: String) -> CollectionReference {
        db.collection("households").document(householdId).collection("expenses")
    }

    // MARK: Fetch

    func fetchExpenses(householdId: String, month: String) async throws -> [Expense] {
        let snapshot = try await expensesRef(householdId: householdId)
            .whereField("month", isEqualTo: month)
            .order(by: "createdAt", descending: true)
            .getDocuments()
        return snapshot.documents.compactMap { try? $0.data(as: Expense.self) }
    }

    // MARK: Write

    func addExpense(_ expense: Expense) async throws {
        try expensesRef(householdId: expense.householdId)
            .document(expense.id)
            .setData(from: expense)
    }

    func updateExpense(_ expense: Expense) async throws {
        try expensesRef(householdId: expense.householdId)
            .document(expense.id)
            .setData(from: expense, merge: true)
    }

    func deleteExpense(householdId: String, expenseId: String) async throws {
        try await expensesRef(householdId: householdId).document(expenseId).delete()
    }

    // MARK: Settlement

    func markSettled(householdId: String, expenseId: String, settlementId: String) async throws {
        let ref = expensesRef(householdId: householdId).document(expenseId)
        let snapshot = try await ref.getDocument()
        guard var expense = try? snapshot.data(as: Expense.self),
              let idx = expense.settlements.firstIndex(where: { $0.id == settlementId }) else {
            return
        }
        expense.settlements[idx].isSettled = true
        expense.settlements[idx].settledAt = Date()
        try ref.setData(from: expense)
    }

    // MARK: Receipt Image

    /// Compresses and uploads a receipt image. Returns the download URL and 60-day expiry date.
    func uploadReceiptImage(_ imageData: Data, householdId: String, expenseId: String) async throws -> (url: String, expiresAt: Date) {
        let path = "receipts/\(householdId)/\(expenseId).jpg"
        let ref = storage.reference().child(path)
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"

        _ = try await ref.putDataAsync(imageData, metadata: metadata)
        let url = try await ref.downloadURL()
        let expiresAt = Calendar.current.date(byAdding: .day, value: 60, to: Date())!
        return (url.absoluteString, expiresAt)
    }

    // MARK: Real-time Listener

    func listenToExpenses(householdId: String, month: String, onChange: @escaping ([Expense]) -> Void) -> ListenerRegistration {
        expensesRef(householdId: householdId)
            .whereField("month", isEqualTo: month)
            .order(by: "createdAt", descending: true)
            .addSnapshotListener { snapshot, _ in
                let expenses = snapshot?.documents.compactMap { try? $0.data(as: Expense.self) } ?? []
                onChange(expenses)
            }
    }
}
