import SwiftUI

struct AddChoreView: View {

    @EnvironmentObject var auth: AuthViewModel
    @ObservedObject var viewModel: ChoreViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var description = ""
    @State private var frequency: ChoreFrequency = .weekly
    @State private var selectedMemberIds: Set<String> = []
    @State private var excludeLastAssignee = false
    @State private var isSubmitting = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Chore") {
                    TextField("Name", text: $title)
                    TextField("Description (optional)", text: $description, axis: .vertical)
                        .lineLimit(3)
                }

                Section("Frequency") {
                    Picker("Repeats", selection: $frequency) {
                        ForEach(ChoreFrequency.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.navigationLink)
                }

                Section {
                    ForEach(auth.householdMembers) { member in
                        Toggle(member.displayName, isOn: Binding(
                            get: { selectedMemberIds.contains(member.id) },
                            set: { checked in
                                if checked { selectedMemberIds.insert(member.id) }
                                else { selectedMemberIds.remove(member.id) }
                            }
                        ))
                    }
                } header: {
                    Text("Assignable Pool")
                } footer: {
                    Text("All selected members must approve this chore before it becomes active.")
                        .font(.caption)
                }

                Section {
                    Toggle(isOn: $excludeLastAssignee) {
                        Label("Never assign twice in a row", systemImage: "arrow.2.squarepath")
                    }
                } footer: {
                    Text(excludeLastAssignee
                         ? "The previous person is always excluded from the next draw. Best for small households or chores that should strictly alternate."
                         : "Assignment is purely probability-weighted by completion count. The same person could be picked consecutively, but less likely the more they've done it.")
                        .font(.caption)
                }
            }
            .navigationTitle("Propose Chore")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Propose") { submit() }
                        .disabled(!isFormValid || isSubmitting)
                        .fontWeight(.semibold)
                }
            }
            .onAppear {
                selectedMemberIds = Set(auth.householdMembers.map(\.id))
            }
        }
    }

    private var isFormValid: Bool {
        !title.trimmingCharacters(in: .whitespaces).isEmpty && selectedMemberIds.count >= 1
    }

    private func submit() {
        isSubmitting = true
        Task {
            await viewModel.proposeChore(
                title: title.trimmingCharacters(in: .whitespaces),
                description: description.trimmingCharacters(in: .whitespaces),
                frequency: frequency,
                assignablePool: Array(selectedMemberIds),
                excludeLastAssignee: excludeLastAssignee
            )
            isSubmitting = false
            dismiss()
        }
    }
}
