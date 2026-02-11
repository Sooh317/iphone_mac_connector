# 実装タスク一覧

> `docs/spec.md` に基づく MVP 実装タスク。
> ステータス: `[ ]` 未着手 / `[x]` 完了

---

## Phase 1: Mac Gateway — プロジェクト初期化

### 1.1 Node.js プロジェクト作成
- [ ] `mac-server/` に `npm init -y` で `package.json` を生成
- [ ] `name` を `terminal-gateway`、`version` を `0.1.0` に設定
- [ ] `"type": "module"` を追加（ESM 使用）
- [ ] `"engines": { "node": ">=18" }` を追加

### 1.2 依存パッケージのインストール
- [ ] `ws` をインストール（WebSocket サーバー）
- [ ] `node-pty` をインストール（擬似端末）
- [ ] `dotenv` をインストール（環境変数読み込み）※ または設定ファイル方式を採用

### 1.3 ディレクトリ構成の作成
- [ ] `mac-server/src/` ディレクトリ作成
- [ ] `mac-server/src/server.js` — エントリポイント
- [ ] `mac-server/src/auth.js` — トークン認証モジュール
- [ ] `mac-server/src/pty-manager.js` — PTY 管理モジュール
- [ ] `mac-server/src/logger.js` — 監査ログモジュール
- [ ] `mac-server/src/config.js` — 設定読み込みモジュール

---

## Phase 2: Mac Gateway — 設定と認証

### 2.1 設定ファイルの仕組み
- [ ] `mac-server/config.json` のテンプレートを作成（`.example` 付き）
  ```json
  {
    "host": "0.0.0.0",
    "port": 8765,
    "shell": "/bin/zsh",
    "tokenFile": "~/.terminal-gateway-token"
  }
  ```
- [ ] `config.js`: `config.json` を読み込み、デフォルト値とマージする関数を実装
- [ ] `config.js`: ポート番号・ホストのバリデーションを実装

### 2.2 トークン生成スクリプト
- [ ] `mac-server/scripts/generate-token.js` を作成
- [ ] `crypto.randomBytes(32)` で 32 バイトの CSPRNG トークンを生成
- [ ] トークンを `~/.terminal-gateway-token` に書き出し
- [ ] ファイル権限を `0600` に設定（`fs.chmod`）
- [ ] 生成されたトークンを標準出力に 1 回だけ表示（iPhone 設定用）

### 2.3 認証モジュール
- [ ] `auth.js`: トークンファイルの読み込み関数を実装
- [ ] `auth.js`: `Authorization: Bearer <token>` ヘッダーの検証関数を実装
- [ ] `auth.js`: タイミング攻撃を防ぐため `crypto.timingSafeEqual` を使用
- [ ] `auth.js`: トークン不一致時に `401` を返す処理

---

## Phase 3: Mac Gateway — WebSocket サーバー

### 3.1 HTTP サーバー + WebSocket アップグレード
- [ ] `server.js`: `http.createServer` で HTTP サーバーを作成
- [ ] `server.js`: `ws.Server` を `noServer: true` で作成
- [ ] `server.js`: `upgrade` イベントで認証チェックを実行
- [ ] 認証成功時のみ `wss.handleUpgrade` で WebSocket 接続を確立
- [ ] 認証失敗時は `401` レスポンスを返しソケットを破棄
- [ ] Listen アドレスを設定ファイルのホストに制限

### 3.2 WebSocket 接続管理
- [ ] 接続時にクライアント情報をログに記録（接続時刻、接続元 IP）
- [ ] `close` イベントで切断時刻をログに記録
- [ ] `error` イベントでエラーをログに記録
- [ ] 同時接続は 1 つのみに制限（2 つ目は拒否）

---

## Phase 4: Mac Gateway — PTY 管理

### 4.1 PTY の生成と管理
- [ ] `pty-manager.js`: `node-pty.spawn` で `zsh` を起動する関数を実装
- [ ] 起動時のデフォルト端末サイズを設定（cols: 80, rows: 24）
- [ ] PTY プロセスの参照を保持する仕組みを実装

