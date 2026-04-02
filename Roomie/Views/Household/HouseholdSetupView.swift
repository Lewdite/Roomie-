import SwiftUI

struct HouseholdSetupView: View {

    @EnvironmentObject var auth: AuthViewModel
    @State private var householdName = ""
    @State private var inviteCode = ""
    @State private var mode: Mode = .create
    @State private var isLoading = false

    enum Mode { case create, join }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Mode Picker
                Picker("Mode", selection: $mode) {
                    Text("Create").tag(Mode.create)
                    Text("Join").tag(Mode.join)
                }
                .pickerStyle(.segmented)
                .padding()

                Form {
                    if mode == .create {
                        Section("Household Name") {
                            TextField("e.g. 42 Maple Street", text: $householdName)
                        }
                    } else {
                        Section("Invite Code") {
                            TextField("6-character code", text: $inviteCode)
                                .textInputAutocapitalization(.characters)
                                .onChange(of: inviteCode) { _, new in
                                    inviteCode = String(new.prefix(6)).uppercased()
                                }
                        }
                    }
                }

                Button {
                    submit()
                } label: {
                    Group {
                        if isLoading {
                            ProgressView()
                        } else {
                            Text(mode == .create ? "Create Household" : "Join Household")
                                .fontWeight(.semibold)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(isFormValid ? Color.accentColor : Color.secondary.opacity(0.3), in: RoundedRectangle(cornerRadius: 14))
                    .foregroundStyle(isFormValid ? .white : .secondary)
                }
                .disabled(!isFormValid || isLoading)
                .padding()
            }
            .navigationTitle("Your Household")
            .navigationBarTitleDisplayMode(.large)
            .alert("Error", isPresented: .constant(auth.errorMessage != nil)) {
                Button("OK") { auth.errorMessage = nil }
            } message: {
                Text(auth.errorMessage ?? "")
            }
        }
    }

    private var isFormValid: Bool {
        mode == .create ? !householdName.trimmingCharacters(in: .whitespaces).isEmpty
                        : inviteCode.count == 6
    }

    private func submit() {
        isLoading = true
        Task {
            defer { isLoading = false }
            if mode == .create {
                await auth.createHousehold(name: householdName.trimmingCharacters(in: .whitespaces))
            } else {
                await auth.joinHousehold(inviteCode: inviteCode)
            }
        }
    }
}
