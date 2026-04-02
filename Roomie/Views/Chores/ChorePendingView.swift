import SwiftUI

struct ChorePendingView: View {

    @EnvironmentObject var auth: AuthViewModel
    @ObservedObject var viewModel: ChoreViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.pendingChores.isEmpty {
                    ContentUnavailableView(
                        "All caught up",
                        systemImage: "checkmark.seal",
                        description: Text("No chores awaiting approval.")
                    )
                } else {
                    List(viewModel.pendingChores) { chore in
                        PendingChoreCard(
                            chore: chore,
                            myVote: viewModel.myVote(for: chore),
                            needsMyVote: viewModel.needsMyVote(for: chore),
                            proposerName: auth.displayName(for: chore.createdBy),
                            memberNames: Dictionary(uniqueKeysWithValues: auth.householdMembers.map { ($0.id, $0.displayName) }),
                            onApprove: { Task { await viewModel.vote(choreId: chore.id, approved: true) } },
                            onReject:  { Task { await viewModel.vote(choreId: chore.id, approved: false) } }
                        )
                    }
                }
            }
            .navigationTitle("Pending Approval")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

struct PendingChoreCard: View {
    let chore: Chore
    let myVote: Bool?
    let needsMyVote: Bool
    let proposerName: String
    let memberNames: [String: String]
    let onApprove: () -> Void
    let onReject: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(chore.title)
                        .font(.headline)
                    Text("Proposed by \(proposerName) · \(chore.frequency.rawValue)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }

            if !chore.description.isEmpty {
                Text(chore.description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            // Vote tally
            VStack(alignment: .leading, spacing: 4) {
                Text("Votes")
                    .font(.caption.uppercaseSmallCaps())
                    .foregroundStyle(.secondary)
                ForEach(chore.assignablePool, id: \.self) { memberId in
                    HStack(spacing: 6) {
                        Image(systemName: voteIcon(for: memberId))
                            .foregroundStyle(voteColor(for: memberId))
                            .frame(width: 16)
                        Text(memberNames[memberId] ?? memberId)
                            .font(.caption)
                    }
                }
            }

            // Action buttons
            if needsMyVote {
                HStack {
                    Button(role: .destructive) { onReject() } label: {
                        Label("Reject", systemImage: "xmark")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)

                    Button { onApprove() } label: {
                        Label("Approve", systemImage: "checkmark")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                }
            } else if let vote = myVote {
                Label(vote ? "You approved" : "You rejected", systemImage: vote ? "checkmark.circle" : "xmark.circle")
                    .font(.caption)
                    .foregroundStyle(vote ? .green : .red)
            }
        }
        .padding(.vertical, 4)
    }

    private func voteIcon(for memberId: String) -> String {
        switch chore.approvals[memberId] {
        case true:  return "checkmark.circle.fill"
        case false: return "xmark.circle.fill"
        default:    return "circle.dashed"
        }
    }

    private func voteColor(for memberId: String) -> Color {
        switch chore.approvals[memberId] {
        case true:  return .green
        case false: return .red
        default:    return .secondary
        }
    }
}
