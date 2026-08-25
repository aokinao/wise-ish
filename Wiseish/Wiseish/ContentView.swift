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
    var quotes: [WiseishQuote] {
        quotes(for: .now)
    }

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
    @State private var displayedQuote = WiseishMood.quiet.quotes[0]
    @State private var isFavorite = false
    @State private var isPoked = false
    @State private var ishMessage: String?
    @State private var pokeID = UUID()
    @State private var isFloating = false
    @State private var selectedReaction: WiseishReflectionReaction?
    @State private var previousDayReaction: WiseishReflectionReaction?
    @State private var contextReason: String?
    @State private var showsIshInput = false
    @State private var ishInputText = ""
    @State private var showsWidgetGuide = false
    @State private var showsSettings = false
    @State private var showsCollection = false
    @State private var sharePayload: WiseishSharePayload?
    @FocusState private var isIshInputFocused: Bool

    private let paper = Color(red: 0.96, green: 0.92, blue: 0.85)
    private let lightPaper = Color(red: 1.00, green: 0.98, blue: 0.94)
    private let ink = Color(red: 0.16, green: 0.15, blue: 0.13)
    private let softInk = Color(red: 0.44, green: 0.41, blue: 0.37)
    private let mustard = Color(red: 0.85, green: 0.66, blue: 0.23)

    private var currentQuote: WiseishQuote {
        displayedQuote
    }

    var body: some View {
        ZStack {
            paper.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    header
                    dateHeader
                    quoteSection
                    reflectionCard
                    actionBar
                }
                .padding(.horizontal, 22)
                .padding(.top, 8)
                .padding(.bottom, 36)
            }
        }
        .foregroundStyle(ink)
        .sheet(isPresented: $showsIshInput) { ishInputSheet }
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
        .sheet(isPresented: $showsCollection) {
            WiseishCollectionView()
        }
        .sheet(item: $sharePayload) { payload in
            WiseishActivityView(image: payload.image)
        }
        .onAppear {
            restorePersonalizedState()
            WiseishContextStore.recordUsage(.appOpened)
            refreshCatalogIfNeeded()
            detectWidgetInstallation()
            withAnimation(.easeInOut(duration: 3.2).repeatForever(autoreverses: true)) {
                isFloating = true
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                restorePersonalizedState()
                refreshCatalogIfNeeded()
                detectWidgetInstallation()
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

            Spacer()

            Button {
                WiseishContextStore.recordUsage(.collectionOpened)
                showsCollection = true
            } label: {
                Image(systemName: "books.vertical")
                    .font(.system(size: 14, weight: .semibold))
                    .frame(width: 36, height: 36)
                    .background(.white.opacity(0.18), in: Circle())
                    .overlay(Circle().stroke(ink.opacity(0.15), lineWidth: 1))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("履歴とお気に入りを見る")

            Button {
                WiseishContextStore.recordUsage(.settingsOpened)
                showsSettings = true
            } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 14, weight: .semibold))
                    .frame(width: 36, height: 36)
                    .background(.white.opacity(0.18), in: Circle())
                    .overlay(Circle().stroke(ink.opacity(0.15), lineWidth: 1))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("設定を開く")
        }
        .font(.system(.title2, design: .serif, weight: .bold))
    }

    private var dateHeader: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("TODAY, PERHAPS")
                .font(.system(size: 9, weight: .bold))
                .tracking(1.8)
                .foregroundStyle(softInk)

            HStack(alignment: .center, spacing: 12) {
                Text(Date.now, format: .dateTime.day(.twoDigits))
                    .font(.system(size: 60, weight: .regular, design: .serif))
                    .tracking(-4)

                VStack(alignment: .leading, spacing: 1) {
                    Text(Date.now.formatted(.dateTime.month(.abbreviated).locale(Locale(identifier: "en_US"))).uppercased())
                        .font(.system(size: 13, weight: .bold))
                    Text(Date.now.formatted(.dateTime.weekday(.wide).locale(Locale(identifier: "en_US"))).uppercased())
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(softInk)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 20)
    }

    private var quoteSection: some View {
        ZStack(alignment: .bottomTrailing) {
            quoteCard
                .padding(.bottom, 52)

            mascot
                .frame(width: 150)
                .offset(x: 13, y: 13)
        }
        .padding(.top, 14)
    }

    private var quoteCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("今日の WISE-ISH")
                .font(.system(size: 9, weight: .bold))
                .tracking(1.4)
                .foregroundStyle(softInk)

            if let contextReason {
                Text("あなた向け · \(contextReason)")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(mustard)
                    .padding(.top, 5)
            }

            if let previousDayReaction {
                Text(previousReplyMessage(for: previousDayReaction))
                    .font(.system(size: 9, weight: .semibold, design: .serif))
                    .foregroundStyle(softInk)
                    .padding(.top, 5)
            }

            Text(currentQuote.text)
                .font(.system(size: 25, weight: .semibold, design: .serif))
                .tracking(0.4)
                .lineSpacing(10)
                .frame(maxWidth: .infinity, minHeight: 104, alignment: .leading)
                .padding(.vertical, 13)

            Divider().overlay(ink.opacity(0.12))

            Text("# \(currentQuote.theme)")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(softInk)
            .padding(.top, 7)
        }
        .padding(.horizontal, 22)
        .padding(.top, 25)
        .padding(.bottom, 13)
        .background(lightPaper)
        .clipShape(.rect(cornerRadius: 10))
        .overlay(alignment: .top) {
            HStack {
                ForEach(0..<4, id: \.self) { _ in
                    Capsule()
                        .fill(mustard)
                        .frame(width: 8, height: 24)
                        .overlay(Capsule().stroke(ink, lineWidth: 2.5))
                        .rotationEffect(.degrees(8))
                }
            }
            .frame(maxWidth: .infinity)
            .offset(y: -12)
        }
        .shadow(color: ink.opacity(0.12), radius: 14, y: 8)
    }

    private var mascot: some View {
        ZStack(alignment: .topLeading) {
            if isPoked {
                Text(ishMessage ?? currentQuote.aside)
                    .font(.system(size: 11, weight: .semibold, design: .serif))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(lightPaper, in: UnevenRoundedRectangle(
                        topLeadingRadius: 12,
                        bottomLeadingRadius: 12,
                        bottomTrailingRadius: 4,
                        topTrailingRadius: 12
                    ))
                    .overlay {
                        UnevenRoundedRectangle(
                            topLeadingRadius: 12,
                            bottomLeadingRadius: 12,
                            bottomTrailingRadius: 4,
                            topTrailingRadius: 12
                        )
                        .stroke(ink.opacity(0.14), lineWidth: 1)
                    }
                    .offset(x: -36, y: -16)
                    .transition(.scale(scale: 0.8, anchor: .bottomTrailing).combined(with: .opacity))
                    .zIndex(2)
            }

            Image("Ish")
                .resizable()
                .scaledToFit()
                .contentShape(Rectangle())
                .offset(y: isFloating ? -4 : 1)
                .rotationEffect(.degrees(isPoked ? 5 : (isFloating ? 1.2 : -0.8)), anchor: .bottom)
                .scaleEffect(x: isPoked ? 0.98 : 1, y: isPoked ? 1.02 : 1, anchor: .bottom)
                .shadow(color: ink.opacity(0.09), radius: 5, y: 5)
                .onTapGesture { pokeIsh() }
                .accessibilityLabel("小さな仙人のIsh")
                .accessibilityAddTraits(.isButton)
        }
    }

    private var reflectionCard: some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "bubble.left.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(lightPaper)
                    .frame(width: 34, height: 34)
                    .background(ink, in: UnevenRoundedRectangle(
                        topLeadingRadius: 17,
                        bottomLeadingRadius: 6,
                        bottomTrailingRadius: 17,
                        topTrailingRadius: 17
                    ))

                VStack(alignment: .leading, spacing: 5) {
                    Text("ISHに返事")
                        .font(.system(size: 9, weight: .bold))
                        .tracking(1)
                        .foregroundStyle(softInk)

                    Text("この一枚、今日のそなたには効きそうかの？")
                        .font(.system(size: 13, weight: .semibold, design: .serif))
                        .lineSpacing(5)
                }
            }

            reactionBar

            Text(selectedReaction == nil
                 ? "返事は、明日の一枚にこっそり混ぜるぞ。"
                 : "覚えたぞ。明日は少しだけ、そなた寄りじゃ。")
                .font(.system(size: 9, weight: .medium, design: .serif))
                .foregroundStyle(softInk)
                .contentTransition(.opacity)

            if selectedReaction != nil {
                Button {
                    showsIshInput = true
                } label: {
                    Label("明日のIshに、もう少し話す", systemImage: "ellipsis.bubble")
                        .font(.system(size: 10, weight: .semibold, design: .serif))
                        .foregroundStyle(ink)
                }
                .buttonStyle(.plain)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(13)
        .background(.white.opacity(0.16), in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(ink.opacity(0.14), lineWidth: 1))
    }

    private var reactionBar: some View {
        HStack(spacing: 6) {
            reactionButton(.resonate, title: "効きそう")
            reactionButton(.leaveIt, title: "今日はむり")
            reactionButton(.unknown, title: "知らんけど")
        }
    }

    private func reactionButton(_ reaction: WiseishReflectionReaction, title: String) -> some View {
        let isSelected = selectedReaction == reaction
        return Button {
            react(to: reaction)
        } label: {
            Text(title)
                .font(.system(size: 9, weight: .semibold, design: .serif))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .frame(maxWidth: .infinity, minHeight: 34)
                .foregroundStyle(isSelected ? lightPaper : ink)
                .background(isSelected ? ink : lightPaper.opacity(0.6), in: Capsule())
                .overlay(Capsule().stroke(ink.opacity(isSelected ? 0 : 0.13), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Ishに「\(title)」と返す")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var actionBar: some View {
        HStack(spacing: 8) {
            Button {
                toggleFavorite()
            } label: {
                actionLabel(isFavorite ? "好き" : "残す", systemImage: isFavorite ? "heart.fill" : "heart")
            }
            .foregroundStyle(isFavorite ? mustard : ink)

            Button {
                createShareCard()
            } label: {
                actionLabel("共有", systemImage: "square.and.arrow.up")
            }

        }
        .buttonStyle(.plain)
        .padding(.top, 10)
        .padding(.bottom, 16)
    }

    private func actionLabel(_ title: String, systemImage: String) -> some View {
        VStack(spacing: 5) {
            Image(systemName: systemImage)
                .font(.system(size: 15, weight: .semibold))
            Text(title)
                .font(.system(size: 9, weight: .semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, minHeight: 52)
        .background(.white.opacity(0.18), in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(ink.opacity(0.13), lineWidth: 1))
    }

    private var ishInputSheet: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 5) {
                Label("明日のIshに一言", systemImage: "ellipsis.bubble")
                    .font(.system(.title3, design: .serif, weight: .bold))

                Text("まとまってなくてよい。明日の一枚へ、こっそり混ぜるぞ。")
                    .font(.system(size: 11, weight: .medium, design: .serif))
                    .foregroundStyle(softInk)
            }

            ZStack(alignment: .topLeading) {
                if ishInputText.isEmpty {
                    Text("例：会議ばかりで、もう何も考えたくない")
                        .font(.system(size: 12, design: .serif))
                        .foregroundStyle(softInk.opacity(0.72))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 14)
                        .allowsHitTesting(false)
                }

                TextEditor(text: $ishInputText)
                    .font(.system(size: 14, weight: .medium, design: .serif))
                    .scrollContentBackground(.hidden)
                    .padding(8)
                    .focused($isIshInputFocused)
                    .onChange(of: ishInputText) { _, value in
                        if value.count > 240 {
                            ishInputText = String(value.prefix(240))
                        }
                    }
            }
            .frame(height: 112)
            .background(paper, in: RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(ink.opacity(0.16), lineWidth: 1))

            HStack {
                Text("端末の外へは送りません")
                Spacer()
                Text("\(ishInputText.count) / 240")
            }
            .font(.system(size: 9, weight: .medium))
            .foregroundStyle(softInk)

            Button {
                submitIshInput()
            } label: {
                Label("Ishに預ける", systemImage: "arrow.down.heart")
                    .font(.system(size: 13, weight: .semibold))
                    .frame(maxWidth: .infinity, minHeight: 48)
                    .background(ink, in: RoundedRectangle(cornerRadius: 14))
                    .foregroundStyle(lightPaper)
            }
            .buttonStyle(.plain)
            .disabled(ishInputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .opacity(ishInputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.45 : 1)
        }
        .padding(22)
        .presentationDetents([.height(370)])
        .presentationDragIndicator(.visible)
        .onAppear {
            Task {
                try? await Task.sleep(for: .milliseconds(300))
                isIshInputFocused = true
            }
        }
    }

    private var widgetGuide: some View {
        VStack(alignment: .leading, spacing: 18) {
            Label("ホーム画面にIshを置く", systemImage: "square.grid.2x2")
                .font(.system(.title3, design: .serif, weight: .bold))

            guideRow(number: "1", text: "ホーム画面の何もない場所を長押し")
            guideRow(number: "2", text: "「編集」から「ウィジェットを追加」を選ぶ")
            guideRow(number: "3", text: "Wise-ishを検索し、好きなサイズを追加")

            Text("今日の一枚は、アプリとウィジェットで同じになります。")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(softInk)

            Button("わかった") {
                showsWidgetGuide = false
            }
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
        withAnimation(.spring(duration: 0.25, bounce: 0.55)) {
            isFavorite.toggle()
        }
        WiseishContextStore.recordFavorite(quoteID: currentQuote.id, isFavorite: isFavorite)
        if isFavorite { WiseishContextStore.recordUsage(.favoriteAdded) }
        WidgetCenter.shared.reloadTimelines(ofKind: "WiseishDailyWidget")
        if isFavorite { pokeIsh() }
    }

    private func pokeIsh(message: String? = nil) {
        let currentPokeID = UUID()
        pokeID = currentPokeID
        ishMessage = message ?? currentQuote.aside
        withAnimation(.spring(duration: 0.55, bounce: 0.48)) {
            isPoked = true
        }
        Task {
            try? await Task.sleep(for: .milliseconds(1_550))
            guard pokeID == currentPokeID else { return }
            withAnimation(.easeOut(duration: 0.22)) {
                isPoked = false
            }
            ishMessage = nil
        }
    }

    private func restorePersonalizedState() {
        let mood = WiseishMood(rawValue: WiseishContextStore.recommendedMood()) ?? .quiet
        let index = preferredIndex(for: mood.quotes)

        if let todayRecord = WiseishContextStore.quoteHistory().first(where: {
            Calendar.current.isDateInToday($0.shownAt)
        }) {
            displayedQuote = quote(from: todayRecord)
            isFavorite = WiseishContextStore.isFavorite(quoteID: displayedQuote.id)
            selectedReaction = WiseishContextStore.reflectionReaction(quoteID: displayedQuote.id)
            if let generated = WiseishContextStore.recentGeneratedQuote(),
               WiseishContextStore.generatedQuoteIsFromToday(),
               generated.catalogID == todayRecord.quoteID {
                contextReason = generated.contextReason
            } else if let context = WiseishContextStore.recentExternalContext(),
                      context.createdAt < todayRecord.shownAt {
                contextReason = context.reason
            } else {
                contextReason = nil
            }
            WidgetCenter.shared.reloadTimelines(ofKind: "WiseishDailyWidget")
            restorePreviousReplyHint()
            return
        }

        if let generated = WiseishContextStore.recentGeneratedQuote(),
           WiseishContextStore.generatedQuoteIsFromToday() {
            displayedQuote = quote(from: generated)
            contextReason = generated.contextReason
            isFavorite = WiseishContextStore.isFavorite(quoteID: displayedQuote.id)
            selectedReaction = WiseishContextStore.reflectionReaction(quoteID: displayedQuote.id)
            recordCurrentQuote()
            restorePreviousReplyHint()
            return
        }

        displayedQuote = mood.quotes[index]
        isFavorite = WiseishContextStore.isFavorite(quoteID: displayedQuote.id)
        selectedReaction = WiseishContextStore.reflectionReaction(quoteID: displayedQuote.id)
        contextReason = WiseishContextStore.recentExternalContext()?.reason
        recordCurrentQuote()
        restorePreviousReplyHint()
        WidgetCenter.shared.reloadTimelines(ofKind: "WiseishDailyWidget")
    }

    private func restorePreviousReplyHint() {
        let day = Calendar.current.ordinality(of: .day, in: .era, for: .now) ?? 0
        let shouldMention = WiseishContextStore.metDayCount() <= 3 || day.isMultiple(of: 4)
        previousDayReaction = shouldMention
            ? WiseishContextStore.previousDayReaction()
            : nil
    }

    private func previousReplyMessage(for reaction: WiseishReflectionReaction) -> String {
        switch reaction {
        case .resonate: "昨日の「効きそう」、少し覚えておるぞ。"
        case .leaveIt: "昨日は「今日はむり」じゃったな。今日は軽めじゃ。"
        case .unknown: "昨日も「知らんけど」じゃったな。わしもじゃ。"
        }
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
        let catalogTags = WiseishCatalogStore.currentCatalog().quotes
            .first(where: { $0.id == record.quoteID })?.tags ?? ["daily"]
        return WiseishQuote(
            id: record.quoteID,
            text: record.text,
            reflection: record.reflection,
            theme: record.theme,
            aside: record.aside,
            tags: catalogTags
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
        guard let image = WiseishShareCardRenderer.render(quote: currentQuote) else { return }
        WiseishContextStore.recordUsage(.shareCardCreated)
        sharePayload = WiseishSharePayload(image: image)
    }

    private func submitIshInput() {
        let input = ishInputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !input.isEmpty else { return }
        let context = WiseishContextClassifier.classify(input)
        WiseishContextStore.saveExternalContext(tags: context.tags, reason: context.reason)
        WiseishContextStore.recordUsage(.aiRequested)
        isIshInputFocused = false
        showsIshInput = false
        ishInputText = ""

        Task {
            try? await Task.sleep(for: .milliseconds(260))
            pokeIsh(message: "聞いたぞ。明日のわしに渡しておく。")

            let calendar = Calendar.current
            let tomorrow = calendar.date(
                byAdding: .day,
                value: 1,
                to: calendar.startOfDay(for: .now)
            ) ?? Date.now.addingTimeInterval(86_400)
            let mood = WiseishMood(
                rawValue: WiseishContextStore.recommendedMood(date: tomorrow)
            ) ?? .quiet
            let result = await WiseishLanguageModelService.generate(
                sourceText: input,
                mood: mood.title,
                date: tomorrow
            )
            if case .generated(let generated) = result {
                WiseishContextStore.saveGeneratedQuote(generated)
            }
        }
    }

    private func react(to reaction: WiseishReflectionReaction) {
        withAnimation(.spring(duration: 0.28, bounce: 0.35)) {
            selectedReaction = reaction
        }
        WiseishContextStore.recordReflectionReaction(
            reaction,
            quoteID: currentQuote.id,
            tags: currentQuote.tags
        )
        WiseishContextStore.recordUsage(.reflectionReacted)
        WidgetCenter.shared.reloadTimelines(ofKind: "WiseishDailyWidget")

        let message = switch reaction {
        case .resonate: "うむ。そなた、話が早いの。"
        case .leaveIt: "むりなら置いとけ。床は広いぞ。"
        case .unknown: "よい返事じゃ。わしも知らん。"
        }
        pokeIsh(message: message)
    }

    private func preferredIndex(for quotes: [WiseishQuote]) -> Int {
        WiseishContextStore.preferredIndex(
            candidateIDs: quotes.map(\.id),
            candidateTags: Dictionary(uniqueKeysWithValues: quotes.map { ($0.id, $0.tags) })
        )
    }

    private func refreshCatalogIfNeeded() {
        Task {
            guard await WiseishCatalogUpdater.shared.refreshIfNeeded() else { return }
            restorePersonalizedState()
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
