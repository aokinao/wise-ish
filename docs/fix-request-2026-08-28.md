# Wise-ish 修正依頼書

依頼日: 2026-08-28
前提資料: [REVIEW_ACTION_ITEMS.md](../REVIEW_ACTION_ITEMS.md)（2026-08-27時点のレビュー）

この文書は、別の担当者やAIへそのまま渡して修正を依頼するためのものです。
各項目は「対象 / 問題 / 修正方針 / 完了条件」で独立しており、上から順に着手できます。

## 先に共有する前提

`REVIEW_ACTION_ITEMS.md` の指摘のうち、以下は**すでに修正済み**です。重複して着手しないでください。

| 旧項目 | 現状 |
| --- | --- |
| P1 カタログ内容次第で起動時にクラッシュ | 解消。`WiseishCatalogStore.dailyQuote(for:)` が空候補時に `fallbackCatalog` を返し、`WiseishOnboardingView.init` も `quotes.isEmpty` を判定している |
| P1 年・月の経過率が100分の1で表示される | 解消。`WiseishDailyMetric.swift:186` の `percentage(_:)` が100倍している |
| P2 アプリ未起動日はWidgetとアプリの一言が一致しない | ほぼ解消。アプリ・Widget・App Intentの3経路が `dailyQuote(for:)` を共有している |

未修正のまま残っているのは、旧 P2「オンデバイスLLMが到達不能」、旧 P2「日付キーがUTC基準」、旧 P3「カタログ更新の再試行」です。本書ではそれぞれ C-1 / B-1 / C-2 として再掲します。

---

## A-1（最優先）リモートカタログが今日の一枚に反映されない

### 対象

- `Wiseish/WiseishShared/WiseishCatalog.swift`
- `Wiseish/Wiseish/WiseishSettingsView.swift`

### 問題

`dailyQuote(for:bundle:calendar:)` はカタログを次の順で解決している。

```swift
let catalog = bundledCatalog(bundle: bundle) ?? currentCatalog(bundle: bundle)
```

`bundledCatalog` はアプリに同梱された `quotes.json` を読むだけなので、通常は必ず成功する。つまり**`currentCatalog()` には到達せず、App Group にキャッシュされたリモートカタログは今日の一枚の選択に一度も使われない**。

一方 `currentCatalog()` 自体は、キャッシュとバンドルの `catalogVersion` を比較して新しい方を返す正しい実装になっている（`WiseishCatalog.swift:92`）。そしてこの `currentCatalog()` を使っているのは、設定画面の枚数表示とカタログ版数表示（`WiseishSettingsView.swift:164,173`）である。

結果として、次の状態が起きる。

- GitHub Pages のカタログを更新しても、ユーザーに表示される言葉は永久に変わらない
- それにもかかわらず、設定画面の「言葉の棚 ◯枚」と「カタログ ◯◯」はリモートの値を表示する
- つまり**更新されたように見えて、中身は変わっていない**

`docs/catalog.md` に定めたカタログ運用（PR → 検証 → GitHub Pages 配信）と、`WiseishCatalogUpdater` の実装が、まるごと空回りしている。日めくりアプリにとってコンテンツ供給経路は生命線なので、これを最優先とする。

### 修正方針

`dailyQuote(for:bundle:calendar:)` のカタログ解決を `currentCatalog(bundle:)` へ統一する。

- キャッシュが壊れている・読めない場合は `currentCatalog()` 内部で従来どおりバンドルへフォールバックするため、安全性は下がらない
- バンドル優先にした経緯（コミット `273f0f7` の「Widgetの描画パス簡素化」）を確認し、Widget から App Group のキャッシュを読めない事情があったのかを先に確かめる
- Widget 側で App Group のファイル読み取りが不安定な場合は、キャッシュ読み取りを一度だけ試し、失敗時に即バンドルへ落とす形にする。Widget を無条件にバンドル固定へ戻す対応は取らない（アプリと不一致になるため）

### 完了条件

