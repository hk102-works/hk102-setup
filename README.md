# hk102-setup

102 INTERNATIONAL の会社資料を Mac に入れるためのスクリプト。

```bash
curl -fsSL https://raw.githubusercontent.com/hk102-works/hk102-setup/main/install.sh | bash
```

Mac 全体の設定（`~/.claude/`）には触りません。入るのは以下だけです。

- `~/hk102` — 会社の資料（読むだけ・15分ごとに自動更新）
- `~/hk102-outbox` — 作ったものの置き場（15分ごとに自動送信）
- デスクトップの「102の仕事」— ダブルクリックで Claude が開く
