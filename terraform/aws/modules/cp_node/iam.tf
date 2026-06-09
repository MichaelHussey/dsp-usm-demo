resource "aws_iam_role" "cp_node" {
  name = "${var.prefix}-cp-node-${var.instance_index}-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy" "cp_node" {
  name = "${var.prefix}-cp-node-${var.instance_index}"
  role = aws_iam_role.cp_node.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ssm:PutParameter"
        ]
        Resource = "arn:aws:ssm:${var.aws_region}:*:parameter/${var.prefix}/cp-node/*"
      },
      {
        Effect = "Allow"
        Action = [
          "ecr:GetAuthorizationToken"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage"
        ]
        Resource = "arn:aws:ecr:${var.aws_region}:*:repository/${var.prefix}/*"
      }
    ]
  })
}

resource "aws_iam_instance_profile" "cp_node" {
  name = "${var.prefix}-cp-node-${var.instance_index}-profile"
  role = aws_iam_role.cp_node.name
}
