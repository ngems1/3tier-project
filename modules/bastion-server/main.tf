data "aws_iam_policy_document" "bastion_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    effect  = "Allow"

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "bastion" {
  name               = "bastion_role_${terraform.workspace}"
  assume_role_policy = data.aws_iam_policy_document.bastion_assume_role.json
}

resource "aws_iam_role_policy_attachment" "bastion_ssm_core" {
  role       = aws_iam_role.bastion.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "bastion" {
  name = "bastion_profile_${terraform.workspace}"
  role = aws_iam_role.bastion.name
}

resource "aws_instance" "bastion" {
  ami                    = var.image_id
  instance_type          = var.instance_type
  iam_instance_profile   = aws_iam_instance_profile.bastion.name
  subnet_id              = var.subnet_id
  vpc_security_group_ids = var.security_groups
  tags                   = var.tags
  key_name               = var.key_name
}
