 variable "region" {
   default     = "ap-southeast-1"
   description = "AWS region"
 }
variable "database_password" {}
variable "env" {}
  
 variable "database_user" {}
 
 variable "project" {}

data "archive_file" "lambda" {
  type        = "zip"
  source_dir  = "${path.module}/source-code"
  output_path = "lambda.zip"
}