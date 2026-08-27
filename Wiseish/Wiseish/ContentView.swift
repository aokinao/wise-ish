//
//  ContentView.swift
//  Wiseish
//
//  Created by aoki nao on 2026/08/24.
//

import SwiftUI
import WidgetKit

struct WiseishQuote: Identifiable, Equatable {
    let id: String
    let text: String
    let reflection: String
    let theme: String
    let aside: String
    let tags: [String]
}

enum WiseishMood: String, CaseIterable, Identifiable {
    case quiet
    case foggy
    case thinking

    var id: Self { self }

    var title: String {
        switch self {
        case .quiet: "静か"
        case .foggy: "ぼんやり"
        case .thinking: "考えすぎ"
        }
    }

    var symbol: String {
        switch self {
        case .quiet: "◌"
        case .foggy: "≈"
        case .thinking: "…"
        }
    }

    @MainActor
    var quotes: [WiseishQuote] { quotes(for: .now) }

    @MainActor
    func quotes(for date: Date) -> [WiseishQuote] {
        WiseishCatalogStore.currentCatalog().quotes
            .filter { $0.mood == rawValue && $0.isActive(on: date) }
            .map(WiseishQuote.init)
    }
}

private extension WiseishQuote {
    init(_ quote: WiseishCatalogQuote) {
        self.init(
            id: quote.id,
            text: quote.text,
            reflection: quote.reflection,
            theme: quote.theme,
            aside: quote.aside,
            tags: quote.tags
        )
    }
}

struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage("experience.lastSeenDay.v1") private var lastSeenDayKey = ""
    @State private var displayedQuote = WiseishMood.quiet.quotes[0]
    @State private var currentDate = Date.now
    @State private var isFavorite = false
    @State private var isPoked = false
    @State private var isFloating = false
    @State private var isDayRollover = false
    @State private var rolloverStep = 0
    @State private var rolloverMessage: String?
    @State private var outgoingQuote: WiseishQuote?
    @State private var hasPreparedDay = false
    @State private var showsWidgetGuide = false
    @State private var showsSettings = false
    @State private var showsCollection = false
    @State private var sharePayload: WiseishSharePayload?

    private let mustard = Color(red: 0.85, green: 0.66, blue: 0.23)

    private var paper: Color {
        colorScheme == .dark
            ? Color(red: 0.10, green: 0.10, blue: 0.09)
            : Color(red: 0.96, green: 0.92, blue: 0.85)
    }

    private var lightPaper: Color {
        colorScheme == .dark
            ? Color(red: 0.16, green: 0.15, blue: 0.13)
            : Color(red: 1.00, green: 0.98, blue: 0.94)
    }

    private var ink: Color {
        colorScheme == .dark
            ? Color(red: 0.91, green: 0.89, blue: 0.84)
            : Color(red: 0.16, green: 0.15, blue: 0.13)
    }

    private var softInk: Color {
        colorScheme == .dark
            ? Color(red: 0.66, green: 0.63, blue: 0.58)
            : Color(red: 0.44, green: 0.41, blue: 0.37)
    }

    private var currentQuote: WiseishQuote { displayedQuote }
    private var today: Date { currentDate }
    private var calendar: Calendar { .current }
    private var dayNumber: Int { calendar.component(.day, from: today) }
    private var monthNumber: Int { calendar.component(.month, from: today) }
    private var yearNumber: Int { calendar.component(.year, from: today) }
    private var weekday: String {
        today.formatted(.dateTime.weekday(.wide).locale(Locale(identifier: "ja_JP")))
    }

    var body: some View {
        ZStack {
            paper.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    header
                    dateHero
                    dayFact
                    quoteCard
                    ishCompanion
                    actionBar
                }
                .padding(.horizontal, 20)
                .padding(.top, 6)
                .padding(.bottom, 22)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        .foregroundStyle(ink)
        .sheet(isPresented: $showsWidgetGuide) { widgetGuide }
        .sheet(isPresented: $showsSettings) {
            WiseishSettingsView {
                Task {
                    try? await Task.sleep(for: .milliseconds(280))
                    WiseishContextStore.recordUsage(.widgetGuideOpened)
                    showsWidgetGuide = true
                }
            }
        }
        .sheet(isPresented: $showsCollection) { WiseishCollectionView() }
        .sheet(item: $sharePayload) { payload in WiseishActivityView(image: payload.image) }
        .onAppear {
            prepareDayState()
            WiseishContextStore.recordUsage(.appOpened)
            refreshCatalogIfNeeded()
            detectWidgetInstallation()
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 3.4).repeatForever(autoreverses: true)) {
                isFloating = true
            }
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            Task { await refreshForActiveDay() }
            refreshCatalogIfNeeded()
            detectWidgetInstallation()
        }
        .task(id: scenePhase) {
            guard scenePhase == .active else { return }
            await watchForDayRollover()
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            HStack(spacing: 0) {
                Text("Wise")
                Text("–").foregroundStyle(mustard)
                Text("ish")
            }
            .font(.system(.title3, design: .serif, weight: .bold))

            Text("今日を、雑に眺める。")
                .font(.system(size: 9, weight: .medium, design: .serif))
                .foregroundStyle(softInk)

            Spacer(minLength: 6)

            headerButton(systemImage: "books.vertical", label: "過去の日を見る") {
                WiseishContextStore.recordUsage(.collectionOpened)
                showsCollection = true
            }

            headerButton(systemImage: "gearshape", label: "設定を開く") {
                WiseishContextStore.recordUsage(.settingsOpened)
                showsSettings = true
            }
        }
        .frame(height: 42)
    }

    private func headerButton(
        systemImage: String,
        label: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 13, weight: .semibold))
                .frame(width: 32, height: 32)
                .background(lightPaper.opacity(0.48), in: Circle())
                .overlay(Circle().stroke(ink.opacity(0.12), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    private var dateHero: some View {
        HStack(alignment: .center, spacing: 14) {
            Text("\(dayNumber)")
                .font(.system(size: 88, weight: .regular, design: .serif))
                .tracking(-5)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
                .contentTransition(.numericText(value: Double(dayNumber)))
                .frame(width: 98, height: 112, alignment: .center)

            VStack(alignment: .leading, spacing: 3) {
                Text("\(monthNumber)月")
                    .font(.system(size: 22, weight: .bold, design: .serif))
                Text(weekday)
                    .font(.system(size: 14, weight: .semibold, design: .serif))
                Text("\(yearNumber)年")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(softInk)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, minHeight: 132, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(yearNumber)年\(monthNumber)月\(dayNumber)日 \(weekday)")
    }

    @ViewBuilder
    private var dayFact: some View {
        let metric = WiseishDailyMetric.make(for: today)
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                Text(metric.title)
                    .font(.system(size: 8, weight: .bold))
                    .tracking(1)
                    .foregroundStyle(softInk)
                Spacer()
                Text("意味は、まだない")
                    .font(.system(size: 9, weight: .semibold, design: .serif))
                    .foregroundStyle(softInk)
            }

            HStack(spacing: 14) {
                if let progress = metric.progress {
                    ZStack {
                        Circle()
                            .stroke(ink.opacity(0.1), lineWidth: 7)
                        Circle()
                            .trim(from: 0, to: progress)
                            .stroke(mustard.opacity(0.82), style: StrokeStyle(lineWidth: 7, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                        Text("\(Int(progress * 100))")
                            .font(.system(size: 12, weight: .bold, design: .serif))
                    }
                    .frame(width: 54, height: 54)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(metric.value)
                        .font(.system(size: 22, weight: .semibold, design: .serif))
                    Text(metric.detail)
                        .font(.system(size: 10, weight: .medium, design: .serif))
                        .foregroundStyle(softInk)
                        .lineLimit(2)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(lightPaper.opacity(0.48), in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(ink.opacity(0.1), lineWidth: 1))
    }

    private var quoteCard: some View {
        Group {
            // めくり中は古い紙だけを描画する。新しい紙を下に重ねると、
            // 同じ文言が二重に見えたり、差し替え時に古い紙が一瞬戻ったりする。
            if isDayRollover, let outgoingQuote {
                quoteSheet(for: outgoingQuote)
                    .rotation3DEffect(
                        .degrees(Double(pageTurnProgress) * -76),
                        axis: (x: 1, y: 0, z: 0),
                        anchor: .topTrailing,
                        perspective: 0.58
                    )
                    .rotationEffect(.degrees(Double(pageTurnProgress) * 3.5), anchor: .topTrailing)
                    .scaleEffect(1 - (pageTurnProgress * 0.06), anchor: .topTrailing)
                    .offset(
                        x: pageTurnProgress * 30,
                        y: pageTurnProgress * 94
                    )
                    .opacity(pageTurnOpacity)
                    .shadow(
                        color: Color.black.opacity(0.12 * pageTurnOpacity),
                        radius: 18,
                        x: -6,
                        y: 14
                    )
                    .allowsHitTesting(false)
            } else {
                quoteSheet(for: currentQuote)
            }
        }
        .padding(.top, 12)
    }

    private func quoteSheet(for quote: WiseishQuote) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("今日の、たぶん哲学")
                .font(.system(size: 9, weight: .bold))
                .tracking(1.3)
                .foregroundStyle(softInk)

            Text(quote.text)
                .font(.system(size: 25, weight: .semibold, design: .serif))
                .tracking(0.2)
                .lineSpacing(9)
                .frame(maxWidth: .infinity, minHeight: 106, alignment: .leading)
                .padding(.vertical, 12)

            Rectangle()
                .fill(ink.opacity(0.11))
                .frame(height: 1)

            Text(quote.theme)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(softInk)
                .padding(.top, 7)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 17)
        .background(lightPaper, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(ink.opacity(0.09), lineWidth: 1))
        .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.18 : 0.08), radius: 14, y: 7)
    }

    private var ishCompanion: some View {
        HStack(alignment: .bottom, spacing: 4) {
            Spacer(minLength: 4)

            VStack(alignment: .leading, spacing: 4) {
                Text(isDayRollover ? "Ishは、今日いちばん動いている" : "Ishは、考えすぎている")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(softInk)

                Text(rolloverMessage ?? currentQuote.aside)
                    .font(.system(size: 12, weight: .semibold, design: .serif))
                    .lineSpacing(3)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(lightPaper.opacity(0.76), in: UnevenRoundedRectangle(
                        topLeadingRadius: 14,
                        bottomLeadingRadius: 14,
                        bottomTrailingRadius: 4,
                        topTrailingRadius: 14
                    ))
                    .overlay {
                        UnevenRoundedRectangle(
                            topLeadingRadius: 14,
                            bottomLeadingRadius: 14,
                            bottomTrailingRadius: 4,
                            topTrailingRadius: 14
                        )
                        .stroke(ink.opacity(0.1), lineWidth: 1)
                    }
            }
            .padding(.bottom, 22)

            ZStack(alignment: .bottom) {
                Image("Ish")
                    .resizable()
                    .scaledToFit()
                    .opacity(isTurningPage ? 0 : 1)

                Image("IshTurningPage")
                    .resizable()
                    .scaledToFit()
                    .opacity(isTurningPage ? 1 : 0)
            }
                .frame(width: 112, height: 112, alignment: .bottom)
                .scaleEffect(ishRolloverTransform.scale, anchor: .bottom)
                .offset(
                    x: ishRolloverTransform.x,
                    y: ishRolloverTransform.y + (isFloating && !isDayRollover ? -3 : 1)
                )
                .rotationEffect(
                    .degrees(isDayRollover
                        ? ishRolloverTransform.rotation
                        : (isPoked ? 3.5 : (isFloating ? 0.7 : -0.5))),
                    anchor: .bottom
                )
                .contentShape(Rectangle())
                .onTapGesture {
                    guard !isDayRollover else { return }
                    pokeIsh()
                }
#if DEBUG
                .onLongPressGesture(minimumDuration: 0.8) {
                    Task { await previewDayRollover() }
                }
#endif
                .accessibilityLabel("今日を眺めているIsh")
                .accessibilityAddTraits(.isButton)
        }
        .frame(maxWidth: .infinity, minHeight: 122, alignment: .trailing)
    }

    private var actionBar: some View {
        HStack(spacing: 10) {
            Button {
                toggleFavorite()
            } label: {
                Label(isFavorite ? "残した" : "残す", systemImage: isFavorite ? "heart.fill" : "heart")
                    .foregroundStyle(isFavorite ? mustard : ink)
                    .frame(maxWidth: .infinity, minHeight: 42)
            }

            Button {
                createShareCard()
            } label: {
                Label("共有", systemImage: "square.and.arrow.up")
                    .foregroundStyle(ink)
                    .frame(maxWidth: .infinity, minHeight: 42)
            }
        }
        .font(.system(size: 11, weight: .semibold))
        .buttonStyle(.plain)
        .background(lightPaper.opacity(0.38), in: RoundedRectangle(cornerRadius: 13))
        .overlay(RoundedRectangle(cornerRadius: 13).stroke(ink.opacity(0.1), lineWidth: 1))
    }

    private var widgetGuide: some View {
        VStack(alignment: .leading, spacing: 18) {
            Label("ホーム画面に今日を置く", systemImage: "square.grid.2x2")
                .font(.system(.title3, design: .serif, weight: .bold))

            guideRow(number: "1", text: "ホーム画面の何もない場所を長押し")
            guideRow(number: "2", text: "「編集」から「ウィジェットを追加」を選ぶ")
            guideRow(number: "3", text: "Wise-ishを検索し、好きなサイズを追加")

            Text("日付と今日の、たぶん哲学は、アプリと同じものが置かれます。")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(softInk)

            Button("わかった") { showsWidgetGuide = false }
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(lightPaper)
                .frame(maxWidth: .infinity, minHeight: 46)
                .background(ink, in: RoundedRectangle(cornerRadius: 14))
                .buttonStyle(.plain)
        }
        .padding(22)
        .presentationDetents([.height(360)])
        .presentationDragIndicator(.visible)
    }

    private func guideRow(number: String, text: String) -> some View {
        HStack(spacing: 12) {
            Text(number)
                .font(.system(size: 12, weight: .bold, design: .serif))
                .frame(width: 30, height: 30)
                .background(mustard, in: Circle())
            Text(text)
                .font(.system(size: 13, weight: .semibold, design: .serif))
        }
    }

    private func toggleFavorite() {
        withAnimation(.spring(duration: 0.25, bounce: 0.4)) {
            isFavorite.toggle()
        }
        WiseishContextStore.recordFavorite(quoteID: currentQuote.id, isFavorite: isFavorite)
        if isFavorite { WiseishContextStore.recordUsage(.favoriteAdded) }
        WidgetCenter.shared.reloadTimelines(ofKind: "WiseishDailyWidget")
        if isFavorite { pokeIsh() }
    }

    private func pokeIsh() {
        withAnimation(.spring(duration: 0.55, bounce: 0.38)) {
            isPoked = true
        }
        Task {
            try? await Task.sleep(for: .milliseconds(800))
            withAnimation(.easeOut(duration: 0.25)) {
                isPoked = false
            }
        }
    }

    private func prepareDayState() {
        guard !hasPreparedDay else { return }
        hasPreparedDay = true

        let now = Date.now
        let todayKey = WiseishDayRollover.dayKey(for: now)
        guard !lastSeenDayKey.isEmpty else {
            currentDate = now
            restorePersonalizedState(for: now)
            lastSeenDayKey = todayKey
            return
        }

        if lastSeenDayKey != todayKey,
           let previousRecord = WiseishContextStore.quoteHistory().first(where: {
               WiseishDayRollover.dayKey(for: $0.shownAt) == lastSeenDayKey
           }) {
            currentDate = previousRecord.shownAt
            displayedQuote = quote(from: previousRecord)
            isFavorite = WiseishContextStore.isFavorite(quoteID: displayedQuote.id)
            Task {
                try? await Task.sleep(for: .milliseconds(650))
                await performDayRollover(to: now)
            }
            return
        }

        currentDate = now
        restorePersonalizedState(for: now)
        lastSeenDayKey = todayKey
    }

    private func refreshForActiveDay() async {
        guard hasPreparedDay else { return }
        let now = Date.now
        guard WiseishDayRollover.dayKey(for: currentDate) != WiseishDayRollover.dayKey(for: now) else {
            restorePersonalizedState(for: now)
            // アプリを開いた直後もWidgetへ現在日の再取得を依頼する。
            // WidgetKit側の古いTimelineが残っている場合の復帰点になる。
            WidgetCenter.shared.reloadTimelines(ofKind: "WiseishDailyWidget")
            return
        }
        await performDayRollover(to: now)
    }

    private func watchForDayRollover() async {
        while !Task.isCancelled {
            let now = Date.now
            let nextDay = WiseishDayRollover.nextStartOfDay(after: now)
            let delay = max(nextDay.timeIntervalSince(now), 0.25)
            do {
                try await Task.sleep(for: .seconds(delay))
            } catch {
                return
            }
            guard scenePhase == .active else { return }
            await refreshForActiveDay()
        }
    }

    private func performDayRollover(to date: Date) async {
        guard !isDayRollover else { return }
        isDayRollover = true
        outgoingQuote = currentQuote
        rolloverMessage = "ま、待て。日付が重い。"

        if reduceMotion {
            try? await Task.sleep(for: .milliseconds(320))
            withAnimation(.easeInOut(duration: 0.35)) {
                currentDate = date
                restorePersonalizedState(for: date)
                outgoingQuote = nil
                rolloverMessage = "日付が変わった。わしは特に変わっておらん。"
            }
        } else {
            // 一日で唯一の大仕事なので、気づく間と、めくった後の余韻を残す。
            try? await Task.sleep(for: .milliseconds(420))
            // 前日の紙が完全に画面から消えるまでは、日付も本文も更新しない。
            for step in 1...WiseishDayRollover.contentReplacementStep {
                withAnimation(.spring(duration: 0.2, bounce: 0.32)) {
                    rolloverStep = step
                }
                try? await Task.sleep(for: .milliseconds(180))
            }

            // 古い紙が不可視になったあと、カレンダーと本文を一つの更新として差し替える。
            withAnimation(.easeInOut(duration: 0.36)) {
                currentDate = date
                restorePersonalizedState(for: date)
                // 古い紙が消えた瞬間に表示対象を新しい紙へ切り替える。
                // めくり終了後まで outgoingQuote を残すと、旧文言が再表示される。
                outgoingQuote = nil
                rolloverMessage = "日付が変わった。わしは特に変わっておらん。"
            }
            try? await Task.sleep(for: .milliseconds(360))

            withAnimation(.spring(duration: 0.2, bounce: 0.24)) {
                rolloverStep = 12
            }
            try? await Task.sleep(for: .milliseconds(180))
        }

        lastSeenDayKey = WiseishDayRollover.dayKey(for: date)
        WidgetCenter.shared.reloadTimelines(ofKind: "WiseishDailyWidget")

        withAnimation(.spring(duration: 0.58, bounce: 0.28)) {
            rolloverStep = 0
        }
        try? await Task.sleep(for: .milliseconds(reduceMotion ? 420 : 580))
        isDayRollover = false
        outgoingQuote = nil
        try? await Task.sleep(for: .milliseconds(2_200))
        withAnimation(.easeOut(duration: 0.3)) {
            rolloverMessage = nil
        }
    }

#if DEBUG
    private func previewDayRollover() async {
        guard !isDayRollover,
              let previousDate = Calendar.current.date(byAdding: .day, value: -1, to: Date.now) else {
            return
        }

        currentDate = previousDate
        if let previousRecord = WiseishContextStore.quoteHistory().first(where: {
            Calendar.current.isDate($0.shownAt, inSameDayAs: previousDate)
        }) {
            displayedQuote = quote(from: previousRecord)
        } else {
            let mood = WiseishMood(rawValue: WiseishContextStore.recommendedMood(date: previousDate)) ?? .quiet
            let candidates = mood.quotes(for: previousDate)
            let index = preferredIndex(for: candidates, date: previousDate)
            displayedQuote = candidates[index % candidates.count]
        }

        try? await Task.sleep(for: .milliseconds(220))
        await performDayRollover(to: .now)
    }
#endif

    private var ishRolloverTransform: (x: CGFloat, y: CGFloat, rotation: Double, scale: CGFloat) {
        switch rolloverStep {
        case 1: (-7, -2, -6, 1.03)
        case 2: (11, -7, 9, 0.98)
        case 3: (-14, -3, -12, 1.07)
        case 4: (16, -12, 15, 0.96)
        case 5: (-17, -6, -15, 1.09)
        case 6: (14, -17, 13, 1.02)
        case 7: (-13, -22, -12, 1.14)
        case 8: (12, -14, 10, 1.07)
        case 9: (-9, -9, -8, 1.05)
        case 10: (7, -6, 6, 1.03)
        case 11: (-4, -3, -3, 1.02)
        case 12: (2, -1, 1.5, 1.01)
        default: (0, 0, 0, 1)
        }
    }

    private var isTurningPage: Bool {
        isDayRollover && rolloverStep >= 1 && rolloverStep <= 11
    }

    private var pageTurnProgress: CGFloat {
        CGFloat(WiseishDayRollover.pageTurnProgress(for: rolloverStep))
    }

    private var pageTurnOpacity: Double {
        WiseishDayRollover.pageTurnOpacity(for: rolloverStep)
    }

    private func restorePersonalizedState(for date: Date = .now) {
        let mood = WiseishMood(rawValue: WiseishContextStore.recommendedMood(date: date)) ?? .quiet
        let quotes = mood.quotes(for: date)

        if let todayRecord = WiseishContextStore.quoteHistory().first(where: {
            Calendar.current.isDate($0.shownAt, inSameDayAs: date)
        }) {
            displayedQuote = quote(from: todayRecord)
            isFavorite = WiseishContextStore.isFavorite(quoteID: displayedQuote.id)
            if Calendar.current.isDateInToday(date) { recordCurrentQuote() }
            WidgetCenter.shared.reloadTimelines(ofKind: "WiseishDailyWidget")
            return
        }

        if let generated = WiseishContextStore.recentGeneratedQuote(now: date),
           Calendar.current.isDate(generated.createdAt, inSameDayAs: date) {
            displayedQuote = quote(from: generated)
            isFavorite = WiseishContextStore.isFavorite(quoteID: displayedQuote.id)
            if Calendar.current.isDateInToday(date) { recordCurrentQuote() }
            return
        }

        let index = preferredIndex(for: quotes, date: date)
        displayedQuote = quotes[index % quotes.count]
        isFavorite = WiseishContextStore.isFavorite(quoteID: displayedQuote.id)
        if Calendar.current.isDateInToday(date) { recordCurrentQuote() }
        WidgetCenter.shared.reloadTimelines(ofKind: "WiseishDailyWidget")
    }

    private func quote(from generated: WiseishGeneratedQuote) -> WiseishQuote {
        WiseishQuote(
            id: generated.catalogID,
            text: generated.text,
            reflection: generated.reflection,
            theme: generated.theme,
            aside: generated.aside,
            tags: generated.tags
        )
    }

    private func quote(from record: WiseishQuoteRecord) -> WiseishQuote {
        let catalogQuote = WiseishCatalogStore.currentCatalog().quotes
            .first(where: { $0.id == record.quoteID })
        return WiseishQuote(
            id: record.quoteID,
            text: record.text,
            reflection: record.reflection,
            theme: record.theme,
            aside: record.aside,
            tags: catalogQuote?.tags ?? ["daily"]
        )
    }

    private func recordCurrentQuote() {
        WiseishContextStore.recordQuote(
            quoteID: currentQuote.id,
            text: currentQuote.text,
            reflection: currentQuote.reflection,
            theme: currentQuote.theme,
            aside: currentQuote.aside
        )
    }

    private func createShareCard() {
        guard let image = WiseishShareCardRenderer.render(quote: currentQuote, date: currentDate) else { return }
        WiseishContextStore.recordUsage(.shareCardCreated)
        sharePayload = WiseishSharePayload(image: image)
    }

    private func preferredIndex(for quotes: [WiseishQuote], date: Date = .now) -> Int {
        WiseishContextStore.preferredIndex(
            candidateIDs: quotes.map(\.id),
            candidateTags: Dictionary(uniqueKeysWithValues: quotes.map { ($0.id, $0.tags) }),
            date: date
        )
    }

    private func refreshCatalogIfNeeded() {
        Task {
            guard await WiseishCatalogUpdater.shared.refreshIfNeeded() else { return }
            restorePersonalizedState(for: currentDate)
            WidgetCenter.shared.reloadTimelines(ofKind: "WiseishDailyWidget")
        }
    }

    private func detectWidgetInstallation() {
        WidgetCenter.shared.getCurrentConfigurations { result in
            guard case .success(let configurations) = result,
                  configurations.contains(where: { $0.kind == "WiseishDailyWidget" }) else {
                return
            }
            WiseishContextStore.recordUsageOnce(.widgetInstalled)
        }
    }
}

#Preview {
    ContentView()
}
