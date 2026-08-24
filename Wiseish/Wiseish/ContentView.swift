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
        WiseishCatalogStore.currentCatalog().quotes
            .filter { $0.mood == rawValue }
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
    @State private var selectedMood: WiseishMood = .quiet
    @State private var quoteIndex = 0
    @State private var displayedQuote = WiseishMood.quiet.quotes[0]
    @State private var isFavorite = false
    @State private var isFlipping = false
    @State private var isPoked = false
    @State private var isFloating = false
    @State private var contextReason: String?
    @State private var isGeneratingQuote = false
    @State private var generationStatus: String?
    @State private var showsMoodPicker = false
    @State private var showsWidgetGuide = false
    @State private var showsCollection = false
    @State private var sharePayload: WiseishSharePayload?

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
                    actionBar
                    reflectionCard
                }
                .padding(.horizontal, 22)
                .padding(.top, 8)
                .padding(.bottom, 36)
            }
        }
        .foregroundStyle(ink)
        .sheet(isPresented: $showsMoodPicker) { moodPicker }
        .sheet(isPresented: $showsWidgetGuide) { widgetGuide }
        .sheet(isPresented: $showsCollection) {
            WiseishCollectionView { record in
                show(record)
            }
        }
        .sheet(item: $sharePayload) { payload in
            WiseishActivityView(image: payload.image)
        }
        .onAppear {
            restorePersonalizedState()
            WiseishContextStore.recordUsage(.appOpened)
            processPersonalizedQuoteIfNeeded()
            refreshCatalogIfNeeded()
            withAnimation(.easeInOut(duration: 3.2).repeatForever(autoreverses: true)) {
                isFloating = true
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                restorePersonalizedState()
                processPersonalizedQuoteIfNeeded()
                refreshCatalogIfNeeded()
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
                WiseishContextStore.recordUsage(.widgetGuideOpened)
                showsWidgetGuide = true
            } label: {
                Label("ウィジェット", systemImage: "square.grid.2x2")
                    .font(.system(size: 10, weight: .semibold))
                    .padding(.horizontal, 11)
                    .frame(height: 36)
                    .background(.white.opacity(0.18), in: Capsule())
                    .overlay(Capsule().stroke(ink.opacity(0.15), lineWidth: 1))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("ウィジェットの置き方を見る")
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

            if isGeneratingQuote {
                Text("Ish、考え中…")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(softInk)
                    .padding(.top, 4)
            } else if let generationStatus {
                Text(generationStatus)
                    .font(.system(size: 8, weight: .medium))
                    .foregroundStyle(softInk)
                    .padding(.top, 3)
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
        .rotation3DEffect(
            .degrees(isFlipping ? 88 : 0),
            axis: (x: 1, y: 0, z: 0),
            anchor: .top,
            perspective: 0.55
        )
        .opacity(isFlipping ? 0 : 1)
    }

    private var mascot: some View {
        ZStack(alignment: .topLeading) {
            if isPoked {
                Text(currentQuote.aside)
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
                .onTapGesture(perform: pokeIsh)
                .accessibilityLabel("小さな仙人のIsh")
                .accessibilityAddTraits(.isButton)
        }
    }

    private var reflectionCard: some View {
        HStack(alignment: .top, spacing: 12) {
            Text("?")
                .font(.system(size: 19, weight: .bold, design: .serif))
                .foregroundStyle(lightPaper)
                .frame(width: 34, height: 34)
                .background(ink, in: UnevenRoundedRectangle(
                    topLeadingRadius: 17,
                    bottomLeadingRadius: 6,
                    bottomTrailingRadius: 17,
                    topTrailingRadius: 17
                ))

            VStack(alignment: .leading, spacing: 5) {
                Text("今日の問い")
                    .font(.system(size: 9, weight: .bold))
                    .tracking(1)
                    .foregroundStyle(softInk)

                Text(currentQuote.reflection)
                    .font(.system(size: 13, weight: .semibold, design: .serif))
                    .lineSpacing(5)
                    .contentTransition(.opacity)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(13)
        .background(.white.opacity(0.16), in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(ink.opacity(0.14), lineWidth: 1))
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

            Button {
                showNextQuote()
            } label: {
                actionLabel("もう一枚", systemImage: "arrow.clockwise")
            }

            Button {
                showsMoodPicker = true
            } label: {
                actionLabel(selectedMood.title, systemImage: "slider.horizontal.3")
            }
        }
        .buttonStyle(.plain)
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

    private var moodPicker: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("今日は、どんな感じ？")
                .font(.system(.title3, design: .serif, weight: .bold))

            HStack(spacing: 8) {
                ForEach(WiseishMood.allCases) { mood in
                    Button {
                        select(mood)
                    } label: {
                        VStack(spacing: 5) {
                            Text(mood.symbol).font(.system(size: 24, design: .serif))
                            Text(mood.title).font(.system(size: 11, weight: .semibold))
                        }
                        .foregroundStyle(ink)
                        .frame(maxWidth: .infinity, minHeight: 72)
                        .background(selectedMood == mood ? mustard : paper, in: RoundedRectangle(cornerRadius: 14))
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(ink.opacity(0.16), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
            }

            HStack(spacing: 8) {
                Button {
                    showsMoodPicker = false
                } label: {
                    Text("この気分にする")
                        .font(.system(size: 12, weight: .semibold))
                        .frame(maxWidth: .infinity, minHeight: 48)
                        .background(paper, in: RoundedRectangle(cornerRadius: 14))
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(ink.opacity(0.16), lineWidth: 1))
                }

                Button {
                    showsMoodPicker = false
                    WiseishContextStore.recordUsage(.aiRequested)
                    processPersonalizedQuoteIfNeeded(force: true)
                } label: {
                    Label("Ishに頼む", systemImage: "sparkles")
                        .font(.system(size: 12, weight: .semibold))
                        .frame(maxWidth: .infinity, minHeight: 48)
                        .background(ink, in: RoundedRectangle(cornerRadius: 14))
                        .foregroundStyle(lightPaper)
                }
                .disabled(isGeneratingQuote)
            }
            .buttonStyle(.plain)

            Text("「Ishに頼む」は、端末内AIで今日に合う一枚を選びます。")
                .font(.system(size: 10))
                .foregroundStyle(softInk)
        }
        .padding(22)
        .presentationDetents([.height(310)])
        .presentationDragIndicator(.visible)
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

    private func select(_ mood: WiseishMood) {
        guard mood != selectedMood, !isFlipping else { return }
        WiseishContextStore.recordMood(mood.rawValue)
        let nextIndex = WiseishContextStore.preferredIndex(candidateIDs: mood.quotes.map(\.id))
        let nextQuote = mood.quotes[nextIndex]
        selectedMood = mood
        WiseishContextStore.recordUsage(.moodChanged)
        isFavorite = false
        flipQuote(to: nextQuote, index: nextIndex)
        WidgetCenter.shared.reloadTimelines(ofKind: "WiseishDailyWidget")
        Task {
            try? await Task.sleep(for: .milliseconds(360))
            pokeIsh()
        }
    }

    private func showNextQuote() {
        guard !isFlipping else { return }
        WiseishContextStore.recordSkip(quoteID: currentQuote.id)
        WiseishContextStore.recordUsage(.nextQuote)
        let nextIndex = (quoteIndex + 1) % selectedMood.quotes.count
        let nextQuote = selectedMood.quotes[nextIndex]
        isFavorite = false
        flipQuote(to: nextQuote, index: nextIndex)
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

    private func flipQuote(to nextQuote: WiseishQuote, index nextIndex: Int) {
        withAnimation(.easeIn(duration: 0.26)) {
            isFlipping = true
        }
        Task {
            try? await Task.sleep(for: .milliseconds(260))
            displayedQuote = nextQuote
            quoteIndex = nextIndex
            recordCurrentQuote()
            withAnimation(.spring(duration: 0.34, bounce: 0.18)) {
                isFlipping = false
            }
        }
    }

    private func pokeIsh() {
        withAnimation(.spring(duration: 0.55, bounce: 0.48)) {
            isPoked = true
        }
        Task {
            try? await Task.sleep(for: .milliseconds(1_550))
            withAnimation(.easeOut(duration: 0.22)) {
                isPoked = false
            }
        }
    }

    private func restorePersonalizedState() {
        let mood = WiseishMood(rawValue: WiseishContextStore.recommendedMood()) ?? .quiet
        let index = WiseishContextStore.preferredIndex(candidateIDs: mood.quotes.map(\.id))
        selectedMood = mood
        quoteIndex = index

        if let generated = WiseishContextStore.recentGeneratedQuote(),
           WiseishContextStore.generatedQuoteIsFromToday() {
            displayedQuote = quote(from: generated)
            contextReason = generated.contextReason
            generationStatus = nil
            isFavorite = WiseishContextStore.isFavorite(quoteID: displayedQuote.id)
            recordCurrentQuote()
            return
        }

        displayedQuote = mood.quotes[index]
        isFavorite = WiseishContextStore.isFavorite(quoteID: displayedQuote.id)
        contextReason = WiseishContextStore.recentExternalContext()?.reason
        recordCurrentQuote()
        WidgetCenter.shared.reloadTimelines(ofKind: "WiseishDailyWidget")
    }

    private func processPersonalizedQuoteIfNeeded(force: Bool = false) {
        guard !isGeneratingQuote else { return }
        let pendingInput = WiseishContextStore.pendingInput()
        guard force || pendingInput != nil else { return }

        isGeneratingQuote = true
        generationStatus = nil
        let mood = selectedMood.title

        Task {
            let result = await WiseishLanguageModelService.generate(
                sourceText: pendingInput?.text,
                mood: mood
            )

            switch result {
            case .generated(let generated):
                WiseishContextStore.saveGeneratedQuote(generated)
                WiseishContextStore.saveExternalContext(tags: generated.tags, reason: generated.contextReason)
                WiseishContextStore.clearPendingInput()
                contextReason = generated.contextReason
                generationStatus = nil
                let generatedQuote = quote(from: generated)
                if isFlipping {
                    displayedQuote = generatedQuote
                } else {
                    flipQuote(to: generatedQuote, index: quoteIndex)
                }
                WidgetCenter.shared.reloadTimelines(ofKind: "WiseishDailyWidget")

            case .failed(let message):
                generationStatus = "\(message) · 収録文から選択"
                WiseishContextStore.clearPendingInput()
            }
            isGeneratingQuote = false
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

    private func show(_ record: WiseishQuoteRecord) {
        displayedQuote = WiseishQuote(
            id: record.quoteID,
            text: record.text,
            reflection: record.reflection,
            theme: record.theme,
            aside: record.aside,
            tags: ["daily"]
        )
        isFavorite = WiseishContextStore.isFavorite(quoteID: record.quoteID)
        contextReason = nil
        generationStatus = nil
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

    private func refreshCatalogIfNeeded() {
        Task {
            guard await WiseishCatalogUpdater.shared.refreshIfNeeded() else { return }
            restorePersonalizedState()
            WidgetCenter.shared.reloadTimelines(ofKind: "WiseishDailyWidget")
        }
    }
}

#Preview {
    ContentView()
}
