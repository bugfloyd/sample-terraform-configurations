# To allow a lambda function to use this DB:
# Add vpc_config the to aws_lambda_function to us ethe below SG

resource "aws_security_group" "lambda_sg" {
  name        = "lambda-sg"
  description = "Security group for Lambda function"
  vpc_id      = var.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "LambdaSG"
  }
}

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

resource "aws_iam_role_policy_attachment" "lambda_vpc_access" {
  role       = var.app_lambda_execution_role_name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

resource "aws_iam_role_policy_attachment" "lambda_db_proxy_attach" {
  role       = var.app_lambda_execution_role_name
  policy_arn = aws_iam_policy.lambda_db_proxy_policy.arn
}

resource "aws_iam_policy" "lambda_db_proxy_policy" {
  name        = "LambdaDBProxyPolicy"
  description = "Allow Lambda functions to access RDS Proxy"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "rds-db:connect"
        ],
        Resource = [
          "arn:aws:rds-db:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:dbuser:${aws_db_proxy.db_proxy.id}/${var.db_user}"
        ]
      }
    ]
  })
}

#resource "aws_iam_policy" "lambda_rds_policy" {
#  name        = "RDSLambdaPolicy"
#  description = "Policy to allow Lambda function to manage RDS DB"
#
#  policy = jsonencode({
#    Version = "2012-10-17",
#    Statement = [
#      {
#        Action = [
#          "rds-data:*"
#        ],
#        Effect   = "Allow",
#        Resource = aws_rds_cluster.aurora_serverless_cluster.arn
#      }
#    ]
#  })
#}
#
#resource "aws_iam_role_policy_attachment" "rest_backend_lambda_rds_policy_attachment" {
#  role       = var.app_lambda_execution_role_name
#  policy_arn = aws_iam_policy.lambda_rds_policy.arn
#}