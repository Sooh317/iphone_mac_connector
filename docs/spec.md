# iPhone -> MacBook Terminal Connector 仕様書

## 1. 目的
- iPhone から Tailscale 経由で MacBook のターミナルを安全に操作できるアプリを提供する。
- 個人利用を前提に、最小構成で安定動作する MVP を実装する。

## 2. スコープ
- 対象: iPhone 1 台から MacBook 1 台への接続のみ。
- 対応機能:
  - WebSocket 接続
  - ターミナル入力送信
  - 標準出力/標準エラー表示
  - セッション切断
  - 最小限の監査ログ
- 非対応（MVP外）:
  - 複数ユーザー管理
  - 複数端末切り替え
  - トークン自動ローテーション

## 3. 前提条件
- iPhone と MacBook は同一 Tailnet に参加済み。
- Tailscale ACL で `iPhone 1 台 -> MacBook 1 台` のみ許可済み。
- MacBook 側で常駐プロセスを実行可能。

## 4. システム構成

### 4.1 Mac 側（Terminal Gateway）
- 役割: iPhone から受け取った入力を PTY に渡し、PTY 出力を iPhone に返送する。
- 推奨実装:
  - Node.js
  - `ws`（WebSocket サーバー）
  - `node-pty`（擬似端末）
- 起動シェル: `zsh`
- 常駐方法: `launchd`

### 4.2 iPhone 側（Client App）
- 役割: WebSocket で Gateway に接続し、入力送信と出力表示を行う。
- 推奨実装:
  - SwiftUI
  - `URLSessionWebSocketTask`
- 画面要件:
  - 接続設定（Host, Port, Token）
  - 出力ビュー
  - 入力欄
  - 接続状態表示

### 4.3 通信経路
- iPhone -> Tailscale -> MacBook(Tailscale IP / MagicDNS) -> Gateway
- 通信プロトコル: WebSocket

## 5. セキュリティ要件

### 5.1 ネットワーク制御
- Tailscale ACL で接続元を iPhone 1 台、接続先を MacBook 1 台に限定する。
- Gateway の Listen は Tailscale インターフェースのみを許可する（可能な実装を採用）。

### 5.2 認証
- 固定の強い認証トークンを 1 本使用する。
- 要件:
  - 32 バイト以上の CSPRNG 生成値
  - Bearer トークンとして送信
  - URL クエリで送信しない
- ローテーションは実施しない（漏えい疑い時のみ手動再発行）。

### 5.3 トークン保護
- Mac 側:
  - 設定ファイル権限を `600` に制限
  - 非 root ユーザーで実行
- iPhone 側:
  - Keychain に保存
  - 画面表示時に平文露出しない

### 5.4 ログ
- 最小限の監査情報のみ記録:
  - 接続時刻
  - 接続成功/失敗
  - 切断時刻
- コマンド本文・出力全文は原則保存しない（機密漏えいリスク低減）。

## 6. 通信仕様

### 6.1 認証
- 接続時に `Authorization: Bearer <token>` を付与する。
- トークン不一致時は接続拒否。

### 6.2 メッセージ形式（JSON）
- `input`
  - クライアント -> サーバー
  - `{"type":"input","data":"ls -la\n"}`
- `output`
  - サーバー -> クライアント
  - `{"type":"output","data":"..."}`
- `resize`
  - クライアント -> サーバー
  - `{"type":"resize","cols":120,"rows":40}`
- `error`
  - サーバー -> クライアント
  - `{"type":"error","message":"..."}`
- `heartbeat`
  - 双方向
  - `{"type":"heartbeat","ts":1700000000}`

## 7. 実装ステップ
1. Mac Gateway の最小実装（WebSocket + PTY + 認証）
2. iOS クライアント最小実装（接続/入出力）
3. Tailscale ACL 適用確認（1対1制限）
4. `launchd` による常駐化
5. 監査ログ追加
6. 異常系テスト（認証失敗、切断、再接続）

## 8. 受け入れ基準
- iPhone から MacBook へ Tailscale 経由で接続できる。
- 正しいトークンでのみ接続できる。
- 誤トークンで接続拒否される。
- 入力コマンド実行結果が iPhone 画面に表示される。
- 切断/再接続が正常に動作する。
- 監査ログに接続イベントが残る。

## 9. 運用ルール
- トークンは初期設定後に共有経路を破棄する。
- 漏えい疑い時は即時トークン再発行し、iPhone 設定も更新する。
- Mac の OS 更新後に疎通確認を実施する。

## 10. 将来拡張（任意）
- コマンド許可リスト
- セッション録画
- 複数端末管理
- 生体認証連携強化
