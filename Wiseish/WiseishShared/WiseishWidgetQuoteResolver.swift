import Foundation

struct WiseishWidgetQuote: Equatable {
    let id: String
    let mood: String
    let text: String
    let theme: String
    let tags: [String]
}

enum WiseishWidgetQuoteResolver {
    static func quote(
        for date: Date,
        bundle: Bundle = .main,
        calendar: Calendar = .current
    ) -> WiseishWidgetQuote {
        quote(
            for: date,
            sharedRecord: WiseishContextStore.widgetQuote(for: date),
            catalog: WiseishCatalogStore.currentCatalog(bundle: bundle),
            shownQuoteDates: WiseishContextStore.shownQuoteDates(),
            calendar: calendar
        )
    }

    static func quote(
        for date: Date,
        sharedRecord: WiseishQuoteRecord?,
        catalog: WiseishCatalog,
        shownQuoteDates: [String: Date],
        calendar: Calendar = .current
    ) -> WiseishWidgetQuote {
        if let sharedRecord, calendar.isDate(sharedRecord.shownAt, inSameDayAs: date) {
            return WiseishWidgetQuote(
                id: sharedRecord.quoteID,
                mood: "daily",
                text: sharedRecord.text,
                theme: sharedRecord.theme,
                tags: ["daily"]
            )
        }

        let catalogQuote = WiseishCatalogStore.dailyQuote(
            for: date,
            catalog: catalog,
            shownQuoteDates: shownQuoteDates,
            calendar: calendar
        )
        return WiseishWidgetQuote(
            id: catalogQuote.id,
            mood: catalogQuote.mood,
            text: catalogQuote.text,
            theme: catalogQuote.theme,
            tags: catalogQuote.tags
        )
    }
}
