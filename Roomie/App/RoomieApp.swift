import SwiftUI
import FirebaseCore

@main
struct RoomieApp: App {

    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @StateObject private var auth = AuthViewModel()

    var body: some Scene {
        WindowGroup {
            Group {
                if auth.isLoading {
                    SplashView()
                } else if auth.currentUser == nil {
                    SignInView()
                } else if auth.currentHousehold == nil {
                    HouseholdSetupView()
                } else {
                    MainTabView()
                }
            }
            .environmentObject(auth)
            .animation(.easeInOut(duration: 0.3), value: auth.currentUser?.id)
            .animation(.easeInOut(duration: 0.3), value: auth.currentHousehold?.id)
        }
    }
}
