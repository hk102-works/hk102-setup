# hk102-setup

102 INTERNATIONAL の会社資料を Mac に入れるためのスクリプト。

```bash
curl -fsSL https://raw.githubusercontent.com/hk102-works/hk102-setup/main/install.sh | bash
```

## 入るもの

- `~/hk102` — 会社の資料（読むだけ・15分ごとに自動更新）
- `~/hk102-outbox` — 作ったものの置き場（15分ごとに自動送信）
- `~/.ssh/hk102_brain` / `hk102_inbox` — このMac専用の鍵（**秘密の側はこのMacから出ない**）
- デスクトップの「102の仕事」— ダブルクリックで Claude が開く

## 入らないもの

Mac 全体の設定（`~/.claude/` の中）には**一切触りません**。ルールも権限設定もスキルも `~/hk102` の中だけで効くので、このMacで他の仕事をしていても混ざりません。

## 途中で止まる箇所

手順3で公開鍵が2行表示され、登録待ちになります。その2行をリョウガに渡し、登録が終わってから Enter を押してください。
