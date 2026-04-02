import SwiftUI
import PhotosUI

struct AddExpenseView: View {

    @EnvironmentObject var auth: AuthViewModel
    @ObservedObject var viewModel: ExpenseViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var amountText = ""
    @State private var category: ExpenseCategory = .other
    @State private var paidBy: String = ""
    @State private var selectedMemberIds: Set<String> = []
    @State private var isRecurring = false
    @State private var recurrenceFrequency: RecurrenceFrequency = .monthly
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var receiptImage: UIImage?
    @State private var isExtractingOCR = false
    @State private var isSubmitting = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Details") {
                    TextField("Title", text: $title)
                    HStack {
                        Text("$")
                        TextField("Amount", text: $amountText)
                            .keyboardType(.decimalPad)
                    }
                    Picker("Category", selection: $category) {
                        ForEach(ExpenseCategory.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                    }
                }

                Section("Paid by") {
                    Picker("Paid by", selection: $paidBy) {
                        ForEach(auth.householdMembers) { member in
                            Text(member.displayName).tag(member.id)
                        }
                    }
                    .pickerStyle(.navigationLink)
                }

                Section("Split among") {
                    ForEach(auth.householdMembers) { member in
                        Toggle(member.displayName, isOn: Binding(
                            get: { selectedMemberIds.contains(member.id) },
                            set: { checked in
                                if checked { selectedMemberIds.insert(member.id) }
                                else { selectedMemberIds.remove(member.id) }
                            }
                        ))
                    }
                }

                Section("Recurrence") {
                    Toggle("Recurring charge", isOn: $isRecurring)
                    if isRecurring {
                        Picker("Frequency", selection: $recurrenceFrequency) {
                            ForEach(RecurrenceFrequency.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                        }
                    }
                }

                Section("Receipt") {
                    PhotosPicker(selection: $selectedPhoto, matching: .images) {
                        Label(
                            receiptImage == nil ? "Attach Receipt" : "Change Receipt",
                            systemImage: "doc.viewfinder"
                        )
                    }
                    .onChange(of: selectedPhoto) { _, item in
                        Task { await loadPhoto(item) }
                    }

                    if let image = receiptImage {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 180)
                            .clipShape(RoundedRectangle(cornerRadius: 8))

                        if isExtractingOCR {
                            HStack { ProgressView(); Text("Reading receipt…").font(.caption) }
                        }
                    }
                }
            }
            .navigationTitle("Add Expense")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") { submit() }
                        .disabled(!isFormValid || isSubmitting)
                        .fontWeight(.semibold)
                }
            }
            .onAppear {
                paidBy = auth.currentUser?.id ?? ""
                selectedMemberIds = Set(auth.householdMembers.map(\.id))
            }
        }
    }

    private var isFormValid: Bool {
        !title.isEmpty && Double(amountText) != nil && !paidBy.isEmpty && !selectedMemberIds.isEmpty
    }

    private func loadPhoto(_ item: PhotosPickerItem?) async {
        guard let item, let data = try? await item.loadTransferable(type: Data.self),
              let image = UIImage(data: data) else { return }
        receiptImage = image
        isExtractingOCR = true
        if let result = await viewModel.extractReceiptData(from: image) {
            if let detected = result.detectedAmount, amountText.isEmpty {
                amountText = String(format: "%.2f", detected)
            }
            if let vendor = result.detectedVendor, title.isEmpty {
                title = vendor
            }
        }
        isExtractingOCR = false
    }

    private func submit() {
        guard let amount = Double(amountText) else { return }
        isSubmitting = true
        Task {
            await viewModel.addExpense(
                title: title,
                amount: amount,
                category: category,
                paidBy: paidBy,
                splitAmong: Array(selectedMemberIds),
                isRecurring: isRecurring,
                recurrenceFrequency: isRecurring ? recurrenceFrequency : nil,
                receiptImage: receiptImage
            )
            isSubmitting = false
            dismiss()
        }
    }
}
