"""
AWS Student Lab — Nightly Shutdown
Lambda 함수: 매일 지정된 시각에 모든 리전의 실행 중인 EC2/RDS를 자동 중지
(Environment=production 또는 prod 태그가 붙은 리소스는 예외)

트리거: EventBridge Scheduler (cron)
런타임: Python 3.12
"""
from __future__ import annotations

import logging

import boto3
from botocore.exceptions import ClientError

logger = logging.getLogger()
logger.setLevel(logging.INFO)

PRODUCTION_TAG_KEY = "Environment"
PRODUCTION_TAG_VALUES = {"production", "prod"}


def list_all_regions() -> list[str]:
    """계정에서 활성화된 모든 리전 목록 조회."""
    ec2 = boto3.client("ec2")
    response = ec2.describe_regions(AllRegions=False)
    return [r["RegionName"] for r in response["Regions"]]


# ─── EC2 ───────────────────────────────────────────────────────────────────

def stop_non_production_ec2_instances(region: str) -> list[str]:
    """
    Environment=production/prod 태그가 없는 실행 중인 EC2 인스턴스를 모두 중지.
    학생이 만든 인스턴스뿐 아니라 Owner 태그가 없는 인스턴스도 대상.
    """
    ec2 = boto3.client("ec2", region_name=region)
    response = ec2.describe_instances(
        Filters=[{"Name": "instance-state-name", "Values": ["running"]}]
    )

    target_ids = []
    for reservation in response["Reservations"]:
        for instance in reservation["Instances"]:
            tags = {t["Key"]: t["Value"] for t in instance.get("Tags", [])}
            if tags.get(PRODUCTION_TAG_KEY) in PRODUCTION_TAG_VALUES:
                continue
            target_ids.append(instance["InstanceId"])

    if not target_ids:
        return []

    stopped = []
    for iid in target_ids:
        try:
            ec2.stop_instances(InstanceIds=[iid])
            stopped.append(iid)
            logger.info(f"[{region}] EC2 중지: {iid}")
        except ClientError as e:
            logger.warning(f"[{region}] EC2 {iid} 중지 실패 (무시): {e}")

    return stopped


# ─── RDS ───────────────────────────────────────────────────────────────────

def stop_non_production_rds_instances(region: str) -> list[str]:
    """
    Environment=production/prod 태그가 없는 사용 가능한 RDS 인스턴스를 모두 중지.
    """
    rds = boto3.client("rds", region_name=region)
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
            logger.warning(f"[{region}] RDS 태그 조회 실패 ({db_id}): {e}")
            continue

        if tags.get(PRODUCTION_TAG_KEY) in PRODUCTION_TAG_VALUES:
            continue

        try:
            rds.stop_db_instance(DBInstanceIdentifier=db_id)
            stopped.append(db_id)
            logger.info(f"[{region}] RDS 중지: {db_id}")
        except ClientError as e:
            logger.warning(f"[{region}] RDS {db_id} 중지 실패 (무시): {e}")

    return stopped


# ─── Lambda 핸들러 ─────────────────────────────────────────────────────────────

def lambda_handler(event: dict, context) -> dict:
    try:
        regions = list_all_regions()
    except ClientError as e:
        logger.error(f"리전 목록 조회 실패: {e}")
        return {"statusCode": 500, "body": "Failed to list regions"}

    ec2_stopped: dict[str, list[str]] = {}
    rds_stopped: dict[str, list[str]] = {}

    for region in regions:
        try:
            stopped = stop_non_production_ec2_instances(region)
            if stopped:
                ec2_stopped[region] = stopped
        except ClientError as e:
            logger.warning(f"[{region}] EC2 조회 실패 (무시): {e}")

        try:
            stopped = stop_non_production_rds_instances(region)
            if stopped:
                rds_stopped[region] = stopped
        except ClientError as e:
            logger.warning(f"[{region}] RDS 조회 실패 (무시): {e}")

    logger.info(f"야간 자동 중지 완료 — EC2: {ec2_stopped}, RDS: {rds_stopped}")

    return {
        "statusCode": 200,
        "body": {"ec2_stopped": ec2_stopped, "rds_stopped": rds_stopped},
    }
