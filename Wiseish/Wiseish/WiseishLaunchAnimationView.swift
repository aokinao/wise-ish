import SwiftUI

struct WiseishLaunchAnimationView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var hasAppeared = false
    @State private var isNodding = false

    private let paper = Color(red: 0.96, green: 0.92, blue: 0.85)
    private let ink = Color(red: 0.16, green: 0.15, blue: 0.13)
    private let softInk = Color(red: 0.44, green: 0.41, blue: 0.37)
    private let mustard = Color(red: 0.85, green: 0.66, blue: 0.23)

    var body: some View {
        ZStack {
            paper.ignoresSafeArea()

            Circle()
                .trim(from: 0.08, to: hasAppeared ? 0.92 : 0.08)
                .stroke(
                    mustard.opacity(0.7),
                    style: StrokeStyle(lineWidth: 2, lineCap: .round)
                )
                .frame(width: 232, height: 232)
                .rotationEffect(.degrees(hasAppeared ? 28 : -82))
                .opacity(reduceMotion ? 0 : 1)

            VStack(spacing: 16) {
                Image("Ish")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 176, height: 176)
                    .scaleEffect(hasAppeared ? 1 : 0.82, anchor: .bottom)
                    .offset(y: hasAppeared ? 0 : 24)
                    .rotationEffect(
                        .degrees(reduceMotion ? 0 : (isNodding ? 2.5 : -2)),
                        anchor: .bottom
                    )
                    .opacity(hasAppeared ? 1 : 0)
                    .shadow(color: ink.opacity(0.08), radius: 6, y: 5)

                VStack(spacing: 7) {
                    HStack(spacing: 0) {
                        Text("Wise")
                        Text("–").foregroundStyle(mustard)
                        Text("ish")
                    }
                    .font(.system(size: 29, weight: .bold, design: .serif))

                    Text("きょうも、たぶん。")
                        .font(.system(size: 11, weight: .semibold, design: .serif))
                        .tracking(1.5)
                        .foregroundStyle(softInk)
                }
                .offset(y: hasAppeared ? 0 : 8)
                .opacity(hasAppeared ? 1 : 0)
            }
        }
        .foregroundStyle(ink)
        .onAppear {
            withAnimation(.easeOut(duration: reduceMotion ? 0.2 : 0.55)) {
                hasAppeared = true
            }

            guard !reduceMotion else { return }
            withAnimation(
                .easeInOut(duration: 0.32)
                    .repeatCount(2, autoreverses: true)
                    .delay(0.48)
            ) {
                isNodding = true
            }
        }
    }
}

#Preview {
    WiseishLaunchAnimationView()
}
