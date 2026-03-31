"""
AWS Student Lab — Budget Kill Switch
Lambda 함수: 학생 예산 초과 시 EC2 Stop + EIP 해제 + S3 Block + RDS Stop

트리거: SNS (AWS Budgets → SNS → Lambda)
런타임: Python 3.12
"""
from __future__ import annotations

import json
import logging
import os

import boto3
from botocore.exceptions import ClientError

logger = logging.getLogger()
logger.setLevel(logging.INFO)

ec2 = boto3.client("ec2")
s3 = boto3.client("s3")
rds = boto3.client("rds")
ses = boto3.client("ses")

# TODO 2: 학생 이메일 맵 (환경변수에서 로드)
_raw_emails = os.environ.get("STUDENT_EMAILS", "{}")
try:
    STUDENT_EMAILS: dict[str, str] = json.loads(_raw_emails)
except json.JSONDecodeError:
    STUDENT_EMAILS = {}
    logger.warning("STUDENT_EMAILS 파싱 실패 — 이메일 알림 비활성화")

SES_SENDER = os.environ.get("SES_SENDER", "")


# ─── 학생 이름 추출 ────────────────────────────────────────────────────────────

def get_student_name_from_budget_notification(sns_message: dict) -> str | None:
    """
    Budget 이름에서 학생 이름 추출.
    예: "student-alice-monthly-budget" → "alice"
    """
    budget_name = sns_message.get("budgetName", "")
    prefix = "student-"
    suffix = "-monthly-budget"
    if budget_name.startswith(prefix) and budget_name.endswith(suffix):
        return budget_name.removeprefix(prefix).removesuffix(suffix)
    return None


# ─── EC2 Stop + EIP 해제 ───────────────────────────────────────────────────────

def stop_ec2_instances(student_name: str) -> list[str]:
    """
    Owner 태그가 student_name인 실행 중인 EC2 인스턴스를 중지.
    인스턴스별 개별 예외 처리 — 하나 실패해도 나머지 계속 처리.
    """
    response = ec2.describe_instances(
        Filters=[
            {"Name": "tag:Owner", "Values": [student_name]},
            {"Name": "instance-state-name", "Values": ["running", "pending"]},
        ]
    )

    instance_ids = [
        instance["InstanceId"]
        for reservation in response["Reservations"]
        for instance in reservation["Instances"]
    ]

    if not instance_ids:
        logger.info(f"[{student_name}] 실행 중인 EC2 없음")
        return []

    stopped = []
    for iid in instance_ids:
        try:
            ec2.stop_instances(InstanceIds=[iid])
            stopped.append(iid)
            logger.info(f"[{student_name}] EC2 중지: {iid}")
        except ClientError as e:
            # 이미 stopped 상태면 정상 — 그 외 오류는 경고
            if e.response["Error"]["Code"] == "IncorrectInstanceState":
                logger.info(f"[{student_name}] EC2 {iid} 이미 중지 상태 (무시)")
            else:
                logger.warning(f"[{student_name}] EC2 {iid} 중지 실패 (무시): {e}")

    return stopped


def release_eips(student_name: str) -> list[str]:
    """
    Owner 태그가 student_name인 EIP를 disassociate + release.
    EC2 Stop 후 호출하지 않으면 할당된 EIP 비용 계속 발생 ($0.005/hr).
    """
    response = ec2.describe_addresses(
        Filters=[{"Name": "tag:Owner", "Values": [student_name]}]
    )

    released = []
    for addr in response["Addresses"]:
        allocation_id = addr.get("AllocationId")
        association_id = addr.get("AssociationId")

        if not allocation_id:
            continue

        # 먼저 분리
        if association_id:
            try:
                ec2.disassociate_address(AssociationId=association_id)
                logger.info(f"[{student_name}] EIP 분리: {allocation_id}")
            except ClientError as e:
                logger.warning(f"[{student_name}] EIP 분리 실패 ({allocation_id}): {e}")
                continue

        # 이후 해제
        try:
            ec2.release_address(AllocationId=allocation_id)
            released.append(allocation_id)
            logger.info(f"[{student_name}] EIP 해제: {allocation_id}")
        except ClientError as e:
            logger.warning(f"[{student_name}] EIP 해제 실패 ({allocation_id}): {e}")

    return released


# ─── S3 Block ─────────────────────────────────────────────────────────────────

def block_s3_buckets(student_name: str) -> list[str]:
    """
    Owner 태그가 student_name인 S3 버킷에 Deny All 정책 추가 + Public Access Block.
    """
    all_buckets = s3.list_buckets().get("Buckets", [])
    blocked = []

    for bucket in all_buckets:
        bucket_name = bucket["Name"]

        # Owner 태그 확인
        try:
            tags_response = s3.get_bucket_tagging(Bucket=bucket_name)
            tags = {t["Key"]: t["Value"] for t in tags_response.get("TagSet", [])}
        except ClientError as e:
            if e.response["Error"]["Code"] in ("NoSuchTagSet", "NoSuchBucket"):
                continue
            logger.warning(f"[{student_name}] S3 태그 조회 실패 ({bucket_name}): {e}")
            continue

        if tags.get("Owner") != student_name:
            continue

        # Public Access Block 강제 (이미 설정되어 있어도 재확인)
        try:
            s3.put_public_access_block(
                Bucket=bucket_name,
                PublicAccessBlockConfiguration={
                    "BlockPublicAcls": True,
                    "IgnorePublicAcls": True,
                    "BlockPublicPolicy": True,
                    "RestrictPublicBuckets": True,
                },
            )
        except ClientError as e:
            logger.warning(f"[{student_name}] S3 Public Access Block 실패 ({bucket_name}): {e}")

        # Deny All 버킷 정책 추가
        deny_policy = json.dumps({
            "Version": "2012-10-17",
            "Statement": [{
                "Sid": "BudgetKillSwitchDenyAll",
                "Effect": "Deny",
                "Principal": "*",
                "Action": "s3:*",
                "Resource": [
                    f"arn:aws:s3:::{bucket_name}",
                    f"arn:aws:s3:::{bucket_name}/*",
                ],
            }],
        })

        try:
            s3.put_bucket_policy(Bucket=bucket_name, Policy=deny_policy)
            blocked.append(bucket_name)
            logger.info(f"[{student_name}] S3 버킷 차단: {bucket_name}")
        except ClientError as e:
            logger.error(f"[{student_name}] S3 버킷 정책 설정 실패 ({bucket_name}): {e}")

    return blocked


