import SwiftUI

struct SplashView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "house.fill")
                .font(.system(size: 64))
                .foregroundStyle(.tint)
            Text("Roomie")
                .font(.largeTitle.bold())
            ProgressView()
                .padding(.top, 8)
        }
    }
}
