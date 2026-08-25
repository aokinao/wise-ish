import SwiftUI

struct WiseishCollectionView: View {
    enum Section: String, CaseIterable, Identifiable {
        case history = "日々"
        case favorites = "好き"

        var id: Self { self }
    }

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @State private var selectedSection: Section = .history
    @State private var revision = 0

    private var paper: Color { colorScheme == .dark ? Color(red: 0.10, green: 0.10, blue: 0.09) : Color(red: 0.96, green: 0.92, blue: 0.85) }
    private var lightPaper: Color { colorScheme == .dark ? Color(red: 0.16, green: 0.15, blue: 0.13) : Color(red: 1.00, green: 0.98, blue: 0.94) }
    private var ink: Color { colorScheme == .dark ? Color(red: 0.92, green: 0.89, blue: 0.83) : Color(red: 0.16, green: 0.15, blue: 0.13) }
    private var softInk: Color { colorScheme == .dark ? Color(red: 0.68, green: 0.65, blue: 0.59) : Color(red: 0.44, green: 0.41, blue: 0.37) }
    private let mustard = Color(red: 0.85, green: 0.66, blue: 0.23)

    private var records: [WiseishQuoteRecord] {
        _ = revision
        let history = WiseishContextStore.quoteHistory()
        guard selectedSection == .favorites else { return history }
        return history.filter { WiseishContextStore.isFavorite(quoteID: $0.quoteID) }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                paper.ignoresSafeArea()

                VStack(spacing: 14) {
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
            .navigationTitle("過去の日々")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("閉じる") { dismiss() }
                }
            }
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
