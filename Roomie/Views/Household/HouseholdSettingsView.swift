import SwiftUI

struct HouseholdSettingsView: View {

    @EnvironmentObject var auth: AuthViewModel
    @State private var showInviteCode = false
    @State private var showLeaveConfirm = false

    var body: some View {
        NavigationStack {
            List {
                // Household Info
                Section {
                    HStack {
                        Image(systemName: "house.fill")
                            .font(.title2)
                            .foregroundStyle(.accentColor)
                            .frame(width: 44, height: 44)
                            .background(Color.accentColor.opacity(0.12), in: Circle())
                        VStack(alignment: .leading) {
                            Text(auth.currentHousehold?.name ?? "")
                                .font(.headline)
                            Text("\(auth.householdMembers.count) members")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }

                // Members
                Section("Members") {
                    ForEach(auth.householdMembers) { member in
                        HStack {
                            AsyncImage(url: URL(string: member.photoURL ?? "")) { image in
                                image.resizable().scaledToFill()
                            } placeholder: {
                                Image(systemName: "person.circle.fill")
                                    .foregroundStyle(.secondary)
                            }
                            .frame(width: 36, height: 36)
                            .clipShape(Circle())

                            VStack(alignment: .leading) {
                                Text(member.displayName)
                                Text(member.email)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            if member.id == auth.currentHousehold?.adminId {
                                Spacer()
                                Text("Admin")
                                    .font(.caption)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 2)
                                    .background(.tint.opacity(0.1), in: Capsule())
                                    .foregroundStyle(.tint)
                            }
                        }
                    }
                }

                // Invite
                Section("Invite") {
                    Button {
                        showInviteCode = true
                    } label: {
                        Label("Share Invite Code", systemImage: "person.badge.plus")
                    }
                }

                // Account
                Section("Account") {
                    if let user = auth.currentUser {
                        Label(user.email, systemImage: "envelope")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Button(role: .destructive) {
                        auth.signOut()
                    } label: {
                        Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                    }
                }
            }
            .navigationTitle("Household")
            .sheet(isPresented: $showInviteCode) {
                InviteCodeSheet(code: auth.currentHousehold?.inviteCode ?? "")
            }
        }
    }
}

struct InviteCodeSheet: View {
    let code: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Image(systemName: "person.badge.plus")
                    .font(.system(size: 52))
                    .foregroundStyle(.tint)

                Text("Invite a Housemate")
                    .font(.title2.bold())

                Text("Share this code. They can enter it when creating their account.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                Text(code)
                    .font(.system(size: 40, weight: .bold, design: .monospaced))
                    .tracking(8)
                    .padding()
                    .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))

                Button {
                    UIPasteboard.general.string = code
                } label: {
                    Label("Copy Code", systemImage: "doc.on.doc")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(.tint, in: RoundedRectangle(cornerRadius: 12))
                        .foregroundStyle(.white)
                }
                .padding(.horizontal)

                Spacer()
            }
            .padding(.top, 32)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
    }
}
