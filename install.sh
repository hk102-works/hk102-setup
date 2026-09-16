#!/bin/bash
# 102 INTERNATIONAL の会社資料をこのMacに入れる。
#
#   curl -fsSL https://raw.githubusercontent.com/hk102-works/hk102-setup/main/install.sh | bash
#
# このMacの他の設定（~/.claude/ の中）には一切触らない。
# 入るのは ~/hk102（資料）と ~/hk102-outbox（提案の送り先）とデスクトップの起動アイコンだけ。
set -euo pipefail

OWNER="hk102-works"
WS="$HOME/hk102"
OUT="$HOME/hk102-outbox"
BIN="$HOME/hk102-bin"

say() { printf '\n\033[1m%s\033[0m\n' "$*"; }
ok()  { printf '  ✅ %s\n' "$*"; }
ng()  { printf '  ❌ %s\n' "$*" >&2; }

# ── 0. もう入っている場合は更新するだけ ───────────────────────
if [ -e "$WS/.git" ]; then
  say "すでにセットアップ済み。資料を最新にします"
  [ -x "$BIN/brain-pull.sh" ] && "$BIN/brain-pull.sh"
  ok "完了"
  exit 0
fi

# ── 1. gitとpythonを用意する ──────────────────────────────
say "1/8  必要なものを確認しています"
if ! xcode-select -p >/dev/null 2>&1; then
  ng "開発ツールが入っていません。インストール画面を出します"
  xcode-select --install || true
  echo "     → 画面の指示でインストールを終えてから、もう一度このコマンドを実行してください"
  exit 0
fi
ok "git $(git --version | awk '{print $3}') / python $(/usr/bin/python3 -V 2>&1 | awk '{print $2}')"

# ── 2. GitHubのアクセスキーを預かる ───────────────────────────
say "2/8  アクセスキーを入力してください（画面には出ません）"
printf '  キーを貼り付けて Enter: '
read -rs PAT
echo
[ -n "$PAT" ] || { ng "空でした。中止します"; exit 1; }

git config --global --get credential.helper >/dev/null 2>&1 \
  || git config --global credential.helper osxkeychain
printf 'protocol=https\nhost=github.com\nusername=x-access-token\npassword=%s\n\n' "$PAT" \
  | git credential-osxkeychain store
unset PAT
ok "保存しました"

# ── 3. 資料と送信フォルダを取ってくる ──────────────────────────
say "3/8  会社の資料を取得しています"
git clone -q "https://github.com/$OWNER/hk102-brain.git" "$WS" || { ng "取得に失敗しました。キーを確認してください"; exit 1; }
ok "$WS"
git clone -q "https://github.com/$OWNER/hk102-inbox.git" "$OUT" 2>/dev/null || mkdir -p "$OUT"
if [ -e "$OUT/.git" ]; then
  # 送信用の名前はこのフォルダの中だけで設定する（Mac全体のgit設定は変えない）
  git -C "$OUT" config user.name  "Jion"
  git -C "$OUT" config user.email "jion@hk102.local"
  ok "$OUT"
fi

# ── 4. 資料フォルダを書き換え不可にする ────────────────────────
say "4/8  資料フォルダを読み取り専用にしています"
printf '#!/bin/sh\necho "ここは読むだけのフォルダです" >&2\nexit 1\n' > "$WS/.git/hooks/pre-commit"
chmod +x "$WS/.git/hooks/pre-commit"
ok "書き込みできないようにしました"

# ── 5. このMac向けの設定を書く（このフォルダの中だけ） ──────────────
say "5/8  設定を書いています"
mkdir -p "$WS/.claude"
cat > "$WS/.claude/settings.local.json" <<EOF
{
  "env": {
    "PATHMAP_WORKSPACE": "$WS"
  }
}
EOF
/usr/bin/python3 "$WS/tools/pathmap/pathmap.py" refresh >/dev/null
ok "資料の索引を作りました"

# ── 6. 起動アイコンを置く ──────────────────────────────────
say "6/8  デスクトップに起動アイコンを置いています"
CLAUDE_BIN="$(command -v claude || true)"
if [ -z "$CLAUDE_BIN" ]; then
  ng "Claude Code が見つかりません。先にインストールしてください"
  CLAUDE_BIN="claude"
fi
LAUNCHER="$HOME/Desktop/102の仕事.command"
cat > "$LAUNCHER" <<EOF
#!/bin/bash
cd "$WS" || exit 1
exec "$CLAUDE_BIN"
EOF
chmod +x "$LAUNCHER"
ok "デスクトップの「102の仕事」をダブルクリックで開きます"

# ── 7. 自動で最新にする仕組みを入れる ──────────────────────────
say "7/8  自動更新を設定しています"
mkdir -p "$BIN"
cp "$WS/setup/brain-pull.sh" "$WS/setup/outbox-push.sh" "$BIN/"
chmod +x "$BIN"/*.sh
for L in com.hk102.brain-pull com.hk102.outbox-push; do
  sed "s|__HOME__|$HOME|g" "$WS/setup/$L.plist" > "$HOME/Library/LaunchAgents/$L.plist"
  launchctl bootout "gui/$UID/$L" 2>/dev/null || true
  launchctl bootstrap "gui/$UID" "$HOME/Library/LaunchAgents/$L.plist"
done
ok "15分ごとに最新になります"

# ── 8. 確認 ────────────────────────────────────────────
say "8/8  確認"
/usr/bin/python3 "$WS/tools/pathmap/pathmap.py" check | grep -q '"ok": true' \
  && ok "資料の整合性 OK" || ng "資料の整合性に問題あり（リョウガに連絡）"
[ "$(launchctl list | grep -c com.hk102)" -eq 2 ] \
  && ok "自動更新 2件 登録済み" || ng "自動更新の登録に失敗（リョウガに連絡）"
launchctl list | grep -q com.ryoga && ng "com.ryoga.* が存在します（リョウガに連絡）" || ok "他環境との混線なし"

cat <<'EOM'

──────────────────────────────────
 セットアップが終わりました

 次の2つだけ、画面の指示にしたがって進めてください

   1. ターミナルで  claude  と打って、自分のアカウントでログイン
   2. Google ドライブ（パソコン版）を入れて、自分のGoogleでログイン

 以降は「デスクトップの 102の仕事 をダブルクリック」で
 Claudeが開きます。日本語で話しかけるだけで大丈夫です
──────────────────────────────────
EOM
