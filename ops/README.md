# 슬랙 앱 운영 IAM 인프라

슬랙 앱 배포 및 운영에 필요한 IAM 리소스를 Terraform으로 관리합니다.
GitHub Actions OIDC 인증, ECS 실행 권한, 로컬 개발용 IAM User를 포함합니다.

> **이 폴더는 학교 AWS Admin이 처음 한 번만 실행합니다.**
> 이후 앱 인프라 배포는 GitHub Actions에서 여기서 만든 Role을 사용해 수행합니다.

---

## 생성되는 리소스

| 리소스 | 이름 | 용도 |
|---|---|---|
| OIDC Provider | GitHub Actions | GitHub OIDC 인증 (AWS 계정당 1개) |
| IAM Role | `{app_name}-github-actions-role` | GitHub Actions에서 배포 시 assume |
| IAM Role | `{app_name}-ecs-task-role` | ECS 컨테이너의 AWS API 접근 |
| IAM Role | `{app_name}-ecs-execution-role` | ECR 이미지 pull, CloudWatch 로그 쓰기 |
| IAM User | `{app_name}-dev` | 로컬 개발 및 테스트용 |

---

## 처음 배포 (Bootstrap)

### 사전 준비

- AWS Admin 계정 자격증명 (`AdministratorAccess` 권한 필요)
- Terraform 1.5.0 이상
- Terraform Cloud 계정 및 워크스페이스 (`aws-ops-test`)
  - 워크스페이스 Variables에 `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_REGION` 설정

### 배포

```bash
terraform init
cp terraform.tfvars.example terraform.tfvars
# terraform.tfvars 값 입력 후
terraform apply
```

### 개발자 계정 초기 비밀번호 확인

`terraform apply` 완료 후 초기 비밀번호를 확인해서 개발자에게 전달합니다.

```bash
terraform output dev_user_initial_password
```

개발자는 아래 URL로 콘솔에 로그인 후 비밀번호를 변경합니다.

```
https://<account-id>.signin.aws.amazon.com/console
```

### 로컬 개발용 Access Key 발급

개발자가 콘솔에 로그인한 후 직접 발급합니다.

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

---

## 앱 인프라 배포 (이후 작업)

ops에서 만든 ARN을 앱 인프라 Terraform에 전달합니다.

```bash
terraform output
```

| Output | 사용처 |
|---|---|
| `github_actions_role_arn` | GitHub Actions Secrets — `AWS_DEPLOY_ROLE_ARN` |
| `ecs_task_role_arn` | ECS Task Definition `taskRoleArn` |
| `ecs_execution_role_arn` | ECS Task Definition `executionRoleArn` |

### GitHub Actions workflow 설정 예시

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
> ```hcl
> data "aws_iam_openid_connect_provider" "github" {
>   url = "https://token.actions.githubusercontent.com"
> }
> ```