- リモートカタログにのみ存在するIDが、今日の一枚として選ばれ得る
- キャッシュが壊れている、または存在しない場合もバンドル版で正常に表示される
- 同じ日付で、アプリ・Widget・App Intent が同じ quote ID を返す（実機でWidgetを含めて確認する）
- 設定画面が表示する枚数・版数と、実際に選択対象となる候補集合が一致する
- リモート版のみのIDを含むテストカタログで `dailyQuote` がそれを選び得ることのユニットテストを追加する

---

## A-2（最優先）表示済みの言葉が重複する仕組みになっている

### 対象

- `Wiseish/WiseishShared/WiseishCatalog.swift`
- `Wiseish/WiseishShared/WiseishContextStore.swift`

### 問題

`dailyQuote` の選択は次の一行に集約されている。

```swift
return candidates[abs(day) % candidates.count]
```

カタログは現在120枚なので、**120日で必ず一巡し、以後は同じ順序で同じ言葉が繰り返される**。表示済みの履歴は `WiseishContextStore.quoteHistory()` に最大100件保持されているが、選択処理はこれを一切参照していない。

日めくりアプリで最も体験を壊すのは「これ、前に見た」であり、それが起きた瞬間に「毎日そこにある」は「使い回している」に変わる。

**これをリリース前に入れる必要がある理由**は、影響が出るのが数ヶ月後だからではなく、逆である。重複回避には「これまで何を表示したか」の記録が要る。リリース後に追加すると、既存ユーザーは記録が空の状態から始まるため、一巡目の重複をどのみち防げない。記録の仕組みだけでも先に入れる。

### 修正方針

1. `WiseishContextStore` に、全期間の表示済み quote ID を保持する領域を追加する
   - 既存の `quoteHistory()`（100件上限）とは別に、ID と最終表示日だけの軽い辞書として持つ
   - `recordShownQuote` から同時に更新する
   - App Group の `UserDefaults` に置き、Widget からも読めるようにする
2. `dailyQuote(for:bundle:calendar:)` を、表示済み集合を考慮する決定的な選択へ拡張する
   - active な候補のうち、未表示のものを優先する
   - 未表示候補の中から `abs(day) % 未表示候補数` で選ぶ（決定性を維持する）
   - 未表示が0件になったら、最後に表示した日が最も古いものから選ぶ
   - 表示済み集合が空でも、現在と同じ結果になること（初回起動時の互換性）
3. アプリ・Widget・App Intent の3経路が、同じ App Group のデータを入力として同じ結果を返すことを維持する
   - 当日分が確定・保存されたあとは、既存の `widgetQuote(for:)` が優先されるため一致は崩れない
   - 確定前に Widget が先に描画する場合も、両者が同じ表示済み集合を読むため一致する

既存の `preferredIndex` によるスコアリングは、この選択には持ち込まない（C-1 参照）。

### 完了条件

- 日付を120日連続で進めても、同じ quote ID が二度選ばれない
- 121日目以降は、最も古く表示した言葉から順に再登場する
- 表示済み集合が空の場合、変更前と同じ言葉が選ばれる
- 同じ日付でアプリ・Widget・App Intent が同じ quote ID を返す
- 季節限定候補（`activeMonths`）と候補0件のケースを含むユニットテストを追加する

---

## A-3（最優先）App Store 説明文に未実装機能が記載されている

### 対象

- `docs/app-store-listing-ja.md`

### 問題

概要（説明）の箇条書きに次の行がある。

> ・対応端末では、端末内AIによるIshらしい言い換え

しかし `WiseishLanguageModelService.generate` はリポジトリ内に呼び出し元がなく（C-1 参照）、この機能は動作しない。未提供の機能をストア掲載文に書いている状態であり、審査上も表記上もリスクになる。

### 修正方針

- 当該の1行を削除する
- 同ファイルの「審査提出前チェック」に、掲載文の全機能が実機で確認できることを追加する
- `README.md` と `docs/mvp.md` の「オンデバイスLLM」記述も、C-1 の判断結果に合わせて整合させる

### 完了条件

