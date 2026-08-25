# App Store公開手順

## 1. App Store Connectでアプリを作成

1. [App Store Connect](https://appstoreconnect.apple.com/) の「マイApp」→「＋」→「新規App」
2. プラットフォームは **iOS**
3. 名前は `Wise-ish`
4. プライマリ言語は日本語
5. Bundle IDは `com.naoki.Wiseish`
6. SKUは社内用に `wise-ish-ios` など一意な値を設定

Bundle IDはXcodeのApp targetと一致させる。WidgetとShare Extensionは、同じBundle IDとして登録するのではなく、Xcodeの自動署名でApp IDを作成する。

## 2. Xcode側の確認

- Team: Apple Developerのチーム
- App target: `com.naoki.Wiseish`
- Widget target: `com.naoki.Wiseish.WiseishWidget`
- Share target: `com.naoki.Wiseish.WiseishShare`
- Version: `1.0.0`など、App Store Connectのバージョンと一致
- Build: 同じVersion内で必ず増やす（1, 2, 3...）
- Signing & Capabilities: Automatically manage signingを有効化
- App Groups: `group.com.naoki.Wiseish` がApp、Widget、Shareで一致

まず実機でArchiveせずRunできることを確認する。次に `Product > Archive` → OrganizerのValidateで署名とExtensionを確認する。

## 3. TestFlight

1. OrganizerでArchiveを選択
2. `Distribute App` → `App Store Connect` → `Upload`
3. App Store ConnectのTestFlightでビルド処理完了を待つ
4. 内部テスターを追加して、実機で以下を確認
   - 初回オンボーディング
   - 日付変更アニメーション
   - Widgetの小・中サイズ
   - 通知のON/OFF
   - App Intents / Siri
   - 端末内LLMが使えない端末でのフォールバック

## 4. GitHub Actions自動デプロイの準備

リポジトリの `Settings > Secrets and variables > Actions` に以下を登録する。

| Secret | 内容 |
| --- | --- |
| `APP_STORE_CONNECT_KEY_ID` | App Store Connect API KeyのKey ID |
| `APP_STORE_CONNECT_ISSUER_ID` | API KeyのIssuer ID |
| `APP_STORE_CONNECT_PRIVATE_KEY` | `.p8`秘密鍵の内容（改行を保持） |
| `APPLE_TEAM_ID` | Apple Developer Team ID（例: `YE3JSRF22E`） |

API KeyはApp Store Connectの `Users and Access > Integrations > Keys` で、最低限 `App Manager` 権限で作成する。`.p8`は一度しかダウンロードできないため、パスワードマネージャーにも保管する。

このリポジトリの `ios-release.yml` は、`v*`タグまたはActionsの手動実行で以下を行う。

1. Swiftテスト
2. generic iOS向けArchive
3. IPA書き出し
4. TestFlightへUpload

```bash
git tag v1.0.0
git push origin v1.0.0
```

タグを付ける前に、Xcodeプロジェクトの `MARKETING_VERSION` と `CURRENT_PROJECT_VERSION` を更新する。

## 5. 初回リリース

自動Upload後、App Store Connectで以下を入力する。

- スクリーンショット（iPhoneの必要サイズ）
- 概要、説明、キーワード
- サポートURL、プライバシーポリシーURL
- 年齢制限
- App Privacy（端末内処理、外部コンテキストの扱い、通知など）
- 輸出コンプライアンス

TestFlightで問題がなければ、ビルドをバージョンに紐づけて「審査へ提出」する。

## 6. リリース前チェック

- 本番Bundle IDとProvisioning Profileが一致している
- Debug用の長押し日付変更がReleaseビルドに残っていない
- API Key、秘密鍵、個人情報がリポジトリに入っていない
- WidgetとShare Extensionを含むArchiveになっている
- オフライン時にも編集済みカタログが表示される
- Widgetの表示日付がアプリの日付と一致している
