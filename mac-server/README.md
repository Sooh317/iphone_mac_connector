# Terminal Gateway Server

Mac Terminal Gateway for iPhone-Mac Connector

## ローカルでの起動

### 0. Node.js バージョン

推奨 Node.js: **18 / 20 / 22 LTS**（`node-pty` 互換のため。24 以上は非推奨）

Volta を使う場合:

```bash
volta pin node@22
volta run --node 22 node -v
```

### 1. 依存パッケージのインストール

```bash
cd mac-server
npm install
```

### 2. 設定ファイルの作成（オプション）

```bash
cp config.json.example config.json
chmod 600 config.json  # セキュリティのため必須
```

### 3. トークンの生成

```bash
npm run generate-token
```

デフォルトではトークン文字列をクリップボードに自動コピーします（Universal Clipboard 対応）。

QR 画像も生成したい場合：

```bash
npm run generate-token -- --qr
```

クリップボードコピーをしない場合：

```bash
npm run generate-token -- --no-copy
```

トークン文字列を表示する場合：

```bash
npm run generate-token -- --show-token
```

### 4. サーバーの起動

```bash
# 推奨: トークン生成と起動を1コマンドで実行
npm run start-with-token

# Volta 利用時（推奨）
volta run --node 22 npm run start-with-token
```

手動で分ける場合：

```bash
GATEWAY_HOST=$(tailscale ip -4 | head -n1) GATEWAY_PORT=8765 GATEWAY_SHELL=/bin/zsh npm run generate-token
GATEWAY_HOST=$(tailscale ip -4 | head -n1) GATEWAY_PORT=8765 GATEWAY_SHELL=/bin/zsh npm start
```

Universal Clipboard 有効時は、トークン生成後に Mac 側で別文字列をコピーすると iPhone クリップボードも上書きされます。接続前に余計なコピーをしないでください。

## セキュリティ

### ネットワークバインディング

本サーバーは、デフォルトで**Tailscale IPアドレス**へのバインドのみを許可します。

- **本番環境**: Tailscale IPアドレス（100.x.x.x）にバインド
- **開発/テスト環境のみ**: `ALLOW_INSECURE_BIND=true` 環境変数で localhost へのバインドを許可

例：
```bash
# 本番環境（推奨）
export GATEWAY_HOST=100.x.x.x  # あなたのTailscale IP
npm start

# 開発環境のみ
ALLOW_INSECURE_BIND=true npm start
```

### トークンセキュリティ

- トークンファイルは **0600** パーミッション（所有者のみ読み書き可能）が必須
- config.json も **0600** パーミッションが必須
- トークンは最低32バイト（256ビット）の強度が必要

### グレースフルシャットダウン

サーバーは以下のシグナルで安全にシャットダウンします：
- `SIGINT` (Ctrl+C)
- `SIGTERM`
- 未処理の例外やPromise拒否も自動的に処理

## 接続テスト

WebSocket クライアントで接続テスト:

```bash
# wscat を使用 (npm install -g wscat)
TOKEN=$(cat ~/.terminal-gateway-token)
wscat -c ws://localhost:8765 -H "Authorization: Bearer $TOKEN"
```

接続後、以下のメッセージを送信:

```json
{"type":"input","data":"ls\n"}
```

## トラブルシューティング

### `node-pty spawn failed (posix_spawnp failed.)`

このサーバーはデフォルトで PTY 起動を必須にしています（接続先 Mac の実ターミナル挙動を優先）。

確認ポイント:

```bash
# 1) シェルが実在して実行可能か
ls -l /bin/zsh

# 1.5) node-pty の spawn-helper に実行権限があるか
ls -l node_modules/node-pty/prebuilds/darwin-arm64/spawn-helper
# -rwxr-xr-x でない場合:
chmod +x node_modules/node-pty/prebuilds/darwin-arm64/spawn-helper

# 2) launchd を使う場合は plist を再インストール
bash scripts/install-launchd.sh

# 3) 手動起動時は shell を明示
GATEWAY_SHELL=/bin/zsh npm start
```

どうしても暫定で非PTYモードに落としたい場合のみ:

```bash
ALLOW_NON_PTY_FALLBACK=true npm start
```