- ストア掲載文に、実機で確認できない機能の記述がない
- README / MVP / 掲載文の3つで、AI関連の記述が矛盾していない

---

## B-1 日付キーの一部がUTC基準になっている

（`REVIEW_ACTION_ITEMS.md` の旧P2を再掲。未修正）

### 対象

- `Wiseish/WiseishShared/WiseishContextStore.swift:348`
- `Wiseish/WiseishShared/WiseishContextStore.swift:402`

### 問題

```swift
private static func dayKey(for date: Date) -> String {
    date.formatted(.iso8601.year().month().day())
}
```

`.iso8601` はデフォルトでUTC基準になる。Asia/Tokyo の 2026-08-27 01:00 は `2026-08-26` として扱われるため、気分や反応の有効期限が日本時間の午前9時に切り替わる。`reflectionKey` も同じ問題を持つ。

同じファイル内の日次判定は `WiseishDayRollover.dayKey(for:)`（ローカルカレンダー基準）を使っており、2種類の日付キーが混在している。

### 修正方針

- `WiseishDayRollover.dayKey(for:calendar:)` に統一する
- 旧キーで保存済みのデータがある場合は、一度だけ読み出して新キーへ移行する

### 完了条件

- Asia/Tokyo の0時前後で、キーがローカル日付どおりに切り替わる
- DSTのあるタイムゾーンでも、ローカルの0時で切り替わる
- タイムゾーン変更時の期待動作を、テストまたは仕様として記載する

---

## C-1 使われていないパーソナライズ層とLLM層を整理する

### 対象

- `Wiseish/Wiseish/WiseishLanguageModelService.swift`（243行）
- `Wiseish/WiseishShared/WiseishContextStore.swift`
- `Wiseish/Wiseish/WiseishOnboardingView.swift`
- `Wiseish/Wiseish/ContentView.swift:28-58`（`WiseishMood`）

### 問題

日々の一枚は `dailyQuote(for:)` によって日付から決定的に選ばれている。その結果、以下が実質的に使われていない。

- `WiseishLanguageModelService.generate` — 呼び出し元がゼロ
- `WiseishContextStore` の `preferredIndex` / `recommendedMood` / `recordSkip` / `recordReflectionReaction` / `recentExternalContext` / タグスコア / 反応スコア — 実際に到達するのは `WiseishOnboardingView.init` の初回1枚のみ
- `WiseishMood`（quiet / foggy / thinking）— ユーザーが選ぶUIはなく、`dailyQuote` も mood を区別しない

つまり**初回起動の1枚だけがパーソナライズされ、2日目以降は完全に決定的**という、説明できない状態になっている。加えて `preferredIndex` はお気に入りに `+3` の加点をするため、初回に限っては「お気に入りが再登場しやすい」挙動が残っている。

死にコードが多いこと自体より、**仕様が2つ同居していて、どちらが正なのか読み取れない**ことが問題である。

### 修正方針

「今日の一枚は日付から決定的に決める」を正式な仕様として確定し、それに合わせて整理する。この方針を採る理由は次のとおり。

- `docs/product-brief.md` の「正しい答えや自己改善を押しつけない」「ユーザーを診断しない」と整合する
- アプリ・Widget・App Intent の一致が、施策ではなく構造として保証される
- 全ユーザーが同じ日に同じ一枚を見るため、共有した言葉が会話として成立する

作業内容:

1. `WiseishOnboardingView.init` の初回1枚も `dailyQuote(for:)` に置き換える
2. 到達しなくなる `preferredIndex` などのパーソナライズAPIを削除する（お気に入り・履歴・通知設定の保存は残す）
3. `WiseishLanguageModelService` を削除するか、明示的に「MVP対象外」として扱いを決める
   - 生成による言い換えは、`docs/ish-character-bible.md` の品質基準（25〜65文字、論理をずらさない）を最も壊しやすいため、当面は入れない方針を推奨する
   - AIを使うなら、実行時ではなくカタログ執筆時の下書き用途に寄せる
