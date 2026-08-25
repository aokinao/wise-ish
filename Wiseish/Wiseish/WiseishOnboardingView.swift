import SwiftUI

struct WiseishOnboardingView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var page = 0
    @State private var selectedMood = WiseishMood.quiet

    let onComplete: () -> Void

    private let paper = Color(red: 0.96, green: 0.92, blue: 0.85)
    private let lightPaper = Color(red: 1.00, green: 0.98, blue: 0.94)
    private let ink = Color(red: 0.16, green: 0.15, blue: 0.13)
    private let softInk = Color(red: 0.44, green: 0.41, blue: 0.37)
    private let mustard = Color(red: 0.85, green: 0.66, blue: 0.23)

    var body: some View {
        ZStack {
            paper.ignoresSafeArea()

            VStack(spacing: 0) {
                header

                ZStack {
                    switch page {
                    case 0: conceptPage
                    case 1: moodPage
                    default: widgetPage
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .id(page)
                .transition(pageTransition)

                pageIndicator
                    .padding(.bottom, 20)

                nextButton
            }
            .padding(.horizontal, 24)
            .padding(.top, 10)
            .padding(.bottom, 18)
        }
        .foregroundStyle(ink)
        .onAppear {
            if let preferred = WiseishContextStore.preferredMood,
               let mood = WiseishMood(rawValue: preferred) {
                selectedMood = mood
            }
        }
    }

    private var header: some View {
        HStack {
            HStack(spacing: 0) {
                Text("Wise")
                Text("–").foregroundStyle(mustard)
                Text("ish")
            }
            .font(.system(.title3, design: .serif, weight: .bold))

            Spacer()

            Button(page == 2 ? "あとで" : "スキップ") {
                finish()
            }
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(softInk)
            .buttonStyle(.plain)
        }
        .frame(height: 44)
    }

    private var conceptPage: some View {
        VStack(spacing: 20) {
            Image("Ish")
                .resizable()
                .scaledToFit()
                .frame(width: 190, height: 190)
                .rotationEffect(.degrees(-1.5), anchor: .bottom)
                .shadow(color: ink.opacity(0.08), radius: 6, y: 5)

            VStack(spacing: 12) {
                Text("一日ひとつ、\n答えのない日めくり。")
                    .font(.system(size: 27, weight: .bold, design: .serif))
                    .multilineTextAlignment(.center)
                    .lineSpacing(7)

                Text("少し考えて、少し笑って、\nだいたいそのままでよい。")
                    .font(.system(size: 13, weight: .medium, design: .serif))
                    .multilineTextAlignment(.center)
                    .lineSpacing(5)
                    .foregroundStyle(softInk)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var moodPage: some View {
        VStack(spacing: 20) {
            VStack(spacing: 7) {
                Text("今日は、どんな感じ？")
                    .font(.system(size: 25, weight: .bold, design: .serif))
                Text("最初の一枚を選ぶ手がかりにするぞ。")
                    .font(.system(size: 12, weight: .medium, design: .serif))
                    .foregroundStyle(softInk)
            }

            VStack(spacing: 9) {
                moodButton(.quiet, detail: "余白がほしい")
                moodButton(.foggy, detail: "まだ決めたくない")
                moodButton(.thinking, detail: "頭が働きすぎ")
            }
            .frame(maxWidth: 390)
        }
    }

    private func moodButton(_ mood: WiseishMood, detail: String) -> some View {
        let isSelected = selectedMood == mood
        return Button {
            withAnimation(.spring(duration: 0.28, bounce: 0.28)) {
                selectedMood = mood
            }
            WiseishContextStore.recordMood(mood.rawValue)
        } label: {
            HStack(spacing: 14) {
                Text(mood.symbol)
                    .font(.system(size: 25, design: .serif))
                    .frame(width: 38)

                VStack(alignment: .leading, spacing: 2) {
                    Text(mood.title)
                        .font(.system(size: 14, weight: .bold, design: .serif))
                    Text(detail)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(isSelected ? ink.opacity(0.7) : softInk)
                }

                Spacer()

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 18, weight: .semibold))
            }
            .padding(.horizontal, 17)
            .frame(maxWidth: .infinity, minHeight: 66)
            .background(isSelected ? mustard : lightPaper.opacity(0.55), in: RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(ink.opacity(0.14), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(mood.title)、\(detail)")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var widgetPage: some View {
        VStack(spacing: 22) {
            VStack(spacing: 7) {
                Text("Ishをホーム画面へ")
                    .font(.system(size: 25, weight: .bold, design: .serif))
                Text("アプリを開かぬ日も、そこにおる。")
                    .font(.system(size: 12, weight: .medium, design: .serif))
                    .foregroundStyle(softInk)
            }

            widgetMock

            VStack(alignment: .leading, spacing: 8) {
                onboardingGuideRow("1", "ホーム画面を長押し")
                onboardingGuideRow("2", "「編集」からWidgetを追加")
                onboardingGuideRow("3", "Wise-ishを検索")
            }
            .frame(maxWidth: 310)
        }
    }

    private var widgetMock: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 7) {
                HStack(spacing: 0) {
                    Text("Wise")
                    Text("–").foregroundStyle(mustard)
                    Text("ish")
                }
                .font(.system(size: 11, weight: .bold, design: .serif))

                Text("休むのも歩みのうちじゃ。\nわしは最初から休んでおる。")
                    .font(.system(size: 14, weight: .semibold, design: .serif))
                    .lineSpacing(3)

                Text("# 歩みについて")
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundStyle(softInk)
            }

            Spacer(minLength: 0)

            Image("Ish")
                .resizable()
                .scaledToFit()
                .frame(width: 72, height: 92)
        }
        .padding(16)
        .frame(maxWidth: 330, minHeight: 142)
        .background(lightPaper, in: RoundedRectangle(cornerRadius: 22))
        .overlay(RoundedRectangle(cornerRadius: 22).stroke(ink.opacity(0.12), lineWidth: 1))
        .shadow(color: ink.opacity(0.1), radius: 14, y: 8)
    }

    private func onboardingGuideRow(_ number: String, _ text: String) -> some View {
        HStack(spacing: 10) {
            Text(number)
                .font(.system(size: 10, weight: .bold, design: .serif))
                .frame(width: 25, height: 25)
                .background(mustard, in: Circle())
            Text(text)
                .font(.system(size: 12, weight: .semibold, design: .serif))
        }
    }

    private var pageIndicator: some View {
        HStack(spacing: 7) {
            ForEach(0..<3, id: \.self) { index in
                Capsule()
                    .fill(index == page ? ink : ink.opacity(0.18))
                    .frame(width: index == page ? 22 : 7, height: 7)
            }
        }
        .animation(.easeInOut(duration: 0.22), value: page)
        .accessibilityLabel("全3ページ中、\(page + 1)ページ目")
    }

    private var nextButton: some View {
        Button {
            if page < 2 {
                if page == 1 {
                    WiseishContextStore.recordMood(selectedMood.rawValue)
                }
                withAnimation(.easeInOut(duration: reduceMotion ? 0.15 : 0.3)) {
                    page += 1
                }
            } else {
                finish()
            }
        } label: {
            HStack {
                Text(page == 2 ? "今日の一枚を見る" : "次へ")
                Image(systemName: page == 2 ? "sun.max" : "arrow.right")
            }
            .font(.system(size: 14, weight: .semibold))
            .frame(maxWidth: .infinity, minHeight: 50)
            .foregroundStyle(lightPaper)
            .background(ink, in: RoundedRectangle(cornerRadius: 15))
        }
        .buttonStyle(.plain)
    }

    private var pageTransition: AnyTransition {
        guard !reduceMotion else { return .opacity }
        return .asymmetric(
            insertion: .move(edge: .trailing).combined(with: .opacity),
            removal: .move(edge: .leading).combined(with: .opacity)
        )
    }

    private func finish() {
        WiseishContextStore.recordMood(selectedMood.rawValue)
        onComplete()
    }
}

#Preview {
    WiseishOnboardingView {}
}