# ─── RDS Stop ─────────────────────────────────────────────────────────────────

def stop_rds_instances(student_name: str) -> list[str]:
    """
    Owner 태그가 student_name인 실행 중인 RDS 인스턴스를 중지.
    (미래 확장성을 위해 유지)
    """
    response = rds.describe_db_instances()
    affected = []

    for db in response["DBInstances"]:
        db_id = db["DBInstanceIdentifier"]
        db_arn = db["DBInstanceArn"]
        db_status = db["DBInstanceStatus"]

        if db_status != "available":
            continue

        # RDS 태그 조회
        try:
            tags_response = rds.list_tags_for_resource(ResourceName=db_arn)
            tags = {t["Key"]: t["Value"] for t in tags_response.get("TagList", [])}
        except ClientError as e:
            logger.warning(f"[{student_name}] RDS 태그 조회 실패 ({db_id}): {e}")
            continue

        if tags.get("Owner") != student_name:
            continue

        try:
            rds.stop_db_instance(DBInstanceIdentifier=db_id)
            affected.append(db_id)
            logger.info(f"[{student_name}] RDS 중지: {db_id}")
        except ClientError as e:
            logger.error(f"[{student_name}] RDS 처리 중 오류 ({db_id}): {e}")

    return affected


# ─── TODO 2: 학생 이메일 알림 ──────────────────────────────────────────────────

def notify_student(
    student_name: str,
    stopped_instances: list[str],
    released_eips: list[str],
    blocked_buckets: list[str],
    stopped_rds: list[str],
) -> None:
    """
    킬 스위치 발동 후 학생에게 SES 이메일 알림 전송.
    STUDENT_EMAILS 환경변수에 이메일이 없으면 무시.
    """
    if not STUDENT_EMAILS or not SES_SENDER:
        return

    email = STUDENT_EMAILS.get(student_name)
    if not email:
        logger.info(f"[{student_name}] 이메일 미설정 — 알림 스킵")
        return

    body_lines = [
        f"{student_name}님,",
        "",
        "AWS 실습 월 예산 ($40)이 초과되어 리소스가 자동으로 중지되었습니다.",
        "",
        "중지된 리소스:",
    ]
    if stopped_instances:
        body_lines.append(f"  - EC2 인스턴스: {', '.join(stopped_instances)}")
    if released_eips:
        body_lines.append(f"  - 해제된 EIP: {', '.join(released_eips)}")
    if blocked_buckets:
        body_lines.append(f"  - S3 버킷 (접근 차단): {', '.join(blocked_buckets)}")
    if stopped_rds:
        body_lines.append(f"  - RDS 인스턴스: {', '.join(stopped_rds)}")

    body_lines += [
        "",
        "복구가 필요하면 강사에게 문의하세요.",
        "실습 데이터는 보존되어 있습니다.",
    ]

    try:
        ses.send_email(
            Source=SES_SENDER,
            Destination={"ToAddresses": [email]},
            Message={
                "Subject": {"Data": "[AWS Lab] 예산 초과 — 리소스가 중지되었습니다"},
                "Body": {"Text": {"Data": "\n".join(body_lines)}},
            },
        )
        logger.info(f"[{student_name}] 이메일 알림 전송: {email}")
    except ClientError as e:
        logger.error(f"[{student_name}] 이메일 전송 실패: {e}")


# ─── Lambda 핸들러 ─────────────────────────────────────────────────────────────

def lambda_handler(event: dict, context) -> dict:
    for record in event.get("Records", []):
        sns_message_raw = record.get("Sns", {}).get("Message", "{}")

        try:
            sns_message = json.loads(sns_message_raw)
        except json.JSONDecodeError:
            logger.error(f"SNS 메시지 파싱 실패: {sns_message_raw}")
            continue

        student_name = get_student_name_from_budget_notification(sns_message)
        if not student_name:
            logger.warning(f"학생 이름 추출 실패: {sns_message}")
            continue

        logger.info(f"킬 스위치 실행 — 학생: {student_name}")

        ec2_stopped  = stop_ec2_instances(student_name)
        eips_released = release_eips(student_name)
        s3_blocked   = block_s3_buckets(student_name)
        rds_stopped  = stop_rds_instances(student_name)

        logger.info(
            f"[{student_name}] 완료 — "
            f"EC2: {ec2_stopped}, EIP: {eips_released}, "
            f"S3: {s3_blocked}, RDS: {rds_stopped}"
        )

        # TODO 2: 학생에게 이메일 알림
        notify_student(student_name, ec2_stopped, eips_released, s3_blocked, rds_stopped)

    return {"statusCode": 200, "body": "Kill switch executed"}
