resource "aws_rds_cluster" "aurora_serverless_cluster" {
  cluster_identifier = "aurora-cluster1"
  engine             = "aurora-postgresql"
  engine_mode        = "provisioned" # Use "provisioned" for Serverless v2
  engine_version     = "15.4"
  database_name      = "main"
  master_username    = var.db_user
  manage_master_user_password = true
  skip_final_snapshot         = true # Enable for production
  db_subnet_group_name        = aws_db_subnet_group.aurora_subnet_group.name
  serverlessv2_scaling_configuration {
    min_capacity = 0.5 # Minimum ACU. The smallest increment is 0.5 ACU for Serverless v2.
    max_capacity = 2   # Maximum ACU. Adjust based on expected peak load in dev environment.
  }
  vpc_security_group_ids = [aws_security_group.rds_cluster_sg.id]
}

resource "aws_rds_cluster_instance" "aurora_instance" {
  engine             = "aurora-postgresql"
  cluster_identifier = aws_rds_cluster.aurora_serverless_cluster.cluster_identifier
  instance_class     = "db.serverless"
}

resource "aws_db_subnet_group" "aurora_subnet_group" {
  name       = "aurora-subnet-group"
  subnet_ids = [var.private_subnet_id_az1, var.private_subnet_id_az2]

  tags = {
    Name = "Aurora Subnet Group"
  }
}

resource "aws_db_proxy" "db_proxy" {
  name           = "db-proxy"
  engine_family  = "POSTGRESQL"
  role_arn       = aws_iam_role.db_proxy_role.arn
  vpc_subnet_ids = [var.private_subnet_id_az1, var.private_subnet_id_az2]
  require_tls    = true # Set to true if you want to enforce TLS

  auth {
    auth_scheme = "SECRETS"
    description = "Authentication used for the DB proxy"
    iam_auth    = "REQUIRED"
    secret_arn  = aws_rds_cluster.aurora_serverless_cluster.master_user_secret[0].secret_arn
  }

  idle_client_timeout    = 1800  # Adjust based on your needs
  debug_logging          = false # Set to true if you need detailed logs for troubleshooting
  vpc_security_group_ids = [aws_security_group.rds_proxy_sg.id]

  tags = {
    Name = "db-proxy"
  }
}

resource "aws_iam_role" "db_proxy_role" {
  name = "db-proxy-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "rds.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_policy" "db_proxy_policy" {
  name        = "db-proxy-policy"
  description = "A policy for the DB proxy to access secrets"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = [
        "secretsmanager:GetSecretValue",
        "secretsmanager:DescribeSecret"
      ]
      Effect   = "Allow"
      Resource = aws_rds_cluster.aurora_serverless_cluster.master_user_secret[0].secret_arn
    }]
  })
}

resource "aws_iam_role_policy_attachment" "db_proxy_policy_attachment" {
  role       = aws_iam_role.db_proxy_role.name
  policy_arn = aws_iam_policy.db_proxy_policy.arn
}

resource "aws_db_proxy_default_target_group" "main" {
  db_proxy_name = aws_db_proxy.db_proxy.name

  connection_pool_config {
    max_connections_percent      = 100
    max_idle_connections_percent = 50
    connection_borrow_timeout    = 120
    session_pinning_filters      = ["EXCLUDE_VARIABLE_SETS"]
  }
}

resource "aws_db_proxy_target" "main" {
  db_proxy_name         = aws_db_proxy.db_proxy.name
  target_group_name     = "default"
  db_cluster_identifier = aws_rds_cluster.aurora_serverless_cluster.id # For an Aurora cluster
}

resource "aws_security_group" "rds_cluster_sg" {
  name        = "rds-cluster-sg"
  description = "Security group for RDS cluster that only allows traffic from the RDS Proxy"
  vpc_id      = var.vpc_id

  # Allow inbound traffic from RDS Proxy's security group
  ingress {
    description     = "Allow inbound traffic from RDS Proxy"
    from_port       = 5432 # the database port
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.rds_proxy_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "RDSClusterSG"
  }
}

resource "aws_security_group" "rds_proxy_sg" {
  name        = "rds-proxy-sg"
  description = "Security group for RDS Proxy"
  vpc_id      = var.vpc_id

  # Allow inbound traffic on the database port from a specific source, such as
  # another security group (e.g., your application servers or Lambda functions)
  ingress {
    description = "Allow inbound traffic to RDS Proxy from App Servers"
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    # For simplicity, this example allows traffic from any source in the VPC.
    # Replace "0.0.0.0/0" with specific CIDR blocks or reference another security
    # group if you want to restrict access further.
    #    cidr_blocks = ["0.0.0.0/0"]
    security_groups = [var.app_lambda_security_group]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "RDSProxySG"
  }
}