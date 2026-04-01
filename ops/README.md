# 슬랙 앱 운영 IAM 인프라

슬랙 앱 배포 및 운영에 필요한 IAM 리소스를 Terraform으로 관리합니다.
GitHub Actions OIDC 인증, ECS 실행 권한, 로컬 개발용 IAM User를 포함합니다.

> **이 폴더는 학교 AWS Admin이 처음 한 번만 실행합니다.**
> 이후 앱 인프라 배포는 GitHub Actions에서 여기서 만든 Role을 사용해 수행합니다.

---

## 생성되는 리소스

| 리소스        | 이름                             | 용도                                      |
| ------------- | -------------------------------- | ----------------------------------------- |
| OIDC Provider | GitHub Actions                   | GitHub OIDC 인증 (AWS 계정당 1개)         |
| IAM Role      | `{app_name}-github-actions-role` | GitHub Actions에서 배포 시 assume         |
| IAM Role      | `{app_name}-ecs-task-role`       | ECS 컨테이너의 AWS API 접근               |
| IAM Role      | `{app_name}-ecs-execution-role`  | ECR 이미지 pull, CloudWatch 로그 쓰기     |
| IAM User      | `{app_name}-dev`                 | 로컬 개발 및 테스트용 (콘솔 + Access Key) |

---

## 처음 배포 (Bootstrap)

> **다른 AWS 계정(예: 학교 계정)에 배포할 경우** `ops/providers.tf`의 워크스페이스 이름을 변경한 후 `terraform init`을 다시 실행합니다.
>
> ```hcl
> workspaces {
>   name = "새-워크스페이스-이름"
> }
> ```

두 가지 방법 중 하나를 선택합니다.

### 방법 A: Terraform Cloud (권장)

별도 설치 없이 웹 브라우저에서 실행합니다.

1. [Terraform Cloud](https://app.terraform.io) → `aws-ops-test` 워크스페이스
2. **Settings → Version Control** → GitHub 연결 → 이 레포 선택 → Working Directory: `ops`
3. **Variables 탭**에서 아래 값 설정

   | 종류        | 키                      | 값                             |
   | ----------- | ----------------------- | ------------------------------ |
   | Environment | `AWS_ACCESS_KEY_ID`     | Admin AWS 자격증명             |
   | Environment | `AWS_SECRET_ACCESS_KEY` | Admin AWS 자격증명 (Sensitive) |
   | Environment | `AWS_REGION`            | `ap-northeast-2`               |
   | Terraform   | `app_name`              | 앱 이름 (예: `dept-slack-app`) |
   | Terraform   | `github_org`            | GitHub 조직명 또는 계정명      |
   | Terraform   | `github_repo`           | 슬랙 앱 레포 이름              |

4. **Runs 탭** → "Start new run" → Apply

### 방법 B: 로컬 CLI

**사전 설치 필요:**

- Terraform 1.5.0 이상
- AWS CLI 설치 및 자격증명 설정 (`aws configure`)

```bash
terraform init
cp terraform.tfvars.example terraform.tfvars
# terraform.tfvars 값 입력 후
terraform plan
terraform apply
```

> `terraform.tfvars`는 `.gitignore`에 포함되어 있어 GitHub에 올라가지 않습니다.

### 배포 후 개발자에게 전달할 정보

`terraform apply` 완료 후 아래 정보를 개발자에게 전달합니다.

| 항목                      | 확인 방법                                            |
| ------------------------- | ---------------------------------------------------- |
| 콘솔 로그인 URL           | `https://<account-id>.signin.aws.amazon.com/console` |
| username                  | `{app_name}-dev`                                     |
| 초기 비밀번호             | 아래 방법으로 확인 후 전달                           |
| `github_actions_role_arn` | 아래 방법으로 확인 후 전달                           |
| `ecs_task_role_arn`       | 아래 방법으로 확인 후 전달                           |
| `ecs_execution_role_arn`  | 아래 방법으로 확인 후 전달                           |

**방법 A (Terraform Cloud)**: 워크스페이스 → States → 최신 state → Download State → JSON에서 확인

**방법 B (로컬 CLI)**:

```bash
terraform output
terraform output dev_user_initial_password  # 비밀번호 (sensitive)
```

개발자는 첫 로그인 시 비밀번호를 변경해야 합니다.

---

## 개발자 가이드

### 로컬 개발용 Access Key 발급

콘솔에 로그인한 후 직접 발급합니다.

```
IAM → Users → {app_name}-dev → Security credentials → Create access key → CLI 선택
```

발급받은 키를 로컬 AWS CLI에 설정합니다.

```bash
aws configure --profile dev
# AWS Access Key ID: ...
# AWS Secret Access Key: ...
# Default region: ap-northeast-2
```

이후 로컬에서 `AWS_PROFILE=dev` 환경변수로 사용합니다.

```bash
AWS_PROFILE=dev terraform plan
AWS_PROFILE=dev aws ec2 describe-instances
```

### 앱 인프라 배포

Admin에게 전달받은 ARN을 앱 인프라 Terraform 및 GitHub에 설정합니다.

| 항목                      | 사용처                                         |
| ------------------------- | ---------------------------------------------- |
| `github_actions_role_arn` | GitHub Actions Secrets — `AWS_DEPLOY_ROLE_ARN` |
| `ecs_task_role_arn`       | ECS Task Definition `taskRoleArn`              |
| `ecs_execution_role_arn`  | ECS Task Definition `executionRoleArn`         |

**GitHub Actions workflow 설정 예시:**

```yaml
- uses: aws-actions/configure-aws-credentials@v4
  with:
    role-to-assume: ${{ secrets.AWS_DEPLOY_ROLE_ARN }}
    aws-region: ap-northeast-2
```

---

## IAM 구조

```
GitHub Actions (OIDC 토큰)
    └─ assume → github_actions_role (PowerUserAccess)
                IAM 직접 생성 불가, PassRole은 ECS 전용

ECS 플랫폼
    └─ assume → ecs_execution_role
                ECR pull, CloudWatch 로그, Secrets Manager 주입

ECS 컨테이너 (앱 코드)
    └─ assume → ecs_task_role
                S3, Secrets Manager (앱 데이터 접근)

로컬 개발자 (Access Key)
    └─ dev_user (PowerUserAccess)
```

> OIDC Provider는 AWS 계정당 동일 URL로 1개만 생성 가능합니다.
> 다른 레포에서 GitHub Actions를 사용할 경우 `data` source로 참조하세요.
>
> ```hcl
> data "aws_iam_openid_connect_provider" "github" {
>   url = "https://token.actions.githubusercontent.com"
> }
> ```
