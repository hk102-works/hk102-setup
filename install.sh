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

# ── 2. このMac専用の鍵を作る ────────────────────────────────
# 資料用と送信用で別の鍵にする。同じ鍵は2つのリポジトリに登録できないため。
# 鍵の秘密の側はこのMacから一歩も出ない。
say "2/8  このMac専用の鍵を作っています"
mkdir -p "$HOME/.ssh" && chmod 700 "$HOME/.ssh"
for pair in "hk102_brain:資料（読むだけ）" "hk102_inbox:送信"; do
  key="$HOME/.ssh/${pair%%:*}"
  [ -f "$key" ] || ssh-keygen -q -t ed25519 -f "$key" -N "" -C "${pair##*:} / $(hostname -s)"
done
ok "2本作りました"

# 鍵を使い分けるための設定を追記する（固有の名前なので他の用途とぶつからない）
if ! grep -q 'Host hk102-brain.github.com' "$HOME/.ssh/config" 2>/dev/null; then
  cat >> "$HOME/.ssh/config" <<EOF

Host hk102-brain.github.com
  HostName github.com
  User git
  IdentityFile ~/.ssh/hk102_brain
  IdentitiesOnly yes

Host hk102-inbox.github.com
  HostName github.com
  User git
  IdentityFile ~/.ssh/hk102_inbox
  IdentitiesOnly yes
EOF
fi
chmod 600 "$HOME/.ssh/config"

# ── 3. 公開できる側の鍵を見せて、登録を待つ ─────────────────────
say "3/8  以下の2行をリョウガに渡してください（これは人に見せてよい情報です）"
echo
echo "───────── ここから ─────────"
echo "[BRAIN] $(cat "$HOME/.ssh/hk102_brain.pub")"
echo "[INBOX] $(cat "$HOME/.ssh/hk102_inbox.pub")"
echo "───────── ここまで ─────────"
echo
printf '  登録が終わったら Enter を押してください: '
read -r _ < /dev/tty
echo

say "4/8  つながるか確認しています"
for r in brain inbox; do
  if ssh -o StrictHostKeyChecking=accept-new -T "git@hk102-$r.github.com" 2>&1 | grep -q 'successfully authenticated\|does not provide shell'; then
    ok "hk102-$r OK"
  else
    ng "hk102-$r につながりません。鍵の登録を確認してください"
    exit 1
  fi
done

# ── 5. 資料と送信フォルダを取ってくる ──────────────────────────
say "5/8  会社の資料を取得しています"
git clone -q "git@hk102-brain.github.com:$OWNER/hk102-brain.git" "$WS"
ok "$WS"
git clone -q "git@hk102-inbox.github.com:$OWNER/hk102-inbox.git" "$OUT"
# 送信時の名前はこのフォルダの中だけで設定する（Mac全体のgit設定は変えない）
git -C "$OUT" config user.name  "Jion"
git -C "$OUT" config user.email "jion@hk102.local"
ok "$OUT"

# ── 6. 資料フォルダを書き換え不可にして、設定を書く ────────────────
say "6/8  資料フォルダを読み取り専用にしています"
printf '#!/bin/sh\necho "ここは読むだけのフォルダです" >&2\nexit 1\n' > "$WS/.git/hooks/pre-commit"
chmod +x "$WS/.git/hooks/pre-commit"
mkdir -p "$WS/.claude"
cat > "$WS/.claude/settings.local.json" <<EOF
{
  "env": {
    "PATHMAP_WORKSPACE": "$WS"
  }
}
EOF
/usr/bin/python3 "$WS/tools/pathmap/pathmap.py" refresh >/dev/null
ok "書き込み不可にして、資料の索引を作りました"

# ── 7. 起動アイコンと自動更新 ───────────────────────────────
say "7/8  デスクトップに起動アイコンを置いています"
CLAUDE_BIN="$(command -v claude || true)"
[ -n "$CLAUDE_BIN" ] || { ng "Claude Code が見つかりません（あとで入れてください）"; CLAUDE_BIN="claude"; }
LAUNCHER="$HOME/Desktop/102の仕事.command"
cat > "$LAUNCHER" <<EOF
#!/bin/bash
cd "$WS" || exit 1
exec "$CLAUDE_BIN"
EOF
chmod +x "$LAUNCHER"
ok "デスクトップの「102の仕事」をダブルクリックで開きます"

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
[ -d "$HOME/.claude/skills" ] && ok "Mac全体のスキルは触っていません（$(ls "$HOME/.claude/skills" 2>/dev/null | wc -l | tr -d ' ')件のまま）" \
  || ok "Mac全体の設定は触っていません"

cat <<'EOM'

──────────────────────────────────
 セットアップが終わりました

 あと2つだけ、画面の指示にしたがって進めてください

   1. ターミナルで  claude  と打って、自分のアカウントでログイン
   2. Google ドライブ（パソコン版）を入れて、自分のGoogleでログイン

 以降は「デスクトップの 102の仕事 をダブルクリック」で
 Claudeが開きます。日本語で話しかけるだけで大丈夫です
──────────────────────────────────
EOM
