# AWS 학생 실습 환경 관리

Terraform으로 학생별 AWS 실습 환경을 일괄 프로비저닝하고, 예산 초과 시 자동으로 리소스를 중지하는 킬 스위치를 구성합니다.

---

## 생성되는 리소스

| 리소스     | 이름                               | 용도                                                       |
| ---------- | ---------------------------------- | ---------------------------------------------------------- |
| IAM User   | `{student}`                        | 학생별 AWS 콘솔 로그인 계정                                |
| IAM Policy | `student-{student}-tag-enforce`    | 리소스 생성 시 Owner 태그 강제                             |
| AWS Budget | `student-{student}-monthly-budget` | 학생별 월 예산 설정 및 알림                                |
| SNS Topic  | `student-budget-warning`           | 50%, 80% 초과 시 관리자 이메일 알림                        |
| SNS Topic  | `student-budget-kill`              | 100% 초과 시 관리자 이메일 알림 및 Lambda 킬 스위치 트리거 |
| Lambda     | `student-budget-kill-switch`       | EC2 중지, EIP 해제, S3 차단, RDS 중지                      |
| SQS        | `student-kill-switch-dlq`          | Lambda 실패 메시지 보관                                    |
| CloudTrail | `student-lab-trail`                | 전체 API 호출 기록 (Management Events)                     |
| S3 Bucket  | `student-lab-cloudtrail-{account}` | CloudTrail 로그 저장                                       |

---

## 사전 준비

1. **강의 2일 전에 `terraform apply` 실행** — IAM 사용자 등 리소스에 `Owner` 태그가 생성되어야 다음 단계가 가능
2. **AWS Cost Explorer**에서 `Owner` 태그를 비용 할당 태그로 활성화
   - AWS 콘솔 → Billing and Cost Management → Cost Allocation Tags → `Owner` 체크 → Activate
   - `terraform apply` 후 태그 목록에 나타나기까지 최대 24시간, 활성화 후 Budget 필터 반영까지 추가 24시간 소요

---

## 배포

> **다른 AWS 계정(예: 학교 계정)에 배포할 경우** `student-lab/providers.tf`의 워크스페이스 이름을 변경한 후 `terraform init`을 다시 실행합니다.
>
> ```hcl
> workspaces {
>   name = "새-워크스페이스-이름"
> }
> ```

두 가지 방법 중 하나를 선택합니다.

### 방법 A: Terraform Cloud (권장)

별도 설치 없이 웹 브라우저에서 실행합니다.

1. [Terraform Cloud](https://app.terraform.io) → `aws-student-lab-test` 워크스페이스
2. **Settings → Version Control** → GitHub 연결 → 이 레포 선택 → Working Directory: `student-lab`
3. **Variables 탭**에서 아래 값 설정

   | 종류            | 키                      | 값                                |
   | --------------- | ----------------------- | --------------------------------- |
   | Environment     | `AWS_ACCESS_KEY_ID`     | AWS 자격증명                      |
   | Environment     | `AWS_SECRET_ACCESS_KEY` | AWS 자격증명 (Sensitive)          |
   | Environment     | `AWS_REGION`            | `ap-northeast-2`                  |
   | Terraform (HCL) | `students`              | `["alice", "bob", ...]`           |
   | Terraform (HCL) | `student_budget_limits` | `{"alice" = 40, ...}`             |
   | Terraform (HCL) | `student_emails`        | `{"alice" = "alice@example.com"}` |
   | Terraform       | `lab_admin_email`       | 관리자 이메일                     |
   | Terraform       | `budget_limit_usd`      | 기본 예산 (숫자)                  |

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

---

### 배포 후 학생 로그인 정보 확인

```bash
terraform output -json student_console_credentials
```

출력된 `sign_in_url`, `username`, `temp_password`를 학생에게 개별 전달합니다.
학생은 첫 로그인 시 비밀번호를 변경해야 합니다.

> 만약 비밀번호에 `\u0026`이 포함된 경우 `&`로 치환하면 됩니다.

---

## 학생 실습 안내

학생은 AWS 콘솔에서 직접 리소스를 생성합니다. 아래 규칙을 반드시 지켜야 합니다.

- 모든 리소스 생성 시 태그를 추가해야 합니다.
  - **Key**: `Owner`
  - **Value**: 본인 이름 (예: `alice`)
- 태그 없이 생성하면 `AccessDenied` 오류가 발생합니다.
- 생성 후 `Owner` 태그를 삭제하거나 수정할 수 없습니다.

---

## 예산 알림

| 사용량    | 동작                                            |
| --------- | ----------------------------------------------- |
| 50% 초과  | 관리자 이메일 알림                              |
| 80% 초과  | 관리자 이메일 알림                              |
| 100% 초과 | Lambda 킬 스위치 자동 실행 + 관리자 이메일 알림 |

> 킬 스위치는 EC2 중지 → EIP 해제 → S3 접근 차단 → RDS 중지 순으로 동작합니다.
> AWS Budgets 특성상 최대 24시간 지연이 발생할 수 있습니다.

---

## 킬 스위치 발동 후 복구

**학생이 직접 복구 가능:**

- EC2: 콘솔에서 인스턴스 선택 → 시작
- RDS: 콘솔에서 DB 인스턴스 선택 → 시작

**관리자만 복구 가능 (S3 Deny 정책 제거):**

```bash
aws s3api delete-bucket-policy --bucket <bucket-name>
```

---

## 실습 종료 후 전체 삭제

```bash
terraform destroy
```
