# App Review Information（審査提出用ノート）

App Store Connect の「App Review Information > Notes」に貼る定型文です。
2026-08-31 の Guideline 2.1 - Information Needed 差し戻しへの回答として作成しました。
**毎回の提出で同じ内容を入れておく**ようレビュアーから指示されているため、リリースのたびに
この文面を Notes へ貼り直してください。

## 提出前チェック

- [ ] `[DEVICE MODEL]` を実際に検証した実機の機種名に置き換える
- [ ] 実機で撮った画面録画を Attachment 欄に添付する（起動から始めること。オンボーディング、通知許可ダイアログ、課金フロー、復元、ウィジェット、Siri を必ず含める）
- [ ] Sign-In Required は OFF のまま（アカウント機能が存在しないため）
- [ ] 機能を追加・削除したら、下記 4・5 の記述を実装と一致させる

## 記載内容の根拠

| 項目 | 実装上の根拠 |
| --- | --- |
| アカウント無し | ログイン・会員登録の実装が存在しない |
| 課金は買い切り1点 | `com.naoki.Wiseish.wordshelf`（NonConsumable）。サブスクリプションは無し |
| 外部通信は1つだけ | `WiseishCatalogUpdater.swift` の `https://aokinao.github.io/wise-ish/quotes.json` への匿名GETのみ |
| 権限は通知のみ | Info.plist に UsageDescription 系のキーが無い。`WiseishNotificationService` の通知許可のみ |
| 地域差なし | カタログ・課金プロダクトともに全ストアフロント共通 |
| 第三者著作物なし | `docs/content-guidelines.md` で実在人物への帰属・有名な名言の模倣を禁止している |

---

## 貼り付け用本文（英語）

```
Thank you for the review. Here is the requested information.

1. SCREEN RECORDING
A screen recording captured on a physical iPhone running iOS 26 is attached. It starts
from launching the app and covers the full user flow: onboarding, the notification
permission prompt, the main daily screen, the word shelf, the in-app purchase flow,
restore purchases, settings, the Home Screen widgets, and the Siri / App Intents
shortcut.

2. DEVICES AND OS TESTED
- [DEVICE MODEL] (physical device), iOS 26.0
- iPhone 17 Pro Simulator, iOS 26.0
Minimum deployment target: iOS 26.0.

3. APP FUNCTION AND TARGET AUDIENCE
Wise-ish is a "daily tear-off calendar" app. It shows today's date, a few small facts
about the day (day of the year, days remaining, percentage of the year and month
elapsed), and one short, gently philosophical line delivered by an original mascot
character named "Ish".

Problem it solves: many daily apps demand streaks, habits and management. Wise-ish is
deliberately the opposite. It gives the user a calm 3-to-10 second glance at today,
with no goals, no streaks and no tracking. The Home Screen widget alone is enough to
get the full experience without opening the app.

Target audience: general audience (age 4+), primarily Japanese-speaking adults who want
a low-pressure daily moment. There is no content requiring an age restriction.

4. HOW TO SET UP AND ACCESS THE MAIN FEATURES
No account, login or sample file is required. The app has no user accounts of any kind,
so no demo credentials are needed. All features are reachable immediately after launch:
- Launch the app and complete (or skip) the short onboarding.
- Main screen: today's date, the daily line, day metrics.
- Tap the shelf icon to open the word shelf, with tabs for recent days,
  favorites, and the full catalog.
- In-app purchase: the catalog tab shows a one-time non-consumable unlock
  (product ID: com.naoki.Wiseish.wordshelf, approx. JPY 500).
  This is NOT a subscription. It unlocks reading the full back catalog and the full
  history. Today's line and the widget are identical for free and paid users.
  "Restore purchases" is available both on that screen and in Settings.
- Widget: add the Small or Medium "Wise-ish" widget from the Home Screen gallery.
- Siri / Shortcuts: run the "今日のWise-ish" App Shortcut.

5. EXTERNAL SERVICES AND TOOLS
- Apple StoreKit 2 (in-app purchase) — the only payment processing, via Apple.
- A static JSON file hosted on GitHub Pages
  (https://aokinao.github.io/wise-ish/quotes.json) used only to refresh the editorial
  text catalog. It is an anonymous, read-only HTTPS GET. No user data is ever sent.
  The app ships with the same catalog bundled, so it works fully offline.
- No authentication service, no analytics SDK, no advertising SDK, no third-party
  data provider, and no AI or LLM service. All displayed text comes from a fixed,
  pre-edited catalog of human-written lines; nothing is generated at runtime.
- All user data (favorites, history, settings) is stored on device only, in the app's
  App Group container. Nothing is uploaded.
- The app requests only one permission: optional local notifications, for a single
  once-a-day reminder. It does not use location, contacts, camera, microphone,
  photos, or App Tracking Transparency.

6. REGIONAL DIFFERENCES
There are none. The app behaves identically in all regions and storefronts. Content is
in Japanese only, the same catalog is delivered everywhere, and the in-app purchase is
the same single non-consumable product in every storefront. There is no geo-gated,
region-specific or region-restricted content or feature.

7. REGULATED INDUSTRY / THIRD-PARTY MATERIAL
Not applicable. The app does not operate in a regulated industry (no health, finance,
gambling, medical or similar functionality). All text, the "Ish" character and all
artwork are original works created by the developer. The app contains no third-party
copyrighted material and no quotations from real people; our editorial guidelines
explicitly prohibit attributing lines to real individuals or imitating famous quotes.

Please let us know if anything further is needed.
```

## 画面録画の収録手順

実機（iOS 26）で1本撮り。起動から始めるのが必須条件です。

1. ホーム画面からアプリをタップして起動
2. オンボーディング。通知許可のダイアログを画面内で承諾するところまで映す
3. メイン画面。日付、今日の多分哲学、Ish、年・月の経過率
4. 言葉の棚を開き、「日々」「好き」「棚」タブを切り替える
5. 「棚」タブで購入導線。StoreKit のシート表示 → 購入完了 → 全枚表示 → 「以前の購入を復元する」
6. 設定。通知の ON/OFF と時刻変更
7. アプリを閉じてホーム画面へ。Small / Medium ウィジェットがアプリと同じ言葉を出していること
8. Siri または ショートカットで「今日のWise-ish」を実行
