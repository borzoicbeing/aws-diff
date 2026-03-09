# 新規リソースタイプの追加手順

## 既存リソース

- `iam-role` … IAM ロール
- `lambda` … Lambda 関数（リージョン必要）
- `s3-bucket` … S3 バケット
- `api-gateway` … API Gateway REST API（リージョン必要）
- `sqs` … SQS キュー（リージョン必要）
- `iam-policy` … IAM カスタマーマネージドポリシー
- `dynamodb` … DynamoDB テーブル（リージョン必要）

## 1. モジュールファイルを作成

`lib/resources/<resource-type>.sh` を新規作成する。

## 2. 必須関数を実装

- `fetch_<resource>_config <name> [profile] [region]` … 指定リソースの設定を JSON で標準出力。リージョナルなリソースは第3引数に region を受け取る
- `list_<resource>_names [profile] [region]` … 対象リソース名の一覧を標準出力（オプション）

## 3. aws-diff.sh に登録

`aws-diff.sh` の `case "$resource_type" in` に新しいリソースタイプを追加する。リージョナルなリソースは `needs_region=true` を設定する。

## 4. 共通処理の追加（必要に応じて）

`lib/common.sh` にリソース共通の処理を追加する。
