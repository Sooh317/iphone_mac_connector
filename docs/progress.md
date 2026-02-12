# 実装進捗

## Phase 1: Mac Gateway — プロジェクト初期化
- [x] 1.1 Node.js プロジェクト作成
- [x] 1.2 依存パッケージのインストール (ws, node-pty)
- [x] 1.3 ディレクトリ構成の作成 (src/, scripts/)

## Phase 2: Mac Gateway — 設定と認証
- [x] 2.1 設定ファイルの仕組み (config.js, config.json.example)
- [x] 2.2 トークン生成スクリプト (scripts/generate-token.js)
- [x] 2.3 認証モジュール (auth.js - Bearer token, timing-safe comparison)

## Phase 3: Mac Gateway — WebSocket サーバー
- [x] 3.1 HTTP サーバー + WebSocket アップグレード
- [x] 3.2 WebSocket 接続管理 (最大1接続)

## Phase 4: Mac Gateway — PTY 管理
- [x] 4.1 PTY の生成と管理 (pty-manager.js)
- [x] 4.2 PTY の入出力接続
- [x] 4.3 PTY のライフサイクル管理

## Phase 5: Mac Gateway — メッセージハンドリング
- [x] 5.1 受信メッセージのパース・ディスパッチ (message-handler.js)
- [x] 5.2 送信メッセージの整形 (output, error, heartbeat)
- [x] 5.3 Heartbeat 実装

## Phase 6: Mac Gateway — 監査ログ
- [x] 6.1 ログモジュール (logger.js - ~/.terminal-gateway/audit.log)
- [x] 6.2 記録するイベント (接続/切断/認証失敗)

## Phase 7: Mac Gateway — エラーハンドリングとシグナル処理
- [x] 7.1 グレースフルシャットダウン (SIGINT, SIGTERM)
- [x] 7.2 未ハンドル例外の処理

## Phase 8: Mac Gateway — npm scripts と起動確認
- [x] 8.1 npm scripts (start, generate-token)
- [ ] 8.2 手動起動テスト

## Phase 9-17: iOS クライアント
- [ ] 未着手

## Phase 18: launchd による常駐化
- [ ] 未着手

## Phase 19-20: テスト・受け入れ基準チェック
- [ ] 未着手
