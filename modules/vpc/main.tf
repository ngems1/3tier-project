resource "aws_vpc" "main" {
  cidr_block           = var.cidr_block
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name        = "vpc-alb-${terraform.workspace}"
    environment = "${terraform.workspace}"
  }
}

resource "aws_default_security_group" "default" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "default_sg_${terraform.workspace}"
  }
}

resource "aws_cloudwatch_log_group" "vpc_flow_logs" {
  name              = "/aws/vpc/flow-logs/${terraform.workspace}"
  retention_in_days = 30

  tags = {
    Name = "vpc_flow_logs_${terraform.workspace}"
  }
}

data "aws_iam_policy_document" "flow_logs_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    effect  = "Allow"

    principals {
      type        = "Service"
      identifiers = ["vpc-flow-logs.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "flow_logs" {
  name               = "vpc_flow_logs_${terraform.workspace}"
  assume_role_policy = data.aws_iam_policy_document.flow_logs_assume_role.json
}

data "aws_iam_policy_document" "flow_logs" {
  statement {
    effect = "Allow"
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:DescribeLogGroups",
      "logs:DescribeLogStreams",
      "logs:PutLogEvents",
    ]
    resources = [
      aws_cloudwatch_log_group.vpc_flow_logs.arn,
      "${aws_cloudwatch_log_group.vpc_flow_logs.arn}:*",
    ]
  }
}

resource "aws_iam_role_policy" "flow_logs" {
  name   = "vpc_flow_logs_${terraform.workspace}"
  role   = aws_iam_role.flow_logs.id
  policy = data.aws_iam_policy_document.flow_logs.json
}

resource "aws_flow_log" "vpc" {
  iam_role_arn         = aws_iam_role.flow_logs.arn
  log_destination      = aws_cloudwatch_log_group.vpc_flow_logs.arn
  traffic_type         = "ALL"
  vpc_id               = aws_vpc.main.id
  log_destination_type = "cloud-watch-logs"
}

data "aws_availability_zones" "available" {
  state = "available"
}

resource "aws_subnet" "alb_subnet_public" {
  count                   = length(var.alb_subnet_public)
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.alb_subnet_public[count.index]
  map_public_ip_on_launch = true
  availability_zone       = data.aws_availability_zones.available.names[count.index]

  tags = {
    Name = "alb_subnet_public-${terraform.workspace}"
  }
}

resource "aws_subnet" "web_subnet_private" {
  count             = length(var.web_subnet_private)
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.web_subnet_private[count.index]
  availability_zone = data.aws_availability_zones.available.names[count.index]

  tags = {
    Name = "web_subnet_private-${terraform.workspace}"
  }
}

resource "aws_subnet" "app_subnet_private" {
  count             = length(var.app_subnet_private)
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.app_subnet_private[count.index]
  availability_zone = data.aws_availability_zones.available.names[count.index]

  tags = {
    Name = "app_subnet_private-${terraform.workspace}"
  }
}

resource "aws_subnet" "db_subnet_private" {
  count             = length(var.db_subnet_private)
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.db_subnet_private[count.index]
  availability_zone = data.aws_availability_zones.available.names[count.index]

  tags = {
    Name = "db_subnet_private-${terraform.workspace}"
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "igw-${terraform.workspace}"
  }
}

resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.alb_subnet_public[0].id

  tags = {
    Name = "nat-${terraform.workspace}"
  }
}

resource "aws_eip" "nat" {
  domain = "vpc"

  tags = {
    Name = "nat-${terraform.workspace}"
  }
}

resource "aws_route_table" "alb_rt_public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "alb_rt_public-${terraform.workspace}"
  }
}

resource "aws_route_table" "web_rt_private" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "web_rt_private-${terraform.workspace}"
  }
}

resource "aws_route_table" "app_rt_private" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "app_rt_private-${terraform.workspace}"
  }
}

resource "aws_route_table" "db_rt_private" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "db_rt_private-${terraform.workspace}"
  }
}

resource "aws_route_table_association" "alb_rt_ass_public" {
  count          = length(var.alb_subnet_public)
  subnet_id      = aws_subnet.alb_subnet_public[count.index].id
  route_table_id = aws_route_table.alb_rt_public.id
}

resource "aws_route_table_association" "web_rt_ass_private" {
  count          = length(var.web_subnet_private)
  subnet_id      = aws_subnet.web_subnet_private[count.index].id
  route_table_id = aws_route_table.web_rt_private.id

}

resource "aws_route_table_association" "app_rt_ass_private" {
  count          = length(var.app_subnet_private)
  subnet_id      = aws_subnet.app_subnet_private[count.index].id
  route_table_id = aws_route_table.app_rt_private.id
}

resource "aws_route_table_association" "db_rt_ass_private" {
  count          = length(var.db_subnet_private)
  subnet_id      = aws_subnet.db_subnet_private[count.index].id
  route_table_id = aws_route_table.db_rt_private.id
}

resource "aws_route" "web_rt_ass_private" {
  route_table_id         = aws_route_table.web_rt_private.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.nat.id

  depends_on = [aws_eip.nat]
}

resource "aws_route" "app_rt_ass_private" {
  route_table_id         = aws_route_table.app_rt_private.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.nat.id

  depends_on = [aws_eip.nat]
}

resource "aws_route" "db_rt_ass_private" {
  route_table_id         = aws_route_table.db_rt_private.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.nat.id

  depends_on = [aws_eip.nat]
}

