import SwiftUI

@main
struct WiseishApp: App {
    var body: some Scene {
        WindowGroup {
            WiseishRootView()
        }
    }
}

private struct WiseishRootView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage("onboarding.v1.completed") private var hasCompletedOnboarding = false
    @State private var showsLaunchAnimation = true

    var body: some View {
        ZStack {
            Group {
                if hasCompletedOnboarding {
                    ContentView()
                        .transition(.opacity)
                } else {
                    WiseishOnboardingView {
                        withAnimation(.easeInOut(duration: reduceMotion ? 0.18 : 0.35)) {
                            hasCompletedOnboarding = true
                        }
                    }
                    .transition(.opacity)
                }
            }
                .opacity(showsLaunchAnimation ? 0.001 : 1)
                .scaleEffect(showsLaunchAnimation && !reduceMotion ? 0.985 : 1)
                .allowsHitTesting(!showsLaunchAnimation)

            if showsLaunchAnimation {
                WiseishLaunchAnimationView()
                    .transition(.opacity)
                    .zIndex(1)
                    .accessibilityHidden(true)
            }
        }
        .task {
            let duration: Duration = reduceMotion ? .milliseconds(500) : .milliseconds(1_550)
            try? await Task.sleep(for: duration)

            withAnimation(.easeOut(duration: reduceMotion ? 0.18 : 0.36)) {
                showsLaunchAnimation = false
            }
        }
    }
}
