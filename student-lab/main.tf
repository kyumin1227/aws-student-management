data "aws_caller_identity" "current" {}

locals {
  caller_name = element(split("/", data.aws_caller_identity.current.arn), length(split("/", data.aws_caller_identity.current.arn)) - 1)
}
