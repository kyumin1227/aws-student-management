# AWS 학생 실습 환경 관리

Terraform으로 학생별 AWS 실습 환경을 일괄 프로비저닝하고, 예산 초과 시 자동으로 리소스를 중지하는 킬 스위치를 구성합니다.

---

## 사전 준비

1. **Terraform** 1.5.0 이상 설치
2. **AWS CLI** 설치 및 자격증명 설정
   ```bash
   aws configure
   ```
3. **강의 2일 전에 `terraform apply` 실행** — IAM 사용자 등 리소스에 `Owner` 태그가 생성되어야 다음 단계가 가능
4. **AWS Cost Explorer**에서 `Owner` 태그를 비용 할당 태그로 활성화
   - AWS 콘솔 → Billing and Cost Management → Cost Allocation Tags → `Owner` 체크 → Activate
   - `terraform apply` 후 태그 목록에 나타나기까지 최대 24시간, 활성화 후 Budget 필터 반영까지 추가 24시간 소요

---

## 배포

### 1. 초기화

```bash
terraform init
```

### 2. 설정 파일 작성

`terraform.tfvars.example`을 복사해서 실제 값을 입력합니다.

```bash
cp terraform.tfvars.example terraform.tfvars
```

이후 `terraform.tfvars`를 열어 학생 목록, 강사 이메일 등을 입력합니다.

> `terraform.tfvars`는 `.gitignore`에 포함되어 있어 GitHub에 올라가지 않습니다.

### 3. 플랜 확인

```bash
terraform plan
```

### 4. 배포

```bash
terraform apply
```

### 5. 학생 로그인 정보 확인

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

| 사용량    | 동작                       |
| --------- | -------------------------- |
| 50% 초과  | 강사 이메일 알림           |
| 80% 초과  | 강사 이메일 알림           |
| 100% 초과 | Lambda 킬 스위치 자동 실행 |

> 킬 스위치는 EC2 중지 → EIP 해제 → S3 접근 차단 → RDS 중지 순으로 동작합니다.
> AWS Budgets 특성상 최대 24시간 지연이 발생할 수 있습니다.

---

## 킬 스위치 발동 후 복구

학생 리소스가 중지된 경우 강사가 수동으로 복구합니다.

```bash
# EC2 재시작
aws ec2 start-instances --instance-ids <instance-id>

# S3 버킷 정책 제거
aws s3api delete-bucket-policy --bucket <bucket-name>
```

---

## 실습 종료 후 전체 삭제 (학생 개별 IAM 전체 삭제)

```bash
terraform destroy
```
