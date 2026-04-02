import SwiftUI

struct MainTabView: View {

    @EnvironmentObject var auth: AuthViewModel
    @State private var selectedTab = 0

    var body: some View {
        Group {
            if let household = auth.currentHousehold,
               let user = auth.currentUser {
                TabView(selection: $selectedTab) {
                    ExpenseListView(
                        viewModel: ExpenseViewModel(householdId: household.id)
                    )
                    .tabItem { Label("Expenses", systemImage: "dollarsign.circle") }
                    .tag(0)

                    ChoreScheduleView(
                        viewModel: ChoreViewModel(
                            householdId: household.id,
                            currentUserId: user.id
                        )
                    )
                    .tabItem { Label("Chores", systemImage: "checkmark.circle") }
                    .tag(1)

                    BulletinBoardView(
                        viewModel: BulletinViewModel(
                            householdId: household.id,
                            currentUserId: user.id
                        )
                    )
                    .tabItem { Label("Bulletin", systemImage: "pin.circle") }
                    .tag(2)

                    HouseholdSettingsView()
                        .tabItem { Label("House", systemImage: "house") }
                        .tag(3)
                }
            } else {
                ProgressView("Loading…")
            }
        }
    }
}
