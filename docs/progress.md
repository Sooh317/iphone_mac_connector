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
- [x] 8.2 手動起動テスト (ローカル環境で確認完了)

## Phase 9: iOS クライアント — Xcode プロジェクト作成
- [x] 9.1 プロジェクト初期化 (SwiftUI App, iOS 16.0+)
- [x] 9.2 プロジェクト構成 (Models/, Views/, Services/, Utilities/)

## Phase 10: iOS クライアント — データモデル
- [x] 10.1 メッセージモデル (Message.swift - WebSocket メッセージ)
- [x] 10.2 接続設定モデル (ConnectionConfig.swift)

## Phase 11: iOS クライアント — Keychain 管理
- [x] 11.1 Keychain ラッパー (KeychainService.swift - kSecClassGenericPassword)

## Phase 12: iOS クライアント — WebSocket サービス
- [x] 12.1 WebSocket 接続管理 (URLSessionWebSocketTask)
- [x] 12.2 メッセージ送信 (sendInput, sendResize, sendHeartbeat)
- [x] 12.3 メッセージ受信 (出力、エラー、heartbeat 処理)
- [x] 12.4 切断処理
- [x] 12.5 Heartbeat 管理 (30秒間隔、自動再接続)

## Phase 13: iOS クライアント — ターミナル出力管理
- [x] 13.1 出力バッファ (TerminalOutputManager.swift - 10000行上限)

## Phase 14: iOS クライアント — 接続設定画面
- [x] 14.1 接続設定ビュー (ConnectionSettingsView.swift - host/port/token入力)

## Phase 15: iOS クライアント — ターミナル画面
- [x] 15.1 ターミナル出力ビュー (TerminalView.swift - モノスペース、自動スクロール)
- [x] 15.2 入力欄 (CommandInputView.swift - コマンド履歴50件)
- [x] 15.3 接続状態表示

## Phase 16: iOS クライアント — メイン画面統合
- [x] 16.1 画面遷移 (ContentView.swift)
- [x] 16.2 ViewModel 統合

## Phase 17: iOS クライアント — ビルドと実機テスト
- [ ] 17.1 ビルド確認
- [ ] 17.2 実機テスト（Tailscale 環境）

## Phase 18: launchd による常駐化
- [x] 18.1 plist ファイルの作成 (com.terminal-gateway.plist)
- [x] 18.2 インストールスクリプト (install-launchd.sh)
- [x] 18.3 アンインストールスクリプト (uninstall-launchd.sh)

## Phase 19: 異常系テスト
- [x] テストファイル作成（auth.test.js, connection.test.js, pty.test.js, iOS XCTest 4 ファイル）
- [ ] iOS テストターゲット追加（21.1 で対応中）
- [x] テスト実行環境の整備（21.3〜21.5 の修正完了）
- [~] Node.js テスト実行（8/17 テスト成功、残り9テストはタイミング問題）
- [ ] 全テスト PASS 確認

## Phase 20: 受け入れ基準チェック
- [ ] 未着手（実機テスト後に実施）

## Phase 21: Codex レビュー指摘修正（第2回）
- [ ] 21.1 [Critical] iOS テストターゲットを Xcode プロジェクトに追加
- [x] 21.2 [High] iOS テストコードの API 不整合を修正
- [x] 21.3 [High] Node.js auth テストの実装不整合を修正
- [x] 21.4 [High] MagicDNS 扱いの整合性を修正
- [x] 21.5 [Medium] Mac 統合テストのハードニング対応
- [x] 21.6 [Medium] Info.plist から不要な SceneDelegate 参照を削除
- [x] 21.7 [Medium] progress.md を実態に合わせて更新
