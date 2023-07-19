provider "aws" {
 # region = var.region
  profile = "default"
}

data "aws_availability_zones" "available_zones" {}

resource "aws_default_vpc" "default_vpc" {

  tags = {
    Name = "default vpc"
  }
}

resource "aws_default_subnet" "subnet_az1" {
  availability_zone = data.aws_availability_zones.available_zones.names[0]
}
resource "aws_default_subnet" "subnet_az2" {
  availability_zone = data.aws_availability_zones.available_zones.names[1]
}

resource "aws_db_subnet_group" "postgredb" {
  name       = "postgredb"
  subnet_ids = [aws_default_subnet.subnet_az1.id, aws_default_subnet.subnet_az2.id]

  tags = {
    Name = "postgredb"
  }
}

resource "aws_security_group" "rds" {
  name   = "postgredb_rds"
  vpc_id = aws_default_vpc.default_vpc.id

  ingress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "postgredb_rds"
  }
}

resource "aws_db_parameter_group" "postgredb" {
  name   = "postgredb"
  family = "postgres15"

  parameter {
    name  = "log_connections"
    value = "1"
  }
}

resource "aws_db_instance" "postgredb" {
  identifier             = "postgredb"
  instance_class         = "db.t3.micro"
  allocated_storage      = 20
  engine                 = "postgres"
  engine_version         = "15.2"
  db_name                = "${var.project}${var.env}"
  username               = "root"
  password               = "password"
  db_subnet_group_name   = aws_db_subnet_group.postgredb.name
  vpc_security_group_ids = [aws_security_group.rds.id]
  parameter_group_name   = aws_db_parameter_group.postgredb.name
  publicly_accessible    = true
  skip_final_snapshot    = true
}

resource "aws_iam_role" "iam_role" {
  name = "lambda-vpc-execution-role"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "",
      "Effect": "Allow",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "test-attach" {
    role       = aws_iam_role.iam_role.name
    policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

resource "aws_lambda_function" "lambda_init_db" {
  code_signing_config_arn = ""
  description             = ""
  filename                = data.archive_file.lambda.output_path
  function_name           = "${var.project}-lambda-function"
  role                    = aws_iam_role.iam_role.arn
  handler                 = "initdb.lambda_handler"
  runtime                 = "python3.8"
  source_code_hash        = filebase64sha256(data.archive_file.lambda.output_path)


environment {
  variables = {
    APP_DB_USER = "${var.database_user}"
    APP_DB_PASS = "${var.database_password}"
    APP_DB_NAME = "postgredb"
    DB_HOST = aws_db_instance.postgredb.address
    DB_NAME = aws_db_instance.postgredb.db_name
    ENV = "${var.env}"
    PROJECT = "${var.project}"
    }
  }
}

data "aws_lambda_invocation" "init_db" {
  function_name = aws_lambda_function.lambda_init_db.function_name 


  input = <<JSON
{
  "key": "dummy"
}
JSON
}
