# TODOS

## TODO 1: 고비용 리소스 IAM Deny 확장

**현재 상태**: NAT Gateway 생성만 차단 (`ec2:CreateNatGateway` Deny)

**문제**: GPU 인스턴스, 스팟 인스턴스, ElastiCache, Redshift 등 $40 예산을 순식간에 소진할 수 있는 리소스가 차단되지 않음

**추가 차단 대상**:

- GPU/고성능 인스턴스 타입: `p2.*`, `p3.*`, `p4d.*`, `g3.*`, `g4dn.*`, `g5.*` (시간당 $1~$30+)
- 스팟 인스턴스 요청: `ec2:RequestSpotInstances` (실습 의도와 무관)
- ElastiCache 클러스터: `elasticache:CreateCacheCluster` (시간당 $0.02~$0.2+)
- Redshift 클러스터: `redshift:CreateCluster` (시간당 $0.25+)
- EKS 클러스터: `eks:CreateCluster` (시간당 $0.10 + 노드 비용)
- NAT Gateway (이미 차단됨)

**구현 방법**: `student_tag_enforce.json` IAM 정책에 `DenyExpensiveResources` Statement 추가

```json
{
  "Sid": "DenyExpensiveResources",
  "Effect": "Deny",
  "Action": [
    "ec2:RequestSpotInstances",
    "ec2:RequestSpotFleet",
    "elasticache:CreateCacheCluster",
    "elasticache:CreateReplicationGroup",
    "redshift:CreateCluster",
    "eks:CreateCluster"
  ],
  "Resource": "*"
},
{
  "Sid": "DenyExpensiveInstanceTypes",
  "Effect": "Deny",
  "Action": "ec2:RunInstances",
  "Resource": "arn:aws:ec2:*:*:instance/*",
  "Condition": {
    "StringLike": {
      "ec2:InstanceType": [
        "p2.*", "p3.*", "p4d.*",
        "g3.*", "g4dn.*", "g5.*",
        "x1.*", "x2.*",
        "u-*"
      ]
    }
  }
}
```

**우선순위**: Medium (예산 초과 위험이 있지만 현재 실습 과제 범위 외)

---

## TODO 2: 킬 스위치 발동 시 학생 이메일 알림

**현재 상태**: Lambda가 EC2/S3를 처리하지만 학생에게 아무 알림도 전송하지 않음

**문제**: 리소스가 갑자기 중지되어도 학생은 원인을 모름. 강사 개입 없이는 복구 경로도 불명확.

**구현 방법**:

1. `variables.tf`에 학생별 이메일 맵 추가:

```hcl
variable "student_emails" {
  type = map(string)
  default = {
    "alice" = "alice@example.com"
    "bob"   = "bob@example.com"
    # ...
  }
}
```

2. Lambda 환경변수로 JSON 직렬화하여 전달

3. Lambda에서 SES 또는 SNS로 알림 전송:

```python
def notify_student(student_name: str, stopped_instances: list, blocked_buckets: list):
    email = STUDENT_EMAILS.get(student_name)
    if not email:
        return
    ses.send_email(
        Source="lab-admin@example.com",
        Destination={"ToAddresses": [email]},
        Message={
            "Subject": {"Data": f"[AWS Lab] 예산 초과 — 리소스 중지됨"},
            "Body": {"Text": {"Data": (
                f"{student_name}님, $40 월 예산이 초과되어 리소스가 중지되었습니다.\n"
                f"중지된 EC2: {stopped_instances}\n"
                f"차단된 S3: {blocked_buckets}\n"
                f"복구는 강사에게 문의하세요."
            )}}
        }
    )
```

4. Lambda IAM 역할에 `ses:SendEmail` 권한 추가
5. SES에서 발신 이메일 주소 도메인 인증 필요 (SES sandbox → production 승인)

**우선순위**: Medium (학생 경험 개선, 구현 비용 낮음)