### 4.2 PTY の入出力接続
- [ ] PTY の `onData` イベントで出力を受け取り、WebSocket に `output` メッセージとして送信
- [ ] WebSocket から `input` メッセージを受け取り、PTY の `write` に渡す
- [ ] WebSocket から `resize` メッセージを受け取り、PTY の `resize` を呼び出す

### 4.3 PTY のライフサイクル管理
- [ ] WebSocket 切断時に PTY プロセスを `kill` する
- [ ] PTY プロセスの `onExit` イベントで WebSocket に `error` メッセージを送信し接続を閉じる
- [ ] 異常終了時のクリーンアップ処理を実装

---

## Phase 5: Mac Gateway — メッセージハンドリング

### 5.1 受信メッセージのパース・ディスパッチ
- [ ] WebSocket `message` イベントで JSON パースを実装
- [ ] パース失敗時に `error` メッセージを返す
- [ ] `type` フィールドによるメッセージの振り分け（switch/map）
  - `input` → PTY `write`
  - `resize` → PTY `resize`
  - `heartbeat` → heartbeat 応答

### 5.2 送信メッセージの整形
- [ ] PTY 出力を `{"type":"output","data":"..."}` 形式で送信する関数
- [ ] エラーを `{"type":"error","message":"..."}` 形式で送信する関数

### 5.3 Heartbeat 実装
- [ ] クライアントからの `heartbeat` メッセージに応答する処理
- [ ] サーバー側から定期的（30 秒間隔）に heartbeat を送信
- [ ] 一定時間（90 秒）heartbeat 応答がない場合、接続を切断

---

## Phase 6: Mac Gateway — 監査ログ

### 6.1 ログモジュール
- [ ] `logger.js`: ログ出力先を設定（ファイル + stdout）
- [ ] ログフォーマット: `[ISO8601タイムスタンプ] [LEVEL] メッセージ`
- [ ] ログファイルパス: `~/.terminal-gateway/audit.log`
- [ ] ログディレクトリが存在しない場合は自動作成

### 6.2 記録するイベント
- [ ] 接続試行（成功/失敗、接続元 IP、時刻）
- [ ] 認証失敗（時刻、接続元 IP）
- [ ] 切断（時刻、理由）
- [ ] サーバー起動・停止

---

## Phase 7: Mac Gateway — エラーハンドリングとシグナル処理

### 7.1 グレースフルシャットダウン
- [ ] `SIGTERM` / `SIGINT` シグナルをキャッチ
- [ ] アクティブな WebSocket 接続を閉じる
- [ ] PTY プロセスを終了する
- [ ] HTTP サーバーを閉じる
- [ ] ログにシャットダウンを記録

### 7.2 未ハンドル例外の処理
- [ ] `uncaughtException` でエラーをログに記録し安全に終了
- [ ] `unhandledRejection` でエラーをログに記録

---

## Phase 8: Mac Gateway — npm scripts と起動確認

### 8.1 npm scripts
- [ ] `"start": "node src/server.js"` を追加
- [ ] `"generate-token": "node scripts/generate-token.js"` を追加

### 8.2 手動起動テスト
- [ ] `npm run generate-token` でトークンが生成されることを確認
- [ ] `npm start` でサーバーが起動し、ログが出力されることを確認
- [ ] `wscat` 等で WebSocket 接続し、認証が機能することを確認
- [ ] 入力を送信し、PTY 出力が返ってくることを確認

---

## Phase 9: iOS クライアント — Xcode プロジェクト作成

### 9.1 プロジェクト初期化
- [ ] Xcode で SwiftUI App テンプレートから新規プロジェクト作成
  - Product Name: `IphoneMacConnector`
  - Bundle Identifier: 適切な値を設定
  - Deployment Target: iOS 16.0 以上
- [ ] プロジェクトを `ios-app/IphoneMacConnector/` に配置

### 9.2 プロジェクト構成
- [ ] `Models/` グループ作成
- [ ] `Views/` グループ作成
- [ ] `Services/` グループ作成
- [ ] `Utilities/` グループ作成

---

## Phase 10: iOS クライアント — データモデル