4. `WiseishMood` を、ユーザー向け概念ではなくカタログ内の分類として扱うことを明記する
5. `README.md` / `docs/mvp.md` の該当記述を更新する（A-3 と合わせて実施する）

削除ではなく残す判断をする場合は、「いつ・何が・どの経路で使われるか」をコメントまたはドキュメントに明記すること。

### 完了条件

- 今日の一枚を決める経路が1つだけになっている
- 初回起動から2日目以降まで、選択規則が一貫している
- リポジトリ内に呼び出し元のない公開APIが残っていない、または残す理由が明記されている
- README / MVP / ストア掲載文の記述が実装と一致している

---

## C-2 カタログ更新が失敗後24時間再試行されない

（`REVIEW_ACTION_ITEMS.md` の旧P3を再掲。未修正）

### 対象

- `Wiseish/Wiseish/WiseishCatalogUpdater.swift`

### 問題

```swift
defaults.set(now, forKey: lastAttemptKey)
```

を通信開始**前**に保存しているため、オフラインや一時的な失敗でも以後24時間は再試行しない。朝に一度オフラインで起動しただけで、その日の更新機会を失う。

A-1 でリモートカタログが実際に使われるようになると、この問題の影響が初めて表面化する。A-1 と同じ流れで対応するのが望ましい。

### 修正方針

- 成功時刻と失敗時刻を別のキーで保存する
- 成功または304のあとは24時間抑制する
- 失敗後は15分〜1時間程度の短いバックオフで再試行する
- 同時実行を防ぐ in-flight フラグを追加する（`onAppear` と `scenePhase` の両方から呼ばれるため）

### 完了条件

- 通信失敗後、短い間隔で再試行できる
- 成功または304後は24時間抑制される
- 連続した画面イベントから更新処理が重複実行されない

---

## 推奨実装順

1. A-1 リモートカタログを本編の選択に接続する
2. C-2 カタログ更新の再試行を直す（A-1 と同じ層のため続けて行う）
3. A-2 表示済み履歴による重複回避を入れる
4. C-1 選択仕様を1つに確定し、使われていない層を整理する
5. B-1 日付キーをローカルカレンダーへ統一する
6. A-3 ストア掲載文とドキュメントを実装に合わせる

A-3 は他と独立しているため、いつ着手しても構わないが、**提出前に必ず反映すること**。

## 確認コマンド

```bash
xcodebuild -project Wiseish/Wiseish.xcodeproj \
  -scheme Wiseish \
  -configuration Debug \
  -destination 'generic/platform=iOS' \
  -derivedDataPath /tmp/wiseish-build \
  CODE_SIGNING_ALLOWED=NO build
```

```bash
xcodebuild test \
  -project Wiseish/Wiseish.xcodeproj \
  -scheme Wiseish \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -derivedDataPath /tmp/wiseish-tests \
  CODE_SIGNING_ALLOWED=NO
```

デプロイメントターゲットがiOS 26.0のため、シミュレータはiOS 26系のランタイムを持つ機種しか使えません。iPhone 13/ 15系はiOS 18以下のため対象外です。手元の環境で使える機種は次で確認してください。

```bash
xcrun simctl list devices available
```


テストは Swift Testing（`@Test`）で記述する。既存の `Wiseish/WiseishTests/WiseishTests.swift` に合わせること。

Widget を含む一致の確認は実機で行う。シミュレータでは App Group のファイル読み取りタイミングが実機と異なる場合がある。

## 本書に含めない事項（実装依頼ではなく、企画判断）

以下は修正依頼ではなく、依頼主側で方針を決める事項です。担当者は着手しないでください。

- **カタログの枚数** — 現在120枚。A-2 の重複回避を入れても、供給が増えなければ一巡は避けられない。年間365枚が目標、当面の目標は200〜250枚
- **マネタイズ** — `isPremium` フィールドは全120件 `false` で、StoreKit の実装もない。データ構造と方針を決める必要がある
- **Ishの露出** — 現状は静止画と短い独り言のみ。キャラクターへの投資に対して回収経路が少ない
