import SwiftUI

struct WiseishCollectionView: View {
    enum Section: String, CaseIterable, Identifiable {
        case history = "日々"
        case favorites = "好き"

        var id: Self { self }
    }

    @Environment(\.dismiss) private var dismiss
    @State private var selectedSection: Section = .history
    @State private var revision = 0

    private let paper = Color(red: 0.96, green: 0.92, blue: 0.85)
    private let lightPaper = Color(red: 1.00, green: 0.98, blue: 0.94)
    private let ink = Color(red: 0.16, green: 0.15, blue: 0.13)
    private let softInk = Color(red: 0.44, green: 0.41, blue: 0.37)
    private let mustard = Color(red: 0.85, green: 0.66, blue: 0.23)

    private var records: [WiseishQuoteRecord] {
        _ = revision
        let history = WiseishContextStore.quoteHistory()
        guard selectedSection == .favorites else { return history }
        return history.filter { WiseishContextStore.isFavorite(quoteID: $0.quoteID) }
    }

    private var metDayCount: Int {
        _ = revision
        return WiseishContextStore.metDayCount()
    }

    var body: some View {
        NavigationStack {
            ZStack {
                paper.ignoresSafeArea()

                VStack(spacing: 14) {
                    milestoneCard

                    Picker("表示", selection: $selectedSection) {
                        ForEach(Section.allCases) { section in
                            Text(section.rawValue).tag(section)
                        }
                    }
                    .pickerStyle(.segmented)

                    if records.isEmpty {
                        emptyState
                    } else {
                        ScrollView(showsIndicators: false) {
                            LazyVStack(spacing: 10) {
                                ForEach(records) { record in
                                    recordCard(record)
                                }
                            }
                            .padding(.bottom, 24)
                        }
                    }

#if DEBUG
                    usageSummary
#endif
                }
                .padding(.horizontal, 18)
                .padding(.top, 8)
            }
            .foregroundStyle(ink)
            .navigationTitle("Ishと会った日々")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("閉じる") { dismiss() }
                }
            }
        }
    }

    private var milestoneCard: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                Text("Ishと会った日")
                    .font(.system(size: 11, weight: .bold, design: .serif))
                Spacer()
                Text("\(metDayCount)日")
                    .font(.system(size: 16, weight: .bold, design: .serif))
            }

            Text(milestoneMessage)
                .font(.system(size: 10, weight: .medium, design: .serif))
                .foregroundStyle(softInk)

            HStack(spacing: 5) {
                ForEach(0..<7, id: \.self) { index in
                    Capsule()
                        .fill(index < min(metDayCount, 7) ? mustard : ink.opacity(0.1))
                        .frame(maxWidth: .infinity, minHeight: 5, maxHeight: 5)
                }
            }

            Text("連続でなくてよい。休んだ日は、わしも休む。")
                .font(.system(size: 8, weight: .medium, design: .serif))
                .foregroundStyle(softInk.opacity(0.85))
        }
        .padding(14)
        .background(lightPaper.opacity(0.58), in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(ink.opacity(0.1), lineWidth: 1))
    }

    private var milestoneMessage: String {
        switch metDayCount {
        case 0: "最初の一枚は、まだ棚の外じゃ。"
        case 1: "まず一日。Ishはもう座っておる。"
        case 2: "あと一日会えば、少し顔を覚えるぞ。"
        case 3: "三日会ったの。そなたの返事も少し覚えた。"
        case 4...6: "七日ぶん並ぶと、ちいさな週になるぞ。"
        case 7: "七日会った。これで立派な、だいたい一週間じゃ。"
        default: "\(metDayCount)日ぶん、答えのない日が並んでおる。"
        }
    }

    private func recordCard(_ record: WiseishQuoteRecord) -> some View {
        VStack(alignment: .leading, spacing: 9) {
                HStack {
                    Text(record.shownAt, format: .dateTime.month().day().weekday(.abbreviated))
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(softInk)

                    Spacer()

                    Button {
                        let wasFavorite = WiseishContextStore.isFavorite(quoteID: record.quoteID)
                        WiseishContextStore.recordFavorite(quoteID: record.quoteID, isFavorite: !wasFavorite)
                        if !wasFavorite { WiseishContextStore.recordUsage(.favoriteAdded) }
                        revision += 1
                    } label: {
                        Image(systemName: WiseishContextStore.isFavorite(quoteID: record.quoteID) ? "heart.fill" : "heart")
                            .foregroundStyle(WiseishContextStore.isFavorite(quoteID: record.quoteID) ? mustard : softInk)
                            .frame(width: 30, height: 30)
                    }
                    .buttonStyle(.plain)
                }

                Text(record.text)
                    .font(.system(size: 17, weight: .semibold, design: .serif))
                    .lineSpacing(4)
                    .multilineTextAlignment(.leading)

                Text("# \(record.theme)")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(softInk)
        }
        .padding(15)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(lightPaper, in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(ink.opacity(0.1), lineWidth: 1))
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label(
                selectedSection == .favorites ? "まだ残していません" : "まだ会っていません",
                systemImage: selectedSection == .favorites ? "heart" : "calendar"
            )
        } description: {
            Text(selectedSection == .favorites ? "気に入った迷言の「残す」を押すと、ここに並びます。" : "今日の一枚から、少しずつ増えていきます。")
        }
        .foregroundStyle(softInk)
    }

#if DEBUG
    private var usageSummary: some View {
        DisclosureGroup("開発用・利用カウント") {
            let counts = WiseishContextStore.usageCounts()
            VStack(spacing: 6) {
                ForEach(WiseishUsageEvent.allCases, id: \.rawValue) { event in
                    HStack {
                        Text(event.rawValue)
                        Spacer()
                        Text("\(counts[event.rawValue, default: 0])")
                    }
                }
            }
            .font(.system(size: 10, design: .monospaced))
            .padding(.top, 8)
        }
        .font(.system(size: 11, weight: .semibold))
        .foregroundStyle(softInk)
        .padding(.bottom, 10)
    }
#endif
}
