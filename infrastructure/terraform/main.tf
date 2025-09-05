# SlightBuild Infrastructure - AWS Amplify Deployment
# This Terraform configuration sets up the complete infrastructure for SlightBuild website

terraform {
  required_version = ">= 1.0"
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.1"
    }
  }
  
  # Uncomment and configure for production use
  # backend "s3" {
  #   bucket         = "slightbuild-terraform-state"
  #   key            = "infrastructure/terraform.tfstate"
  #   region         = "us-east-1"
  #   encrypt        = true
  #   dynamodb_table = "terraform-state-lock"
  # }
}

# Configure the AWS Provider
provider "aws" {
  region = var.aws_region
  
  default_tags {
    tags = {
      Project     = "SlightBuild"
      Environment = var.environment
      ManagedBy   = "Terraform"
      Owner       = "SlightBuild"
      CostCenter  = "Website"
    }
  }
}

# Data sources for existing resources
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# Random ID for unique resource naming
resource "random_id" "unique_id" {
  byte_length = 4
}

# Amplify App
resource "aws_amplify_app" "slightbuild" {
  name         = var.app_name
  description  = "SlightBuild - Modern Web & Mobile Development Portfolio"
  repository   = var.github_repository
  access_token = var.github_token
  
  # Build settings
  build_spec = file("${path.module}/../../amplify.yml")
  
  # Environment variables
  environment_variables = {
    ENV                = var.environment
    NODE_ENV          = var.environment == "production" ? "production" : "development"
    AWS_REGION        = var.aws_region
    AMPLIFY_MONOREPO_APP_ROOT = "."
  }
  
  # Custom rules for SPA routing
  custom_rule {
    source = "/<*>"
    status = "404"
    target = "/index.html"
  }
  
  # Redirect www to non-www
  custom_rule {
    source = "https://www.${var.domain_name}"
    status = "301"
    target = "https://${var.domain_name}"
  }
  
  # Force HTTPS
  custom_rule {
    source = "http://${var.domain_name}/<*>"
    status = "301"  
    target = "https://${var.domain_name}/<*>"
  }
  
  # Enable auto branch creation and deletion
  enable_auto_branch_creation = false
  enable_branch_auto_deletion = true
  
  # IAM service role for Amplify
  iam_service_role_arn = aws_iam_role.amplify_service_role.arn
  
  tags = {
    Name = "${var.app_name}-amplify-app"
  }
}

# Main branch configuration
resource "aws_amplify_branch" "main" {
  app_id            = aws_amplify_app.slightbuild.id
  branch_name       = "main"
  display_name      = "Production"
  description       = "Production branch for SlightBuild website"
  
  # Environment variables specific to production
  environment_variables = {
    ENV           = "production"
    NODE_ENV      = "production"
    ENVIRONMENT   = "production"
    BRANCH        = "main"
  }
  
  # Enable auto build
  enable_auto_build = true
  
  # Performance mode
  enable_performance_mode = true
  
  # Pull request preview
  enable_pull_request_preview = true
  pull_request_environment_name = "pr-preview"
  
  tags = {
    Name        = "${var.app_name}-main-branch"
    Environment = "production"
  }
}

# Staging branch (optional)
resource "aws_amplify_branch" "staging" {
  count = var.enable_staging_branch ? 1 : 0
  
  app_id      = aws_amplify_app.slightbuild.id
  branch_name = "staging"
  display_name = "Staging"
  description = "Staging branch for testing"
  
  environment_variables = {
    ENV           = "staging"
    NODE_ENV      = "development"
    ENVIRONMENT   = "staging"
    BRANCH        = "staging"
  }
  
  enable_auto_build = true
  
  tags = {
    Name        = "${var.app_name}-staging-branch"
    Environment = "staging"
  }
}

# Custom domain configuration
resource "aws_amplify_domain_association" "slightbuild_domain" {
  count = var.domain_name != "" ? 1 : 0
  
  app_id      = aws_amplify_app.slightbuild.id
  domain_name = var.domain_name
  
  # Wait for certificate validation
  wait_for_verification = true
  
  # Main domain
  sub_domain {
    branch_name = aws_amplify_branch.main.branch_name
    prefix      = ""
  }
  
  # WWW subdomain redirect
  sub_domain {
    branch_name = aws_amplify_branch.main.branch_name
    prefix      = "www"
  }
  
  # Staging subdomain (if enabled)
  dynamic "sub_domain" {
    for_each = var.enable_staging_branch ? [1] : []
    content {
      branch_name = aws_amplify_branch.staging[0].branch_name
      prefix      = "staging"
    }
  }
}

# IAM Role for Amplify Service
resource "aws_iam_role" "amplify_service_role" {
  name = "${var.app_name}-amplify-service-role"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "amplify.amazonaws.com"
        }
      }
    ]
  })
  
  tags = {
    Name = "${var.app_name}-amplify-service-role"
  }
}

# IAM Policy for Amplify Service Role
resource "aws_iam_role_policy" "amplify_service_policy" {
  name = "${var.app_name}-amplify-service-policy"
  role = aws_iam_role.amplify_service_role.id
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      }
    ]
  })
}

# S3 Bucket for Terraform State (optional, for production)
resource "aws_s3_bucket" "terraform_state" {
  count = var.create_state_bucket ? 1 : 0
  
  bucket = "${var.app_name}-terraform-state-${random_id.unique_id.hex}"
  
  tags = {
    Name        = "${var.app_name}-terraform-state"
    Purpose     = "TerraformState"
    Environment = var.environment
  }
}

resource "aws_s3_bucket_versioning" "terraform_state_versioning" {
  count  = var.create_state_bucket ? 1 : 0
  bucket = aws_s3_bucket.terraform_state[0].id
  
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_encryption" "terraform_state_encryption" {
  count  = var.create_state_bucket ? 1 : 0
  bucket = aws_s3_bucket.terraform_state[0].id
  
  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        sse_algorithm = "AES256"
      }
    }
  }
}

resource "aws_s3_bucket_public_access_block" "terraform_state_pab" {
  count  = var.create_state_bucket ? 1 : 0
  bucket = aws_s3_bucket.terraform_state[0].id
  
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# DynamoDB table for Terraform state locking
resource "aws_dynamodb_table" "terraform_state_lock" {
  count = var.create_state_bucket ? 1 : 0
  
  name           = "${var.app_name}-terraform-state-lock"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "LockID"
  
  attribute {
    name = "LockID"
    type = "S"
  }
  
  tags = {
    Name        = "${var.app_name}-terraform-state-lock"
    Purpose     = "TerraformStateLock"
    Environment = var.environment
  }
}