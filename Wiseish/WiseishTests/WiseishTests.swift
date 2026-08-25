//
//  WiseishTests.swift
//  WiseishTests
//
//  Created by aoki nao on 2026/08/24.
//

import Foundation
import Testing
@testable import Wiseish

struct WiseishTests {
    @Test func catalogContainsOnlyValidEditedQuotes() throws {
        let catalog = WiseishCatalogStore.currentCatalog()

        try WiseishCatalogValidator.validate(catalog)
        #expect(catalog.quotes.count == 120)
        #expect(Set(catalog.quotes.map(\.id)).count == catalog.quotes.count)
    }

    @Test func contextClassifierFindsWorkAndRestWithoutKeepingOriginalText() {
        let context = WiseishContextClassifier.classify("会議続きで疲れたので休みたい")

        #expect(context.tags.contains("work"))
        #expect(context.tags.contains("rest"))
        #expect(context.reason == "仕事の気配が濃い日")
        #expect(!context.reason.contains("会議"))
    }

    @Test func seasonalQuotesOnlyAppearInTheirActiveMonths() throws {
        let snowQuote = try #require(
            WiseishCatalogStore.currentCatalog().quotes.first { $0.id == "quiet-25" }
        )
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(secondsFromGMT: 0))
        let january = try #require(calendar.date(from: DateComponents(year: 2026, month: 1, day: 15)))
        let august = try #require(calendar.date(from: DateComponents(year: 2026, month: 8, day: 15)))

        #expect(snowQuote.isActive(on: january, calendar: calendar))
        #expect(!snowQuote.isActive(on: august, calendar: calendar))
    }

    @Test func contextClassifierFallsBackToDaily() {
        let context = WiseishContextClassifier.classify("なんとなくぼんやり")

        #expect(context.tags == ["daily"])
        #expect(context.reason == "気になるものを拾った日")
    }
}
