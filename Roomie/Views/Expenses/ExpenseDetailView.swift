import SwiftUI

struct ExpenseDetailView: View {

    @EnvironmentObject var auth: AuthViewModel
    let expense: Expense
    @ObservedObject var viewModel: ExpenseViewModel

    var body: some View {
        List {
            // Header
            Section {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(expense.title)
                            .font(.title2.bold())
                        Text(expense.category.rawValue)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text(expense.amount.currencyFormatted)
                        .font(.title.bold().monospacedDigit())
                }
                .padding(.vertical, 4)

                Label(
                    "Paid by \(auth.displayName(for: expense.paidBy))",
                    systemImage: "person.circle"
                )
                .font(.subheadline)

                if expense.isRecurring, let freq = expense.recurrenceFrequency {
                    Label("Repeats \(freq.rawValue)", systemImage: "arrow.trianglehead.clockwise")
                        .font(.subheadline)
                }
            }

            // Receipt Image
            if let imageURL = expense.imageURL, !imageURL.isEmpty {
                Section("Receipt") {
                    AsyncImage(url: URL(string: imageURL)) { phase in
                        switch phase {
                        case .success(let image):
                            image.resizable().scaledToFit().clipShape(RoundedRectangle(cornerRadius: 8))
                        case .failure:
                            Label("Receipt unavailable", systemImage: "photo.slash")
                                .foregroundStyle(.secondary)
                        default:
                            ProgressView()
                        }
                    }
                    if let expiresAt = expense.imageExpiresAt {
                        Text("Receipt stored until \(expiresAt.formatted(date: .abbreviated, time: .omitted))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            // Settlements
            Section("Settlements") {
                ForEach(expense.settlements) { settlement in
                    HStack {
                        VStack(alignment: .leading) {
                            Text("\(auth.displayName(for: settlement.fromUserId)) → \(auth.displayName(for: settlement.toUserId))")
                                .font(.subheadline)
                            if settlement.isSettled, let date = settlement.settledAt {
                                Text("Settled \(date.formatted(date: .abbreviated, time: .omitted))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                        if settlement.isSettled {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                        } else {
                            VStack(alignment: .trailing) {
                                Text(settlement.amount.currencyFormatted)
                                    .font(.subheadline.monospacedDigit())
                                if settlement.fromUserId == auth.currentUser?.id {
                                    Button("Mark Settled") {
                                        Task { await viewModel.markSettled(expense: expense, settlementId: settlement.id) }
                                    }
                                    .font(.caption)
                                    .buttonStyle(.bordered)
                                    .controlSize(.mini)
                                }
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Expense")
        .navigationBarTitleDisplayMode(.inline)
    }
}
