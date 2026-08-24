# Ish motion specification

## Character role

Ish（イッシュ）は、悟っていそうで少し抜けている小さな仙人です。答えを授ける賢者ではなく、ユーザーと一緒に考えて、途中で考えていたことを忘れます。

## Personality

- 静か
- 少し困っている
- 好奇心はある
- 答えを知ったふりをしない
- 大げさに笑わせようとしない
- 妙に自信はあるが、たまに足元がおぼつかない

## Visual style

- 白と黒だけを使う
- ノートの余白に短時間で描いたような線
- 線の揺れ、太さの不均一さ、少し開いた輪郭を残す
- 清書しすぎず、ポーズごとの差も個性として許容する
- 長い眉の下に目がほぼ隠れた、優しく眠そうな表情を基本にする
- かなり年老いた印象を、垂れた眉、長いひげ、額のしわ、猫背で表す
- 老いは弱さや悲しさではなく、長く生きすぎた可笑しさとして扱う
- 陰影、グラデーション、細かな質感は加えない

## Layer plan

アニメーション用のマスター素材では、最低限次のパーツを分離します。

- head / body / robe
- left eye / right eye
- left eyebrow / right eyebrow
- mouth
- left arm / right arm
- left leg / right leg
- beard / moustache
- left hair tuft / right hair tuft
- left sleeve / right sleeve
- mustard sash

## Motion states

| State | Motion | Use |
| --- | --- | --- |
| `neutral` | 小さな呼吸、閉じた目、ひげが遅れて揺れる | 通常表示 |
| `thinking` | 片方の目が眉の下から少しだけ覗き、首を傾ける | 言葉の生成・選択中 |
| `remembered` | 指を上げかけるが、何も言わず戻す | 日付や言葉の更新 |
| `stumble` | 半歩よろけ、何事もなかった顔に戻る | タップ時の反応 |
| `tired` | 袖に手を隠し、目が細くなる | 低エネルギーの文脈 |
| `bright` | 眉とひげが一度だけ跳ねる | お気に入り登録 |

## Timing

- Blink: 120–180 ms
- Thinking tilt: 700–1,000 ms
- Beard wobble: 450–700 ms
- Tiny stumble: 500–750 ms
- Tap reaction: 300–600 ms
- In-app idle cycle: 5–9 seconds、不規則にする

## Widget constraints

ウィジェットでは常時ループを前提にしません。タイムラインや操作によるデータ更新時に、2秒以内の短いトランジションとして眉・ひげの跳ねや小さなよろけを使います。通常時は、文脈に合う静止ポーズを表示します。

## AI contract

AIは自由な動作を生成せず、アプリが定義した状態を選びます。

```json
{
  "pose": "thinking",
  "energy": 2,
  "expression": "mildlyConfused",
  "accent": "beardWobble"
}
```

不明な値や生成失敗時は、必ず `neutral` にフォールバックします。
