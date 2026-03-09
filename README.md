# aws-diff

AWS リソースの設定値を取得し、環境間の差分を取るシェルスクリプト。

## 使い方

```bash
./aws-diff.sh iam-role Dev-MyRole1 Com-MyRole1 --env-id '(Dev-|Com-)'
```

- 第1引数: リソースタイプ（例: `iam-role`）
- 第2引数: from 環境のリソース名
- 第3引数: to 環境のリソース名
- `--env-id`: 環境プレフィックスを除去する正規表現（マッチ部分を空文字に置換）。JSON 内の値にマッチさせるため `^(Dev-|Com-)` より `(Dev-|Com-)` を推奨

## オプション

| オプション | 説明 |
|-----------|------|
| `--from-profile PROFILE` | from 環境の AWS プロファイル |
| `--to-profile PROFILE` | to 環境の AWS プロファイル |
| `--env-id PATTERN` | 環境プレフィックス除去用の正規表現 |
| `--replace PAT REPL` | カスタム置換（pattern, replacement） |
| `--replace-file PATH` | 置換ルールファイル（`pattern<TAB>replacement` の行） |
| `--no-default-exclude` | デフォルト除外（ARN, ID, 日付）を無効化 |

## デフォルト除外

以下のパターンは diff 前にプレースホルダに置換される:

- **ARN 形式** (`arn:aws:...`)
- **ID 系** (RoleId, UserId, PolicyId 等: `AROA...`, `AIDA...`, `ANPA...`)
- **日付・時刻** (ISO 8601 形式)

## 依存関係

- AWS CLI v2
- jq
- python3（AssumeRolePolicyDocument の URL デコード用）
- perl または sed（正規表現置換用）

## 拡張

新規リソースタイプの追加手順は `lib/resources/README.md` を参照。