### 10.1 メッセージモデル
- [ ] `Models/Message.swift` を作成
- [ ] `WSMessage` 構造体を定義（`type`, `data`, `message`, `cols`, `rows`, `ts` フィールド）
- [ ] `Codable` 準拠で JSON エンコード/デコードを実装
- [ ] メッセージタイプの `enum` を定義（`input`, `output`, `resize`, `error`, `heartbeat`）

### 10.2 接続設定モデル
- [ ] `Models/ConnectionConfig.swift` を作成
- [ ] `host: String`, `port: Int`, `token: String` を保持
- [ ] Keychain 保存/読み込み用のインターフェースを定義

---

## Phase 11: iOS クライアント — Keychain 管理

### 11.1 Keychain ラッパー
- [ ] `Services/KeychainService.swift` を作成
- [ ] `save(token:)` 関数: トークンを Keychain に保存
- [ ] `loadToken()` 関数: Keychain からトークンを読み込み
- [ ] `deleteToken()` 関数: Keychain からトークンを削除
- [ ] `kSecClassGenericPassword` を使用
- [ ] エラーハンドリング（保存失敗、読み込み失敗）

---

## Phase 12: iOS クライアント — WebSocket サービス

### 12.1 WebSocket 接続管理
- [ ] `Services/WebSocketService.swift` を作成
- [ ] `URLSessionWebSocketTask` を使用した接続処理
- [ ] 接続 URL の構築: `ws://<host>:<port>`
- [ ] `Authorization: Bearer <token>` ヘッダーの付与
- [ ] 接続状態の管理（`enum`: `disconnected`, `connecting`, `connected`, `error`）
- [ ] `@Published` プロパティで状態変更を SwiftUI に通知

### 12.2 メッセージ送信
- [ ] `sendInput(_:)` 関数: `input` メッセージを送信
- [ ] `sendResize(cols:rows:)` 関数: `resize` メッセージを送信
- [ ] `sendHeartbeat()` 関数: `heartbeat` メッセージを送信

### 12.3 メッセージ受信
- [ ] 受信ループの実装（`receive()` の再帰呼び出し）
- [ ] 受信メッセージの JSON デコード
- [ ] `type` に応じたハンドリング
  - `output` → 出力バッファに追加
  - `error` → エラー表示
  - `heartbeat` → タイムスタンプ更新

### 12.4 切断処理
- [ ] `disconnect()` 関数: WebSocket を正常に閉じる
- [ ] 接続エラー時の自動切断処理
- [ ] 切断理由のログ出力

### 12.5 Heartbeat 管理
- [ ] `Timer` で 30 秒ごとに heartbeat を送信
- [ ] サーバーからの heartbeat 応答を監視
- [ ] タイムアウト（90 秒）時に接続を切断

---

## Phase 13: iOS クライアント — ターミナル出力管理

### 13.1 出力バッファ
- [ ] `Services/TerminalOutputManager.swift` を作成
- [ ] 受信した `output` データを蓄積するバッファ
- [ ] バッファサイズの上限設定（古いデータの破棄）
- [ ] `@Published` プロパティで SwiftUI に通知
- [ ] ANSI エスケープシーケンスの簡易ストリップ（または将来のターミナルエミュレータ対応を見据えてそのまま保持）

---

## Phase 14: iOS クライアント — 接続設定画面

### 14.1 接続設定ビュー
- [ ] `Views/ConnectionSettingsView.swift` を作成
- [ ] `host` 入力欄（TextField、キーボードタイプ: URL）
- [ ] `port` 入力欄（TextField、キーボードタイプ: numberPad、デフォルト: 8765）
- [ ] `token` 入力欄（SecureField、平文非表示）
- [ ] 「保存」ボタン → Keychain にトークンを保存、host/port を UserDefaults に保存
- [ ] 「接続」ボタン → WebSocket 接続を開始
- [ ] 入力バリデーション（空チェック、ポート番号範囲）

---

## Phase 15: iOS クライアント — ターミナル画面

### 15.1 ターミナル出力ビュー
- [ ] `Views/TerminalView.swift` を作成
- [ ] `ScrollView` + `Text` でターミナル出力を表示
- [ ] モノスペースフォント（`system(.body, design: .monospaced)`）
- [ ] 黒背景 + 緑/白文字のターミナル風スタイル
- [ ] 新しい出力が来たら自動スクロール
- [ ] 出力テキストの選択・コピー対応

