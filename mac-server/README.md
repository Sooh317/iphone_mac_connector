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

### 2. トークンの生成

```bash
npm run generate-token
```

### 3. サーバーの起動

```bash
npm start
```

## 接続テスト

WebSocket クライアントで接続テスト:

```bash
# wscat を使用 (npm install -g wscat)
TOKEN=$(docker exec terminal-gateway cat /data/terminal-gateway-token)
wscat -c ws://localhost:8765 -H "Authorization: Bearer $TOKEN"
```

接続後、以下のメッセージを送信:

```json
{"type":"input","data":"ls\n"}
```
