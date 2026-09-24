# Least-privilege IAM roles, separated per tier so the web (frontend) role
# never has access to database secrets and each role only carries the
# permissions its own tier needs at runtime.

data "aws_iam_policy_document" "ec2_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    effect  = "Allow"

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

# Shared CloudWatch Agent policy: allows shipping metrics/logs from EC2
# instances without granting the broader AWS managed CloudWatchAgentServerPolicy
# (which also includes unrelated SSM permissions).
data "aws_iam_policy_document" "cloudwatch_agent" {
  statement {
    sid    = "CloudWatchMetrics"
    effect = "Allow"
    actions = [
      "cloudwatch:PutMetricData",
    ]
    resources = ["*"]
  }

  statement {
    sid    = "CloudWatchLogs"
    effect = "Allow"
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
      "logs:DescribeLogStreams",
      "logs:DescribeLogGroups",
    ]
    resources = ["arn:aws:logs:*:*:log-group:/three-tier/${terraform.workspace}/*"]
  }
}

resource "aws_iam_policy" "cloudwatch_agent_policy" {
  name        = "cloudwatch_agent_policy_${terraform.workspace}"
  description = "Least-privilege permissions for the CloudWatch Agent (metrics + logs)"
  policy      = data.aws_iam_policy_document.cloudwatch_agent.json
}

# ---------------------------------------------------------------------------
# App (backend) tier role: CloudWatch Agent + read-only access to its own
# database secret only (not "*").
# ---------------------------------------------------------------------------

resource "aws_iam_role" "app_role" {
  name               = "app_role_${terraform.workspace}"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume_role.json
}

data "aws_iam_policy_document" "secrets_policy" {
  statement {
    effect    = "Allow"
    actions   = ["secretsmanager:GetSecretValue"]
    resources = [var.secret_arn]
  }
}

resource "aws_iam_policy" "secrets_policy" {
  name        = "secrets_policy_${terraform.workspace}"
  description = "Allow read access to the backend database secret only"
  policy      = data.aws_iam_policy_document.secrets_policy.json
}

resource "aws_iam_role_policy_attachment" "secrets_attach" {
  role       = aws_iam_role.app_role.name
  policy_arn = aws_iam_policy.secrets_policy.arn
}

resource "aws_iam_role_policy_attachment" "app_cloudwatch_attach" {
  role       = aws_iam_role.app_role.name
  policy_arn = aws_iam_policy.cloudwatch_agent_policy.arn
}

resource "aws_iam_instance_profile" "app_profile" {
  name = "app_profile_${terraform.workspace}"
  role = aws_iam_role.app_role.name
}

# ---------------------------------------------------------------------------
# Web (frontend) tier role: CloudWatch Agent only. No secrets access, keeping
# the runtime role for the internet-facing tier as narrow as possible.
# ---------------------------------------------------------------------------

resource "aws_iam_role" "web_role" {
  name               = "web_role_${terraform.workspace}"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume_role.json
}

resource "aws_iam_role_policy_attachment" "web_cloudwatch_attach" {
  role       = aws_iam_role.web_role.name
  policy_arn = aws_iam_policy.cloudwatch_agent_policy.arn
}

resource "aws_iam_instance_profile" "web_profile" {
  name = "web_profile_${terraform.workspace}"
  role = aws_iam_role.web_role.name
}
