# Wise-ish review action items

レビュー日: 2026-08-27

この文書は、別の担当者やAIへそのまま修正を依頼できるように、発見事項と完了条件をまとめたものです。

## 現在の確認結果

- `Wiseish`、`WiseishWidget`、`WiseishShare`を含むiOS実機向けDebugビルドは成功
- `WiseishTests`のユニットテスト9件は成功
- UIテスト、起動テスト、起動性能テストは成功
- 配信カタログ `https://aokinao.github.io/wise-ish/quotes.json` は確認時点でHTTP 200
- 以下の問題は既存テストでは検出されない

## P1: カタログの内容次第で起動時にクラッシュする

### 対象

- `Wiseish/Wiseish/ContentView.swift`
- `Wiseish/Wiseish/WiseishOnboardingView.swift`
- `Wiseish/WiseishShared/WiseishCatalog.swift`

### 問題

`ContentView`の初期値で `WiseishMood.quiet.quotes[0]` を直接参照している。また、オンボーディングと日次状態復元では、候補数が0件でも `index % quotes.count` および配列アクセスを行う。

現在のカタログ検証は、mood値が許可値かどうかは確認するが、各moodや各月に表示可能な候補が最低1件あることを保証しない。そのため、検証を通過したリモートカタログでもアプリをクラッシュさせられる。

### 修正方針

選択処理を共有層の1か所へ集約し、次の順序で必ず候補を返す。

1. 指定moodかつ対象日にactiveな候補
2. moodを問わず対象日にactiveな候補
3. バンドルまたはコード内の固定fallback

ビューのプロパティ初期化時にカタログ配列を直接添字参照しない。必要であれば安全な固定placeholderを初期値にして、`onAppear`またはinitializer内の安全なresolverで置き換える。

### 完了条件

- quietが0件の有効なテストカタログでも起動できる
- 対象月にactiveな候補が0件でも起動できる
- オンボーディング、通常画面、日付変更、App Intent、Widgetが同じfallback規則を使う
- 上記ケースのユニットテストが追加されている

## P1: 年・月の経過率が100分の1で表示される

### 対象

- `Wiseish/WiseishShared/WiseishDailyMetric.swift`

### 問題

`yearMetric`と`monthMetric`の `ratio` は0〜1だが、`percentage`が100倍せず数値を文字列化している。その結果、約65%が `0.7%`、約87%が `0.9%` と表示される。

`progress`プロパティは描画用に0〜1のまま維持する必要がある。

### 修正方針

表示文字列を作る箇所だけ `ratio * 100` をフォーマットする。`WiseishDayFact`にも似た計算があるため、重複するパーセント変換を共通化してもよい。

### 完了条件

- 2026-08-27の年経過率が約65.5%になる
- 2026-08-27の月経過率が約87.1%になる
- 円グラフ等へ渡す `progress` は0〜1を維持する
- 閏年と月末を含むユニットテストが追加されている

## P2: オンデバイスLLMの処理が到達不能

### 対象

- `Wiseish/Wiseish/WiseishLanguageModelService.swift`
- `Wiseish/WiseishShared/WiseishContextStore.swift`
- `Wiseish/Wiseish/ContentView.swift`

### 問題

`WiseishLanguageModelService.generate` は定義されているが、リポジトリ内に呼び出し元がない。`saveGeneratedQuote`、`savePendingInput`なども定義以外では利用されていない。

`ContentView`は生成済みの一言を読む処理を持つものの、そのデータを作成・保存する実行経路がない。このためMVPに記載された「オンデバイスLLMが利用可能な場合の選択補助」は動作しない。

### 修正方針

AIを表に出さない現在のプロダクト方針を維持し、日替わり候補を初めて確定するときだけ選択補助を実行する。

- まずローカル選択結果を即座に表示・保存する
- Foundation Modelsが利用可能ならバックグラウンドで選択補助を実行する
- 同日の表示を途中で不意に差し替えるか、翌日分から適用するかを仕様として決める
- タイムアウト、キャンセル、モデル非対応時はローカル結果を維持する
- 生成本文ではなく、編集済み候補の選択に限定する

体験の安定性を優先するなら「共有された文脈を翌日の選択へ反映」が最も自然で、当日の一枚固定とも矛盾しにくい。

