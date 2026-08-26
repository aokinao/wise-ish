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

    @Test func catalogVersionsCompareNumericRevisions() {
        #expect(WiseishCatalogStore.isNewerCatalogVersion("2026-08-26.10", than: "2026-08-26.9"))
        #expect(!WiseishCatalogStore.isNewerCatalogVersion("2026-08-26.9", than: "2026-08-26.10"))
        #expect(WiseishCatalogStore.isNewerCatalogVersion("2026-08-27.1", than: "2026-08-26.99"))
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

    @Test func dayFactsUseTheCalendarDayWithoutNetworkData() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(secondsFromGMT: 0))
        let august25 = try #require(calendar.date(from: DateComponents(year: 2026, month: 8, day: 25)))
        let august26 = try #require(calendar.date(from: DateComponents(year: 2026, month: 8, day: 26)))

        #expect(WiseishDayFact.make(for: august25, calendar: calendar).text == "今年の237日目")
        #expect(WiseishDayFact.make(for: august26, calendar: calendar).text == "今年はあと127日")
    }

    @Test func dayRolloverUsesCalendarMidnightAcrossDaylightSavingTime() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "America/Los_Angeles"))
        let beforeSpringForward = try #require(
            calendar.date(from: DateComponents(year: 2026, month: 3, day: 7, hour: 23, minute: 59))
        )
        let nextDay = WiseishDayRollover.nextStartOfDay(
            after: beforeSpringForward,
            calendar: calendar
        )
        let components = calendar.dateComponents([.year, .month, .day, .hour], from: nextDay)

        #expect(components.year == 2026)
        #expect(components.month == 3)
        #expect(components.day == 8)
        #expect(components.hour == 0)
    }

    @Test func widgetTimelinePrecomputesFutureMidnights() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(secondsFromGMT: 0))
        let now = try #require(
            calendar.date(from: DateComponents(year: 2026, month: 8, day: 25, hour: 18))
        )
        let dates = WiseishDayRollover.timelineDates(from: now, daysAhead: 2, calendar: calendar)

        #expect(dates.count == 3)
        #expect(dates[0] == now)
        #expect(calendar.component(.day, from: dates[1]) == 26)
        #expect(calendar.component(.hour, from: dates[1]) == 0)
        #expect(calendar.component(.day, from: dates[2]) == 27)
    }

    @Test func dayContentChangesOnlyAfterThePreviousPageIsInvisible() {
        let replacementStep = WiseishDayRollover.contentReplacementStep

        #expect(WiseishDayRollover.pageTurnOpacity(for: replacementStep - 1) > 0)
        #expect(WiseishDayRollover.pageTurnProgress(for: replacementStep) == 1)
        #expect(WiseishDayRollover.pageTurnOpacity(for: replacementStep) == 0)
    }

    @Test func contextClassifierFallsBackToDaily() {
        let context = WiseishContextClassifier.classify("なんとなくぼんやり")

        #expect(context.tags == ["daily"])
        #expect(context.reason == "気になるものを拾った日")
    }
}
