terraform {
  required_version = "~> 1.7"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "local" {
    path = "./terraform.tfstate"
  }
}

resource "aws_dynamodb_table" "gang_of_straw" {
  name           = "gang"
  billing_mode   = "PROVISIONED"
  read_capacity  = 20
  write_capacity = 20
  hash_key       = "name"
  range_key      = "bounty"
  attribute {
    name = "name"
    type = "S"
  }
  attribute {
    name = "bounty"
    type = "N"
  }
}