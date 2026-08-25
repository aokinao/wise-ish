import SwiftUI

struct WiseishOnboardingView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage("notification.daily.enabled") private var notificationEnabled = false
    @AppStorage("notification.daily.hour") private var notificationHour = 8
    @AppStorage("notification.daily.minute") private var notificationMinute = 0
    @State private var page = 0
    @State private var selectedReaction: WiseishReflectionReaction?
    @State private var isEnablingNotification = false
    @State private var notificationWasDenied = false
    @State private var firstQuote: WiseishQuote

    let onComplete: () -> Void

    private let paper = Color(red: 0.96, green: 0.92, blue: 0.85)
    private let lightPaper = Color(red: 1.00, green: 0.98, blue: 0.94)
    private let ink = Color(red: 0.16, green: 0.15, blue: 0.13)
    private let softInk = Color(red: 0.44, green: 0.41, blue: 0.37)
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
        VStack(spacing: 14) {
            VStack(spacing: 4) {
                Text("まず、今日の一枚じゃ。")
                    .font(.system(size: 23, weight: .bold, design: .serif))
                Text("説明より先に、会っておくかの。")
                    .font(.system(size: 11, weight: .medium, design: .serif))
                    .foregroundStyle(softInk)
            }

            ZStack(alignment: .bottomTrailing) {
                VStack(alignment: .leading, spacing: 12) {
                    Text(Date.now, format: .dateTime.month().day().weekday(.abbreviated))
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(softInk)

                    Text(firstQuote.text)
                        .font(.system(size: 22, weight: .semibold, design: .serif))
                        .lineSpacing(7)
                        .frame(maxWidth: .infinity, minHeight: 98, alignment: .leading)

                    Text("# \(firstQuote.theme)")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(softInk)
                }
                .padding(18)
                .padding(.trailing, 45)
                .background(lightPaper, in: RoundedRectangle(cornerRadius: 16))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(ink.opacity(0.12), lineWidth: 1))
                .shadow(color: ink.opacity(0.1), radius: 12, y: 7)

                Image("Ish")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 94, height: 112)
                    .offset(x: 10, y: 22)
            }

            VStack(spacing: 9) {
                Text(selectedReaction == nil
                     ? "この一枚、今日のそなたには効きそうかの？"
                     : onboardingReply)
                    .font(.system(size: 12, weight: .semibold, design: .serif))
                    .foregroundStyle(selectedReaction == nil ? ink : softInk)
                    .contentTransition(.opacity)

                HStack(spacing: 7) {
                    reactionButton(.resonate, title: "効きそう")
                    reactionButton(.leaveIt, title: "今日はむり")
                    reactionButton(.unknown, title: "知らんけど")
                }
            }
        }
    }

    private func reactionButton(_ reaction: WiseishReflectionReaction, title: String) -> some View {
        let isSelected = selectedReaction == reaction
        return Button {
            recordFirstReaction(reaction)
        } label: {
            Text(title)
                .font(.system(size: 10, weight: .semibold, design: .serif))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .frame(maxWidth: .infinity, minHeight: 40)
                .foregroundStyle(isSelected ? lightPaper : ink)
                .background(isSelected ? ink : lightPaper.opacity(0.65), in: Capsule())
                .overlay(Capsule().stroke(ink.opacity(isSelected ? 0 : 0.14), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Ishに「\(title)」と返す")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var onboardingReply: String {
        switch selectedReaction {
        case .resonate: "覚えたぞ。明日は少し、そなた寄りじゃ。"
        case .leaveIt: "むりなら置いとけ。明日は軽めにしておく。"
        case .unknown: "よい返事じゃ。明日のわしも、たぶん迷う。"
        case nil: ""
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
                Text("明日のIshも、呼ぶかの？")
                    .font(.system(size: 25, weight: .bold, design: .serif))
                    .multilineTextAlignment(.center)

                Text("朝\(notificationHour)時ごろ、今日とは違う一枚を\nIshが一度だけ知らせます。")
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
                    Text(isEnablingNotification ? "Ish、支度中…" : "明日、Ishを呼ぶ")
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
        .disabled(page == 0 && selectedReaction == nil)
        .opacity(page == 0 && selectedReaction == nil ? 0.38 : 1)
    }

    private var nextButtonTitle: String {
        switch page {
        case 0: "明日のことを決める"
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

    private func recordFirstReaction(_ reaction: WiseishReflectionReaction) {
        let isFirstReply = selectedReaction == nil
        withAnimation(.spring(duration: 0.28, bounce: 0.32)) {
            selectedReaction = reaction
        }
        WiseishContextStore.recordQuote(
            quoteID: firstQuote.id,
            text: firstQuote.text,
            reflection: firstQuote.reflection,
            theme: firstQuote.theme,
            aside: firstQuote.aside
        )
        WiseishContextStore.recordReflectionReaction(
            reaction,
            quoteID: firstQuote.id,
            tags: firstQuote.tags
        )
        WiseishContextStore.recordUsage(.reflectionReacted)
        if isFirstReply {
            WiseishContextStore.recordUsage(.onboardingReply)
        }
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
