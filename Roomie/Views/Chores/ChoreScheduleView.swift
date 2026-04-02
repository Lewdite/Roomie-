import SwiftUI

struct ChoreScheduleView: View {

    @EnvironmentObject var auth: AuthViewModel
    @ObservedObject var viewModel: ChoreViewModel
    @State private var showAddChore = false
    @State private var showPending = false

    private var memberNames: [String: String] {
        Dictionary(uniqueKeysWithValues: auth.householdMembers.map { ($0.id, $0.displayName) })
    }

    var body: some View {
        NavigationStack {
            List {
                // Pending Approval Banner
                if !viewModel.pendingChores.isEmpty {
                    Section {
                        Button {
                            showPending = true
                        } label: {
                            HStack {
                                Image(systemName: "clock.badge.exclamationmark")
                                    .foregroundStyle(.orange)
                                Text("\(viewModel.pendingChores.count) chore(s) awaiting your approval")
                                    .font(.subheadline)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .foregroundStyle(.primary)
                    }
                }

                // This Week
                Section("This Week") {
                    if viewModel.activeChores.isEmpty {
                        ContentUnavailableView(
                            "No chores yet",
                            systemImage: "checkmark.circle",
                            description: Text("Propose a chore to get started.")
                        )
                    } else {
                        ForEach(viewModel.activeChores) { chore in
                            ChoreRow(
                                chore: chore,
                                isCompleted: viewModel.isCompleted(chore),
                                completedByName: viewModel.completedBy(chore, memberNames: memberNames),
                                assigneeName: chore.currentAssigneeId.flatMap { memberNames[$0] },
                                isMyTurn: chore.currentAssigneeId == viewModel.currentUserId,
                                onComplete: {
                                    Task { await viewModel.markComplete(choreId: chore.id) }
                                }
                            )
                        }
                    }
                }
            }
            .navigationTitle("Chores")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showAddChore = true } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showAddChore) {
                AddChoreView(viewModel: viewModel)
            }
            .sheet(isPresented: $showPending) {
                ChorePendingView(viewModel: viewModel)
            }
            .task {
                await viewModel.loadAllWeeklyCompletions()
            }
        }
    }
}

// MARK: - Chore Row

struct ChoreRow: View {
    let chore: Chore
    let isCompleted: Bool
    let completedByName: String?
    let assigneeName: String?
    let isMyTurn: Bool
    let onComplete: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            // Completion indicator
            ZStack {
                Circle()
                    .fill(isCompleted ? Color.green.opacity(0.15) : Color.secondary.opacity(0.1))
                    .frame(width: 40, height: 40)
                Image(systemName: isCompleted ? "checkmark" : "circle.dashed")
                    .foregroundStyle(isCompleted ? .green : .secondary)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(chore.title)
                    .font(.body)
                    .strikethrough(isCompleted)
                if isCompleted, let name = completedByName {
                    Text("Done by \(name)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else if let name = assigneeName {
                    Text("\(chore.frequency.rawValue) · Assigned to \(name)")
                        .font(.caption)
                        .foregroundStyle(isMyTurn ? .accentColor : .secondary)
                }
            }

            Spacer()

            if isMyTurn && !isCompleted {
                Button("Done") { onComplete() }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
            }
        }
        .padding(.vertical, 2)
    }
}