### 完了条件

- 利用可能端末では `generate` に到達することをテストまたはログで確認できる
- 非対応・失敗・タイムアウト時も一枚が即座に表示される
- AI結果が編集済みカタログ外の本文を表示しない
- 同日の一枚を固定するタイミングが仕様とテストで明確になっている

## P2: アプリ未起動日はWidgetとアプリの一言が一致しない

### 対象

- `Wiseish/WiseishWidget/WiseishWidget.swift`
- `Wiseish/Wiseish/ContentView.swift`
- `Wiseish/WiseishShared/WiseishContextStore.swift`

### 問題

共有済みの当日レコードがない場合、Widgetは全active候補から `day % count` で選ぶ。一方、アプリはmood、時間帯、外部文脈、お気に入り、反応、履歴を使う。このため、Widgetを先に見た日やアプリを開かなかった日は、後から開いたアプリと別の一言になる可能性が高い。

これはMVPの非機能要件「同じ日はアプリとウィジェットで同じ言葉を表示する」と矛盾する。

### 修正方針

日付、カタログ、端末内状態から一言を決める純粋なresolverをSharedへ移動し、アプリ、Widget、App Intentのすべてで使う。

- 同じ入力から同じquote IDを返す決定的な実装にする
- Widgetでも安全に読めるApp Group内データだけを入力にする
- リモートカタログをWidgetで使わないなら、アプリ側も「今日の確定前」はバンドル版を基準にするなど、カタログ差の扱いを決める
- 一度確定した当日レコードは、その日の間は優先する

### 完了条件

- アプリ未起動状態でも、同じ日付のWidget、アプリ、App Intentが同じquote IDを返す
- 日付変更後も3経路が一致する
- 季節限定候補と空候補のケースをテストする

## P2: 日付キーの一部がUTC基準になっている

### 対象

- `Wiseish/WiseishShared/WiseishContextStore.swift`

### 問題

`dayKey`と`reflectionKey`は `date.formatted(.iso8601.year().month().day())` を使う。このISO 8601スタイルはデフォルトでUTC基準になる。

たとえばAsia/Tokyoの2026-08-27 01:00は `2026-08-26` になるため、ローカル日付を意図した気分や反応の有効期限が午前9時に切り替わる。現在は関連UIの一部が未接続だが、今後接続すると日付境界の不具合になる。

### 修正方針

すでにローカルカレンダーを使っている `WiseishDayRollover.dayKey` に統一する。保存済みキーとの互換性が必要なら、旧UTCキーを一度だけ読み、新キーへ移行する。

### 完了条件

- Asia/Tokyoの0時前後でキーがローカル日付どおり切り替わる
- DSTのあるタイムゾーンでもローカル0時で切り替わる
- タイムゾーン変更時の期待動作をテストまたは仕様に記載する

## P3: カタログ更新失敗後も24時間再試行されない

### 対象

- `Wiseish/Wiseish/WiseishCatalogUpdater.swift`

### 問題

`lastUpdateAttempt`を通信開始前に保存しているため、オフラインや一時的な通信失敗でも、その後24時間は再試行しない。朝に一度オフライン起動しただけで、その日の更新機会を失う。

### 修正方針

成功時刻と失敗時刻を分ける。成功時は24時間、失敗時は15分〜1時間程度の短いバックオフにする。同時更新を防ぐin-flight制御も追加すると安全。

### 完了条件

- 通信失敗後は短い間隔で再試行できる
- 成功または304後は24時間抑制される
- 連続した画面イベントから更新処理が重複実行されない

## 推奨実装順

1. 空候補でもクラッシュしない共有resolverを作る
2. アプリ、Widget、App Intentをresolverへ統一する
3. パーセント表示とテストを修正する
4. 日付キーをローカルカレンダーへ統一する
5. LLMを日次確定フローへ接続するか、MVP対象外としてコードと文書を整理する
6. カタログ更新の再試行方針を改善する

## 修正後の確認コマンド

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
  -destination 'platform=iOS Simulator,name=iPhone SE (3rd generation),OS=26.2' \
  -derivedDataPath /tmp/wiseish-tests \
  CODE_SIGNING_ALLOWED=NO
```
