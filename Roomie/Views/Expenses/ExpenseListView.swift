import SwiftUI

struct ExpenseListView: View {

    @EnvironmentObject var auth: AuthViewModel
    @ObservedObject var viewModel: ExpenseViewModel
    @State private var showAddExpense = false
    @State private var showSettlement = false

    var body: some View {
        NavigationStack {
            List {
                // Monthly Summary Banner
                Section {
                    MonthlySummaryBanner(
                        total: viewModel.totalMonthlyExpenses,
                        balances: viewModel.balanceSummary(memberIds: auth.householdMembers.map(\.id)),
                        members: auth.householdMembers
                    )
                }
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)

                // Expense Rows
                Section("Charges") {
                    if viewModel.expenses.isEmpty {
                        ContentUnavailableView(
                            "No expenses yet",
                            systemImage: "dollarsign.circle",
                            description: Text("Add the first charge for \(viewModel.selectedMonth).")
                        )
                    } else {
                        ForEach(viewModel.expenses) { expense in
                            NavigationLink {
                                ExpenseDetailView(expense: expense, viewModel: viewModel)
                            } label: {
                                ExpenseRow(expense: expense, members: auth.householdMembers)
                            }
                        }
                        .onDelete { offsets in
                            Task {
                                for i in offsets {
                                    await viewModel.deleteExpense(viewModel.expenses[i])
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle(viewModel.selectedMonth.formattedMonthTitle)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    MonthPickerButton(selectedMonth: $viewModel.selectedMonth) { month in
                        viewModel.changeMonth(to: month)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showAddExpense = true } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showAddExpense) {
                AddExpenseView(viewModel: viewModel)
            }
        }
    }
}

// MARK: - Supporting Views

struct ExpenseRow: View {
    let expense: Expense
    let members: [RoomieUser]

    var payerName: String {
        members.first { $0.id == expense.paidBy }?.displayName ?? "Someone"
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(expense.title)
                    .font(.body)
                Text("\(payerName) paid")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(expense.amount.currencyFormatted)
                    .font(.body.monospacedDigit())
                    .fontWeight(.medium)
                Text(expense.category.rawValue)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}

struct MonthlySummaryBanner: View {
    let total: Double
    let balances: [String: Double]
    let members: [RoomieUser]

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text("Total")
                    .font(.caption.uppercaseSmallCaps())
                    .foregroundStyle(.secondary)
                Spacer()
                Text(total.currencyFormatted)
                    .font(.title2.bold().monospacedDigit())
            }
            Divider()
            ForEach(members) { member in
                if let balance = balances[member.id] {
                    HStack {
                        Text(member.displayName)
                            .font(.caption)
                        Spacer()
                        Text(balance >= 0
                             ? "gets back \(abs(balance).currencyFormatted)"
                             : "owes \(abs(balance).currencyFormatted)")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(balance >= 0 ? .green : .red)
                    }
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
        .padding([.horizontal, .top])
    }
}

struct MonthPickerButton: View {
    @Binding var selectedMonth: String
    var onSelect: (String) -> Void

    // Generate last 12 months
    private var months: [String] {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM"
        return (0..<12).compactMap {
            Calendar.current.date(byAdding: .month, value: -$0, to: Date()).map { fmt.string(from: $0) }
        }
    }

    var body: some View {
        Menu {
            ForEach(months, id: \.self) { month in
                Button(month.formattedMonthTitle) {
                    selectedMonth = month
                    onSelect(month)
                }
            }
        } label: {
            Image(systemName: "calendar")
        }
    }
}
