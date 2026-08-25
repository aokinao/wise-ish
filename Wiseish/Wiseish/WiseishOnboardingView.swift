import SwiftUI

struct WiseishOnboardingView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("notification.daily.enabled") private var notificationEnabled = false
    @AppStorage("notification.daily.hour") private var notificationHour = 8
    @AppStorage("notification.daily.minute") private var notificationMinute = 0
    @State private var page = 0
    @State private var isEnablingNotification = false
    @State private var notificationWasDenied = false
    @State private var firstQuote: WiseishQuote

    let onComplete: () -> Void

    private var paper: Color { colorScheme == .dark ? Color(red: 0.10, green: 0.10, blue: 0.09) : Color(red: 0.96, green: 0.92, blue: 0.85) }
    private var lightPaper: Color { colorScheme == .dark ? Color(red: 0.16, green: 0.15, blue: 0.13) : Color(red: 1.00, green: 0.98, blue: 0.94) }
    private var ink: Color { colorScheme == .dark ? Color(red: 0.92, green: 0.89, blue: 0.83) : Color(red: 0.16, green: 0.15, blue: 0.13) }
    private var softInk: Color { colorScheme == .dark ? Color(red: 0.68, green: 0.65, blue: 0.59) : Color(red: 0.44, green: 0.41, blue: 0.37) }
    private let mustard = Color(red: 0.85, green: 0.66, blue: 0.23)

    init(onComplete: @escaping () -> Void) {
        self.onComplete = onComplete
        let mood = WiseishMood(rawValue: WiseishContextStore.recommendedMood()) ?? .quiet
        let quotes = mood.quotes
        let index = WiseishContextStore.preferredIndex(
            candidateIDs: quotes.map(\.id),
            candidateTags: Dictionary(uniqueKeysWithValues: quotes.map { ($0.id, $0.tags) })
        )
        _firstQuote = State(initialValue: quotes[index % quotes.count])
    }

    var body: some View {
        ZStack {
            paper.ignoresSafeArea()

            VStack(spacing: 0) {
                header

                ZStack {
                    switch page {
                    case 0: firstQuotePage
                    case 1: notificationPage
                    default: widgetPage
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .id(page)
                .transition(pageTransition)

                pageIndicator
                    .padding(.bottom, 18)

                nextButton
            }
            .padding(.horizontal, 24)
            .padding(.top, 10)
            .padding(.bottom, 18)
        }
        .foregroundStyle(ink)
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

            Button("あとで") { finish() }
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(softInk)
                .buttonStyle(.plain)
        }
        .frame(height: 44)
    }

    private var firstQuotePage: some View {
        VStack(spacing: 16) {
            VStack(spacing: 4) {
                Text("今日を、雑に眺める。")
                    .font(.system(size: 23, weight: .bold, design: .serif))
                Text("日付が分かれば、それでだいたい十分。")
                    .font(.system(size: 11, weight: .medium, design: .serif))
                    .foregroundStyle(softInk)
            }

            Text("毎日ひとつ、役に立たない哲学。")
                .font(.system(size: 10, weight: .semibold, design: .serif))
                .foregroundStyle(softInk)

            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .center, spacing: 10) {
                    Text("\(Calendar.current.component(.day, from: .now))")
                        .font(.system(size: 62, weight: .regular, design: .serif))
                        .tracking(-4)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(Calendar.current.component(.month, from: .now))月")
                            .font(.system(size: 17, weight: .bold, design: .serif))
                        Text(Date.now.formatted(.dateTime.weekday(.wide).locale(Locale(identifier: "ja_JP"))))
                            .font(.system(size: 11, weight: .semibold, design: .serif))
                    }

                    Spacer()
                }

                Text(WiseishDayFact.make(for: .now).text)
                    .font(.system(size: 11, weight: .semibold, design: .serif))
                    .foregroundStyle(softInk)

                Rectangle()
                    .fill(ink.opacity(0.1))
                    .frame(height: 1)

                Text(firstQuote.text)
                    .font(.system(size: 21, weight: .semibold, design: .serif))
                    .lineSpacing(7)
                    .frame(maxWidth: .infinity, minHeight: 86, alignment: .leading)

                Text(firstQuote.theme)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(softInk)
            }
            .padding(18)
            .background(lightPaper, in: RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(ink.opacity(0.12), lineWidth: 1))
            .shadow(color: ink.opacity(0.1), radius: 12, y: 7)

            HStack(alignment: .bottom, spacing: 8) {
                Text(firstQuote.aside)
                    .font(.system(size: 11, weight: .semibold, design: .serif))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 9)
                    .background(lightPaper.opacity(0.7), in: RoundedRectangle(cornerRadius: 13))

                Image("Ish")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 82, height: 92)
            }
        }
    }

    private var notificationPage: some View {
        VStack(spacing: 22) {
            Image("Ish")
                .resizable()
                .scaledToFit()
                .frame(width: 150, height: 150)
                .rotationEffect(.degrees(-1.5), anchor: .bottom)

            VStack(spacing: 8) {
                Text("今日になったら、置いておく。")
                    .font(.system(size: 25, weight: .bold, design: .serif))
                    .multilineTextAlignment(.center)

                Text("朝\(notificationHour)時ごろ、今日の分を\nIshが一度だけ置きにきます。")
                    .font(.system(size: 12, weight: .medium, design: .serif))
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .foregroundStyle(softInk)
            }

            Button {
                enableNotification()
            } label: {
                HStack(spacing: 9) {
                    if isEnablingNotification {
                        ProgressView().tint(lightPaper)
                    } else {
                        Image(systemName: "bell")
                    }
                    Text(isEnablingNotification ? "Ish、支度中…" : "今日の分を受け取る")
                }
                .font(.system(size: 13, weight: .semibold))
                .frame(maxWidth: 330, minHeight: 50)
                .foregroundStyle(lightPaper)
                .background(ink, in: RoundedRectangle(cornerRadius: 15))
            }
            .buttonStyle(.plain)
            .disabled(isEnablingNotification)

            if notificationWasDenied {
                Text("呼べなかったの。設定から、あとでも呼べるぞ。")
                    .font(.system(size: 10, weight: .medium, design: .serif))
                    .foregroundStyle(softInk)
            }
        }
    }

    private var widgetPage: some View {
        VStack(spacing: 20) {
            VStack(spacing: 7) {
                Text("今日をホーム画面へ")
                    .font(.system(size: 25, weight: .bold, design: .serif))
                Text("開かなくても、今日はそこにあります。")
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

                Text("\(Calendar.current.component(.month, from: .now))月\(Calendar.current.component(.day, from: .now))日")
                    .font(.system(size: 12, weight: .bold, design: .serif))

                Text(firstQuote.text)
                    .font(.system(size: 14, weight: .semibold, design: .serif))
                    .lineSpacing(3)
                    .lineLimit(3)

                Text("# \(firstQuote.theme)")
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
                move(to: page + 1)
            } else {
                finish()
            }
        } label: {
            HStack {
                Text(nextButtonTitle)
                Image(systemName: page == 2 ? "sun.max" : "arrow.right")
            }
            .font(.system(size: 14, weight: .semibold))
            .frame(maxWidth: .infinity, minHeight: 50)
            .foregroundStyle(page == 1 ? ink : lightPaper)
            .background(page == 1 ? lightPaper.opacity(0.65) : ink, in: RoundedRectangle(cornerRadius: 15))
            .overlay {
                if page == 1 {
                    RoundedRectangle(cornerRadius: 15).stroke(ink.opacity(0.14), lineWidth: 1)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private var nextButtonTitle: String {
        switch page {
        case 0: "まあ、眺めた"
        case 1: "通知はあとで"
        default: "今日の一枚へ"
        }
    }

    private var pageTransition: AnyTransition {
        guard !reduceMotion else { return .opacity }
        return .asymmetric(
            insertion: .move(edge: .trailing).combined(with: .opacity),
            removal: .move(edge: .leading).combined(with: .opacity)
        )
    }

    private func enableNotification() {
        guard !isEnablingNotification else { return }
        isEnablingNotification = true
        WiseishContextStore.recordUsage(.notificationPrompted)
        Task {
            let didSchedule = await WiseishNotificationService.requestAndSchedule(
                hour: notificationHour,
                minute: notificationMinute
            )
            notificationEnabled = didSchedule
            notificationWasDenied = !didSchedule
            isEnablingNotification = false
            if didSchedule {
                WiseishContextStore.recordUsage(.notificationEnabled)
                move(to: 2)
            }
        }
    }

    private func move(to nextPage: Int) {
        withAnimation(.easeInOut(duration: reduceMotion ? 0.15 : 0.3)) {
            page = nextPage
        }
    }

    private func finish() {
        WiseishContextStore.recordUsage(.onboardingCompleted)
        onComplete()
    }
}

#Preview {
    WiseishOnboardingView {}
}
