# iPhone Mac Connector

iPhone から Mac のターミナルに Tailscale 経由で接続するためのプロジェクトです。  
Docker は使わず、Mac 上で `mac-server` を直接起動する前提です。

## 前提環境

- macOS
- iPhone と Mac の両方で Tailscale 接続済み
- Node.js は `mac-server` で **22 LTS 推奨**（`node-pty` の安定動作のため）
- 任意: Volta（プロジェクト単位で Node バージョン固定）

### Volta を使う場合（推奨）

```bash
brew install volta
echo 'export PATH="$HOME/.volta/bin:$PATH"' >> ~/.zshrc
source ~/.zshrc
```

## 使う時の一連の流れ

1. Tailscale を両端末で有効化
Mac と iPhone の両方に Tailscale をインストールし、同じ Tailnet アカウントでログインして `Connected` 状態にします。

2. Mac サーバーを起動
```bash
cd /Users/sooh/Devs/iphone_mac_connector/mac-server
volta pin node@22
volta run --node 22 npm install
volta run --node 22 npm run start-with-token
```

3. iPhone アプリを実機にインストール
```bash
open /Users/sooh/Devs/iphone_mac_connector/ios-app/IphoneMacConnector/IphoneMacConnector.xcodeproj
```
Xcode で Team を設定して実機 Run (`⌘R`) します。初回は iPhone 側で開発者証明書を信頼します。

4. iPhone アプリで接続設定
Host は起動ログに表示された `Host`、Port は起動ログに表示された `Port` を入力します。Token は起動コマンド実行時に自動コピーされるので iPhone 側にペーストして `Connect` をタップします。
注意: Universal Clipboard 有効時は、Mac で別テキストをコピーすると iPhone 側トークンも上書きされます。トークン貼り付け前に追加コピーしないでください。

5. 接続確認
コマンド例は `whoami`, `pwd`, `echo hello` です。Mac 側ログは次で確認します。
```bash
tail -f ~/.terminal-gateway/audit.log
```

## よく使うコマンド

```bash
# Node 22 でサーバー起動
cd /Users/sooh/Devs/iphone_mac_connector/mac-server
volta run --node 22 npm run start-with-token

# ポート占有確認
lsof -nP -iTCP:8767 -sTCP:LISTEN

# ログ監視
tail -f ~/.terminal-gateway/audit.log
```

## 停止方法

サーバーを起動したターミナルで `Ctrl + C`。

## 参考

- Mac サーバー詳細: `/Users/sooh/Devs/iphone_mac_connector/mac-server/README.md`
- iOS アプリ詳細: `/Users/sooh/Devs/iphone_mac_connector/ios-app/README.md`
