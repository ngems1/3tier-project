resource "aws_secretsmanager_secret" "db_secret" {
  #checkov:skip=CKV2_AWS_57:Database credential rotation is coordinated with the application deployment and RDS credential change, so automatic single-secret rotation is not enabled in this stack.
  name = var.secret_name
}

resource "aws_secretsmanager_secret_version" "db_secret_version" {
  secret_id = aws_secretsmanager_secret.db_secret.id
  secret_string = jsonencode({
    username = var.db_username
    password = var.db_password
    endpoint = var.db_endpoint
    db_name  = var.db_name
  })
}
