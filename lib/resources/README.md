# 新規リソースタイプの追加手順

## 1. モジュールファイルを作成

`lib/resources/<resource-type>.sh` を新規作成する。

## 2. 必須関数を実装

- `fetch_<resource>_config <name> [profile]` … 指定リソースの設定を JSON で標準出力
- `list_<resource>_names [profile]` … 対象リソース名の一覧を標準出力（オプション）

## 3. aws-diff.sh に登録

`aws-diff.sh` の `case "$resource_type" in` に新しいリソースタイプを追加する。

```bash
case "$resource_type" in
  iam-role)
    source "$SCRIPT_DIR/lib/resources/iam-role.sh"
    ;;
  your-resource)
    source "$SCRIPT_DIR/lib/resources/your-resource.sh"
    ;;
  ...
esac
```

`main` 内の `fetch_iam_role_config` 呼び出しを、リソースタイプに応じてディスパッチするように変更する。

## 4. 共通処理の追加（必要に応じて）

`lib/common.sh` にリソース共通の処理を追加する。
