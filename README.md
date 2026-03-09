# aws-diff

AWS リソースの設定値を取得し、環境間の差分を取るシェルスクリプト。

## 使い方

```bash
./aws-diff.sh iam-role dev-MyRole1 prd-MyRole1 --env-id '(dev-|prd-)'
```

- 第1引数: リソースタイプ（例: `iam-role`）
- 第2引数: from 環境のリソース名
- 第3引数: to 環境のリソース名
- `--env-id`: 環境プレフィックスを除去する正規表現（マッチ部分を空文字に置換）。JSON 内の値にマッチさせるため `^(dev-|prd-)` より `(dev-|prd-)` を推奨

## オプション

| オプション | 説明 |
|-----------|------|
| `--from-profile PROFILE` | from 環境の AWS プロファイル |
| `--to-profile PROFILE` | to 環境の AWS プロファイル |
| `--from-region REGION` | from 環境のリージョン（Lambda, SQS, DynamoDB, API Gateway） |
| `--to-region REGION` | to 環境のリージョン |
| `--env-id PATTERN` | 環境プレフィックス除去用の正規表現 |
| `--replace PAT REPL` | カスタム置換（pattern, replacement） |
| `--replace-file PATH` | 置換ルールファイル（`pattern<TAB>replacement` の行） |
| `--no-default-exclude` | デフォルト除外（ARN, ID, 日付）を無効化 |

## デフォルト除外

以下のパターンは diff 前にプレースホルダに置換される:

- **ARN 形式** (`arn:aws:...`)
- **ID 系** (RoleId, UserId, PolicyId 等: `AROA...`, `AIDA...`, `ANPA...`)
- **日付・時刻** (ISO 8601 形式)
- **UUID** (イベントソースマッピング等の UUID 形式)
- **EC2 系 ID** (acl-, vpce-, sg-, rtb-, vpc-, subnet- 等)

## 依存関係

- AWS CLI v2
- jq
- python3（AssumeRolePolicyDocument の URL デコード用）
- perl または sed（正規表現置換用）

## 対応リソースタイプ

| リソース | resource_type | リージョン |
|----------|---------------|------------|
| IAM ロール | `iam-role` | 不要 |
| Lambda | `lambda` | 必要 |
| S3 バケット | `s3-bucket` | 不要 |
| API Gateway | `api-gateway` | 必要 |
| SQS | `sqs` | 必要 |
| IAM ポリシー | `iam-policy` | 不要 |
| DynamoDB | `dynamodb` | 必要 |
| Network ACL | `network-acl` | 必要 |
| EventBridge | `eventbridge` | 必要 |
| VPC Endpoint | `vpc-endpoint` | 必要 |
| Step Functions | `stepfunctions` | 必要 |
| Security Group | `security-group` | 必要 |
| ECR | `ecr` | 必要 |
| Route Table | `route-table` | 必要 |

## 各リソースの差分検知

各リソースタイプごとに、**検知する差分**・**検知しない差分**（意図的に除外）・**検知できない差分**（取得対象外）をまとめる。

### 共通（全リソース）

| 種別 | 内容 |
|------|------|
| **検知しない** | ARN、RoleId/PolicyId 等の ID（AROA/AIDA/ANPA...）、日付・時刻（ISO 8601）。`--no-default-exclude` で無効化可能 |
| **検知できない** | 取得 API に含まれない項目、別リソースに紐づく設定 |

---

### IAM ロール (`iam-role`)

| 種別 | 内容 |
|------|------|
| **検知する** | ロール名、AssumeRolePolicyDocument、アタッチ済みマネージドポリシー一覧、インラインポリシーの PolicyDocument、パス、説明 |
| **検知しない** | RoleId、Arn、CreateDate（デフォルト除外） |
| **検知できない** | タグ、Permissions boundary、インスタンスプロファイル紐づけ |

---

### Lambda (`lambda`)

| 種別 | 内容 |
|------|------|
| **検知する** | ランタイム、メモリ、タイムアウト、ハンドラ、環境変数、VPC 設定、ReservedConcurrency、DeadLetterConfig、**イベントソースマッピング**（Kinesis/DynamoDB Streams/SQS 等）、**リソースベースポリシー**（API Gateway/S3/EventBridge 等のトリガー） |
| **検知しない** | Role ARN、CodeSha256、CodeSize、LastModified、RevisionId、Layers、UUID（除外） |
| **検知できない** | 関数コード本体、レイヤー（ARN 一覧・中身）、バージョン・エイリアス詳細、Lambda@Edge のエッジ設定 |

---

### S3 バケット (`s3-bucket`)