### 15.2 入力欄
- [ ] `Views/CommandInputView.swift` を作成
- [ ] `TextField` + 送信ボタン
- [ ] Enter キーで送信（`\n` を付与して `input` メッセージ送信）
- [ ] 送信後に入力欄をクリア
- [ ] コマンド履歴の保持（直近 20 件程度、上下キーで辿れる UI は MVP 外、リスト表示で対応）

### 15.3 接続状態表示
- [ ] 画面上部に接続状態を表示（色分け: 緑=接続中、黄=接続中…、赤=切断）
- [ ] 接続先ホスト名を表示
- [ ] 「切断」ボタンの配置

---

## Phase 16: iOS クライアント — メイン画面統合

### 16.1 画面遷移
- [ ] `Views/ContentView.swift` をメインエントリとして構成
- [ ] 未接続時: 接続設定画面を表示
- [ ] 接続中: ターミナル画面を表示
- [ ] 設定変更用のナビゲーション（歯車アイコン等）

### 16.2 ViewModel 統合
- [ ] `WebSocketService` と `TerminalOutputManager` を `@StateObject` / `@EnvironmentObject` で管理
- [ ] 接続状態に応じた画面切り替えロジック

---

## Phase 17: iOS クライアント — ビルドと実機テスト

### 17.1 ビルド確認
- [ ] Xcode でビルドが成功することを確認
- [ ] シミュレーターで画面表示を確認

### 17.2 実機テスト（Tailscale 環境）
- [ ] iPhone 実機にインストール
- [ ] Mac Gateway を起動した状態で接続テスト
- [ ] コマンド送信・出力表示の動作確認

---

## Phase 18: launchd による常駐化

### 18.1 plist ファイルの作成
- [ ] `mac-server/com.terminal-gateway.plist` を作成
- [ ] `Label`: `com.terminal-gateway`
- [ ] `ProgramArguments`: `["node", "<absolute-path>/src/server.js"]`
- [ ] `RunAtLoad`: `true`
- [ ] `KeepAlive`: `true`
- [ ] `StandardOutPath` / `StandardErrorPath`: ログファイルパス
- [ ] `UserName`: 現在のユーザー（非 root）

### 18.2 インストールスクリプト
- [ ] `mac-server/scripts/install-launchd.sh` を作成
- [ ] plist を `~/Library/LaunchAgents/` にコピー
- [ ] `launchctl load` で登録
- [ ] 動作確認メッセージを表示

### 18.3 アンインストールスクリプト
- [ ] `mac-server/scripts/uninstall-launchd.sh` を作成
- [ ] `launchctl unload` で登録解除
- [ ] plist を削除

---

## Phase 19: 異常系テスト

### 19.1 認証テスト
- [ ] 正しいトークンで接続成功を確認
- [ ] 誤ったトークンで接続拒否（401）を確認
- [ ] トークンなしで接続拒否を確認

### 19.2 接続・切断テスト
- [ ] 正常切断後の再接続が成功することを確認
- [ ] ネットワーク切断からの回復を確認
- [ ] サーバー再起動後にクライアントが再接続できることを確認

### 19.3 PTY テスト
- [ ] 長時間実行コマンド中の切断で PTY が正しく終了することを確認
- [ ] 大量出力時にバッファオーバーフローしないことを確認

### 19.4 Heartbeat テスト
- [ ] heartbeat タイムアウト時に自動切断されることを確認

---

## Phase 20: 最終確認・受け入れ基準チェック

- [ ] iPhone から MacBook へ Tailscale 経由で接続できる
- [ ] 正しいトークンでのみ接続できる
- [ ] 誤トークンで接続拒否される
- [ ] 入力コマンド実行結果が iPhone 画面に表示される
- [ ] 切断/再接続が正常に動作する
- [ ] 監査ログに接続イベントが残る
- [ ] トークンファイルの権限が `600` である
- [ ] Gateway が非 root ユーザーで動作している
