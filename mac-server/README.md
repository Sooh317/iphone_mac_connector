# Terminal Gateway Server

Mac Terminal Gateway for iPhone-Mac Connector

## Docker での起動

### 1. ビルドと起動

```bash
cd /path/to/iphone_mac_connector
docker-compose up -d --build
```

### 2. トークンの確認

```bash
docker exec terminal-gateway cat /data/terminal-gateway-token
```

### 3. ログの確認

```bash
docker logs -f terminal-gateway
```

### 4. 停止

```bash
docker-compose down
```

## ローカルでの起動

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

トークンを表示する場合：

```bash
npm run generate-token -- --show-token
```

### 4. サーバーの起動

```bash
# 本番環境（Tailscale IPでのバインド）
npm start

# 開発/テスト環境（localhostでのバインド）
ALLOW_INSECURE_BIND=true npm start
```

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