| 種別 | 内容 |
|------|------|
| **検知する** | ACL、バケットポリシー、バージョニング、パブリックアクセスブロック、サーバーサイド暗号化 |
| **検知しない** | ポリシー内の ARN（デフォルト除外） |
| **検知できない** | オブジェクト一覧・中身、ライフサイクル、CORS、レプリケーション、ログ設定、イベント通知、Inventory、オブジェクトロック |

---

### API Gateway (`api-gateway`)

| 種別 | 内容 |
|------|------|
| **検知する** | API 基本設定（名前・説明・エンドポイントタイプ等）、リソースツリー、メソッド（GET/POST 等）の有無、ステージ設定 |
| **検知しない** | API ID、リソース ID、デプロイ ID（デフォルト除外） |
| **検知できない** | 統合（Integration）の詳細、API Key 使用量、カスタムドメイン、VPC Link、モデル・マッピングテンプレート |

---

### SQS (`sqs`)

| 種別 | 内容 |
|------|------|
| **検知する** | VisibilityTimeout、MessageRetentionPeriod、DelaySeconds、ReceiveMessageWaitTimeSeconds、ポリシー、RedrivePolicy、FifoQueue 等の全属性 |
| **検知しない** | キュー URL 内のアカウント ID、ポリシー内の ARN（デフォルト除外） |
| **検知できない** | キュー内メッセージ、タグ |

---

### IAM ポリシー (`iam-policy`)

| 種別 | 内容 |
|------|------|
| **検知する** | PolicyDocument（Statement、Effect、Action、Resource、Condition 等） |
| **検知しない** | PolicyId、Arn、CreateDate、UpdateDate（デフォルト除外） |
| **検知できない** | タグ、バージョン履歴（デフォルト以外） |

---

### DynamoDB (`dynamodb`)

| 種別 | 内容 |
|------|------|
| **検知する** | テーブル名、キースキーマ、属性定義、プロビジョンド/オンデマンド、GSI/LSI、ストリーム、TTL、Point-in-Time Recovery 等 |
| **検知しない** | TableId、TableArn、CreationDateTime、ItemCount、TableSizeBytes（デフォルト除外） |
| **検知できない** | テーブル内アイテム、タグ、バックアップ一覧 |

---

### Network ACL (`network-acl`)

| 種別 | 内容 |
|------|------|
| **検知する** | Entries（インバウンド/アウトバウンドルール）、Associations、IsDefault、Tags |
| **検知しない** | NetworkAclId、VpcId、SubnetId（デフォルト除外） |
| **検知できない** | フローログ、ネットワークインターフェース詳細 |

---

### EventBridge (`eventbridge`)

| 種別 | 内容 |
|------|------|
| **検知する** | ルール定義（EventPattern、ScheduleExpression、State）、ターゲット一覧 |
| **検知しない** | ターゲット ID 内の ARN（デフォルト除外） |
| **検知できない** | カスタムイベントバス、アーカイブ、リプレイ |

---

### VPC Endpoint (`vpc-endpoint`)

| 種別 | 内容 |
|------|------|
| **検知する** | PolicyDocument、ServiceName、VpcId、SubnetIds、SecurityGroupIds、RouteTableIds、PrivateDnsEnabled 等 |
| **検知しない** | VpcEndpointId、VpcId、SubnetId 等（デフォルト除外） |
| **検知できない** | エンドポイント経由のトラフィック、DNS レコード |

---

### Step Functions (`stepfunctions`)

| 種別 | 内容 |
|------|------|
| **検知する** | ステートマシン定義、ロール ARN、ロギング設定、トレース設定 |
| **検知しない** | StateMachineArn、CreationDate、Status（除外） |
| **検知できない** | 実行履歴、エイリアス、バージョン |

---

### Security Group (`security-group`)

| 種別 | 内容 |
|------|------|
| **検知する** | IpPermissions、IpPermissionsEgress、Description、VpcId、Tags |
| **検知しない** | GroupId、VpcId（デフォルト除外） |
| **検知できない** | 参照元・参照先のリソース一覧 |

---

### ECR (`ecr`)

| 種別 | 内容 |
|------|------|
| **検知する** | imageTagMutability、imageScanningConfiguration、encryptionConfiguration、ライフサイクルポリシー |
| **検知しない** | repositoryArn、registryId（デフォルト除外） |
| **検知できない** | イメージ一覧・タグ、レプリケーション設定 |

---

### Route Table (`route-table`)

| 種別 | 内容 |
|------|------|
| **検知する** | Routes、Associations、PropagatingVgws、VpcId、Tags |
| **検知しない** | RouteTableId、VpcId、SubnetId 等（デフォルト除外） |
| **検知できない** | 経路の実際の到達性 |

---

## 拡張

新規リソースタイプの追加手順は `lib/resources/README.md` を参照。
