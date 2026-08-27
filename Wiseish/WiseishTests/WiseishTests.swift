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

    @Test func dailyQuoteCanSelectQuoteThatExistsOnlyInRemoteCatalog() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(secondsFromGMT: 0))
        let date = try #require(calendar.date(from: DateComponents(year: 2026, month: 8, day: 27)))
        let remoteOnly = WiseishCatalogQuote(
            id: "remote-only",
            mood: "quiet",
            text: "遠くの棚にも、今日がある。\n取りに行くかは、また考える。",
            theme: "遠さについて",
            aside: "今日は近い棚でよいのじゃ。",
            tags: ["daily"],
            isPremium: false,
            activeMonths: nil
        )
        let catalog = WiseishCatalog(schemaVersion: 1, catalogVersion: "2026-08-28.1", quotes: [remoteOnly])

        #expect(WiseishCatalogStore.dailyQuote(for: date, catalog: catalog, calendar: calendar).id == "remote-only")
    }

    @Test func dailyQuotePrefersUnseenQuotesAndThenReusesTheOldest() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(secondsFromGMT: 0))
        let date = try #require(calendar.date(from: DateComponents(year: 2026, month: 8, day: 27)))
        let quotes = (1...3).map { index in
            WiseishCatalogQuote(
                id: "quote-\(index)", mood: "quiet", text: "今日の棚には、\(index)がある。\n取るかどうかは、また考えるのじゃ。",
                theme: "棚", aside: "急がぬのじゃ。", tags: ["daily"], isPremium: false, activeMonths: nil
            )
        }
        let catalog = WiseishCatalog(schemaVersion: 1, catalogVersion: "2026-08-28.1", quotes: quotes)
        let first = WiseishCatalogStore.dailyQuote(for: date, catalog: catalog, shownQuoteDates: [:], calendar: calendar)
        let shown = [first.id: date]
        let second = WiseishCatalogStore.dailyQuote(for: date.addingTimeInterval(86_400), catalog: catalog, shownQuoteDates: shown, calendar: calendar)

        #expect(second.id != first.id)
        #expect(WiseishCatalogStore.dailyQuote(for: date, catalog: catalog, shownQuoteDates: shown, calendar: calendar).id == first.id)
        let allShown = ["quote-1": date, "quote-2": date.addingTimeInterval(-86_400), "quote-3": date.addingTimeInterval(-2 * 86_400)]
        #expect(WiseishCatalogStore.dailyQuote(for: date.addingTimeInterval(3 * 86_400), catalog: catalog, shownQuoteDates: allShown, calendar: calendar).id == "quote-3")
    }

    @Test func catalogUpdateRetriesAfterFailureBackoffInsteadOfWaitingADay() {
        let now = Date(timeIntervalSince1970: 10_000)
        let failedAt = now.addingTimeInterval(-16 * 60)

        #expect(WiseishCatalogUpdater.retryDelay(failureCount: 1) == 15 * 60)
        #expect(WiseishCatalogUpdater.shouldAttempt(
            now: now,
            lastSuccess: nil,
            lastFailure: failedAt,
            failureCount: 1,
            force: false
        ))
    }

    @Test func successfulCatalogUpdateKeepsTheNormalDailyInterval() {
        let now = Date(timeIntervalSince1970: 10_000)
        let succeededAt = now.addingTimeInterval(-23 * 60 * 60)

        #expect(!WiseishCatalogUpdater.shouldAttempt(
            now: now,
            lastSuccess: succeededAt,
            lastFailure: nil,
            failureCount: 0,
            force: false
        ))
        #expect(WiseishCatalogUpdater.shouldAttempt(
            now: now,
            lastSuccess: now.addingTimeInterval(-25 * 60 * 60),
            lastFailure: nil,
            failureCount: 0,
            force: false
        ))
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

    @Test func dayKeyUsesTheProvidedLocalCalendar() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "Asia/Tokyo"))
        let beforeMidnight = try #require(calendar.date(from: DateComponents(year: 2026, month: 8, day: 27, hour: 23, minute: 59)))
        let afterMidnight = try #require(calendar.date(from: DateComponents(year: 2026, month: 8, day: 28, hour: 0, minute: 1)))

        #expect(WiseishDayRollover.dayKey(for: beforeMidnight, calendar: calendar) == "1-2026-8-27")
        #expect(WiseishDayRollover.dayKey(for: afterMidnight, calendar: calendar) == "1-2026-8-28")
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

}
