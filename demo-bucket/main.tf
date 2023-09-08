terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Configure the AWS Provider
provider "aws" {
  region     = "us-east-1"
  access_key = ""
  secret_key = ""
}

resource "aws_s3_bucket" "bucket_utec_demo" {
  bucket = "bucket-utec-demo"
  acl    = "private"
}

resource "aws_s3_bucket_object" "object1" {
  for_each = fileset("uploads/", "*")
  bucket   = aws_s3_bucket.bucket_utec_demo.id
  key      = each.value
  source   = "uploads/${each.value}"
  etag     = filemd5("uploads/${each.value}")
}
