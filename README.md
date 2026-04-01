# AWS Student Management

학과 AWS 환경 관리를 위한 Terraform 인프라 코드입니다.
슬랙 앱 운영 IAM 설정과 학생 실습 환경 관리 두 가지로 구성됩니다.

---

## 구성

```
aws-student-management/
├── ops/           # 슬랙 앱 운영 IAM 인프라
└── student-lab/   # 학생 실습 환경 관리
```

### [ops/](ops/)

슬랙 앱 배포 및 운영에 필요한 IAM 리소스를 구성합니다.

- GitHub Actions OIDC 인증 Role
- ECS Task / Execution Role
- 로컬 개발용 IAM User

### [student-lab/](student-lab/)

학생별 AWS 실습 환경을 프로비저닝하고 예산 초과 시 자동으로 리소스를 중지합니다.

- 학생별 IAM User 및 태그 강제 정책
- 예산 알림 (SNS) 및 Lambda 킬 스위치
- AWS Budgets 연동
