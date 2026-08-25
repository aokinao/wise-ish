# Wise-ish

今日を、雑に眺める。

Wise-ishは、日付と「少し深くて、だいたい迷言」な一言を静かに置いておく日めくりアプリです。生活を改善したり、今日を管理したりせず、3秒ほど今日を眺めて閉じられる場所を目指します。

長く生きすぎて、哲学と生活の境目がなくなったIshが、毎日ひとつ、役に立たない哲学を置いていきます。世界の真理も、冷蔵庫のプリンも、同じ深刻さで考えます。

## Product principles

- アプリを開かなくても、ウィジェットだけで体験が成立する
- 毎日使わせるのではなく、毎日そこにある
- 一画面で日付、一言、Ishまで眺められる
- 哲学的な問い 4.5、哲学と生活が混ざった思考 4、可愛げと脱力 1.5
- 一瞬笑えて、あとから少しだけ残る
- AIは世界観を補助し、品質の基準は人が設計する
- 個人情報は可能な限り端末内で扱う

## MVP

- 今日の日付とWise-ishな言葉の表示
- 今年の何日目、残り日数、経過率から日替わりで一つ表示
- ホーム画面ウィジェット
- その日の文脈と過去の返事に合わせた言葉の選択
- お気に入りと直近7日間の履歴
- 対応端末でのオンデバイス言い換え
- AIが使えない場合の編集済みコンテンツへのフォールバック
- Siri / App Intentsから今日の言葉を呼び出す

詳しくは [docs/mvp.md](docs/mvp.md) を参照してください。

## HTML prototype

依存ライブラリなしの画面プロトタイプを `prototype/` に用意しています。

```bash
cd /Users/aoki/develop/wise-ish
python3 -m http.server 8000
```

ブラウザで `http://localhost:8000/prototype/` を開いてください。HTMLファイルを直接開いても動作します。

## Mascot

マスコットは、悟っていそうで少し抜けている小さな仙人「Ish（イッシュ）」です。ノートの余白に描いたような、白黒のラフな線を基本表現にします。

![Ish mascot](design/mascot/ish-master.png)

モーション方針は [design/mascot/ish-motion-spec.md](design/mascot/ish-motion-spec.md) にまとめています。

## Planned technical direction

- SwiftUI
- WidgetKit
- SwiftData
- App Intents
- Apple Foundation Models（対応端末のみ）
- 編集済みJSONコンテンツによるオフラインフォールバック

表示名には `Wise-ish`、コード・ターゲット・Bundle IDにはハイフンを除いた `Wiseish` を使用します。
