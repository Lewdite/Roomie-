import SwiftUI

struct ComposeBulletinView: View {

    @ObservedObject var viewModel: BulletinViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var content = ""
    @State private var isUrgent = false
    @State private var isSubmitting = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Post") {
                    TextField("Title", text: $title)
                    TextField("What's on your mind?", text: $content, axis: .vertical)
                        .lineLimit(5...10)
                }

                Section {
                    Toggle(isOn: $isUrgent) {
                        Label("Mark as Urgent", systemImage: "exclamationmark.triangle")
                    }
                    .tint(.orange)
                } footer: {
                    Text("Urgent posts send a push notification to all housemates.")
                        .font(.caption)
                }
            }
            .navigationTitle("New Post")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Post") { submit() }
                        .disabled(!isFormValid || isSubmitting)
                        .fontWeight(.semibold)
                }
            }
        }
    }

    private var isFormValid: Bool {
        !title.trimmingCharacters(in: .whitespaces).isEmpty &&
        !content.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private func submit() {
        isSubmitting = true
        Task {
            await viewModel.post(
                title: title.trimmingCharacters(in: .whitespaces),
                content: content.trimmingCharacters(in: .whitespaces),
                isUrgent: isUrgent
            )
            isSubmitting = false
            dismiss()
        }
    }
}
