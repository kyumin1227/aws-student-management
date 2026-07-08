"""
AWS Student Lab — Nightly Shutdown
Lambda 함수: 매일 지정된 시각에 실행 중인 EC2/RDS를 자동 중지
(Environment=production 태그가 붙은 리소스는 예외)

트리거: EventBridge Scheduler (cron)
런타임: Python 3.12
"""
from __future__ import annotations

import logging

import boto3
from botocore.exceptions import ClientError

logger = logging.getLogger()
logger.setLevel(logging.INFO)

ec2 = boto3.client("ec2")
rds = boto3.client("rds")

PRODUCTION_TAG_KEY = "Environment"
PRODUCTION_TAG_VALUE = "production"


# ─── EC2 ───────────────────────────────────────────────────────────────────

def stop_non_production_ec2_instances() -> list[str]:
    """
    Environment=production 태그가 없는 실행 중인 EC2 인스턴스를 모두 중지.
    학생이 만든 인스턴스뿐 아니라 Owner 태그가 없는 인스턴스도 대상.
    """
    response = ec2.describe_instances(
        Filters=[{"Name": "instance-state-name", "Values": ["running"]}]
    )

    target_ids = []
    for reservation in response["Reservations"]:
        for instance in reservation["Instances"]:
            tags = {t["Key"]: t["Value"] for t in instance.get("Tags", [])}
            if tags.get(PRODUCTION_TAG_KEY) == PRODUCTION_TAG_VALUE:
                continue
            target_ids.append(instance["InstanceId"])

    if not target_ids:
        logger.info("중지 대상 EC2 없음")
        return []

    stopped = []
    for iid in target_ids:
        try:
            ec2.stop_instances(InstanceIds=[iid])
            stopped.append(iid)
            logger.info(f"EC2 중지: {iid}")
        except ClientError as e:
            logger.warning(f"EC2 {iid} 중지 실패 (무시): {e}")

    return stopped


# ─── RDS ───────────────────────────────────────────────────────────────────

def stop_non_production_rds_instances() -> list[str]:
    """
    Environment=production 태그가 없는 사용 가능한 RDS 인스턴스를 모두 중지.
    """
    response = rds.describe_db_instances()

    stopped = []
    for db in response["DBInstances"]:
        if db["DBInstanceStatus"] != "available":
            continue

        db_id = db["DBInstanceIdentifier"]
        db_arn = db["DBInstanceArn"]

        try:
            tags_response = rds.list_tags_for_resource(ResourceName=db_arn)
            tags = {t["Key"]: t["Value"] for t in tags_response.get("TagList", [])}
        except ClientError as e:
            logger.warning(f"RDS 태그 조회 실패 ({db_id}): {e}")
            continue

        if tags.get(PRODUCTION_TAG_KEY) == PRODUCTION_TAG_VALUE:
            continue

        try:
            rds.stop_db_instance(DBInstanceIdentifier=db_id)
            stopped.append(db_id)
            logger.info(f"RDS 중지: {db_id}")
        except ClientError as e:
            logger.warning(f"RDS {db_id} 중지 실패 (무시): {e}")

    return stopped


# ─── Lambda 핸들러 ─────────────────────────────────────────────────────────────

def lambda_handler(event: dict, context) -> dict:
    ec2_stopped = stop_non_production_ec2_instances()
    rds_stopped = stop_non_production_rds_instances()

    logger.info(f"야간 자동 중지 완료 — EC2: {ec2_stopped}, RDS: {rds_stopped}")

    return {
        "statusCode": 200,
        "body": {"ec2_stopped": ec2_stopped, "rds_stopped": rds_stopped},
    }
