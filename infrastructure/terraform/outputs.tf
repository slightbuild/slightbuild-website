# SlightBuild Infrastructure Outputs
# Output values from the Terraform deployment

output "amplify_app_id" {
  description = "The ID of the Amplify application"
  value       = aws_amplify_app.slightbuild.id
}

output "amplify_app_arn" {
  description = "The ARN of the Amplify application"
  value       = aws_amplify_app.slightbuild.arn
}

output "amplify_app_name" {
  description = "The name of the Amplify application"
  value       = aws_amplify_app.slightbuild.name
}

output "amplify_default_domain" {
  description = "The default domain for the Amplify application"
  value       = aws_amplify_app.slightbuild.default_domain
}

output "production_branch_url" {
  description = "URL of the production branch"
  value       = "https://${aws_amplify_branch.main.branch_name}.${aws_amplify_app.slightbuild.default_domain}"
}

output "staging_branch_url" {
  description = "URL of the staging branch (if enabled)"
  value       = var.enable_staging_branch ? "https://${aws_amplify_branch.staging[0].branch_name}.${aws_amplify_app.slightbuild.default_domain}" : "N/A - Staging branch not enabled"
}

output "custom_domain_url" {
  description = "Custom domain URL (if configured)"
  value       = var.domain_name != "" ? "https://${var.domain_name}" : "N/A - Custom domain not configured"
}

output "domain_verification_record" {
  description = "DNS verification record for custom domain"
  value       = var.domain_name != "" ? aws_amplify_domain_association.slightbuild_domain[0].certificate_verification_dns_record : "N/A"
}

# Amplify Console URLs
output "amplify_console_url" {
  description = "URL to the Amplify Console for this app"
  value       = "https://console.aws.amazon.com/amplify/home?region=${var.aws_region}#/${aws_amplify_app.slightbuild.id}"
}

output "main_branch_console_url" {
  description = "URL to the main branch in Amplify Console"
  value       = "https://console.aws.amazon.com/amplify/home?region=${var.aws_region}#/${aws_amplify_app.slightbuild.id}/${aws_amplify_branch.main.branch_name}"
}

# GitHub Integration
output "github_repository" {
  description = "Connected GitHub repository"
  value       = var.github_repository
}

# IAM Role Information
output "amplify_service_role_arn" {
  description = "ARN of the Amplify service role"
  value       = aws_iam_role.amplify_service_role.arn
}

output "amplify_service_role_name" {
  description = "Name of the Amplify service role"
  value       = aws_iam_role.amplify_service_role.name
}

# Infrastructure State Management (if enabled)
output "terraform_state_bucket" {
  description = "S3 bucket for Terraform state (if created)"
  value       = var.create_state_bucket ? aws_s3_bucket.terraform_state[0].id : "N/A - State bucket not created"
}

output "terraform_state_lock_table" {
  description = "DynamoDB table for Terraform state locking (if created)"
  value       = var.create_state_bucket ? aws_dynamodb_table.terraform_state_lock[0].name : "N/A - Lock table not created"
}

# Deployment Information
output "deployment_info" {
  description = "Comprehensive deployment information"
  value = {
    app_id            = aws_amplify_app.slightbuild.id
    production_url    = "https://${aws_amplify_branch.main.branch_name}.${aws_amplify_app.slightbuild.default_domain}"
    custom_domain     = var.domain_name != "" ? "https://${var.domain_name}" : "Not configured"
    environment       = var.environment
    region           = var.aws_region
    console_url      = "https://console.aws.amazon.com/amplify/home?region=${var.aws_region}#/${aws_amplify_app.slightbuild.id}"
    github_repo      = var.github_repository
  }
}

# Cost Information
output "estimated_monthly_cost" {
  description = "Estimated monthly cost breakdown"
  value = {
    amplify_hosting = "~$1-3 USD (depends on traffic)"
    custom_domain   = var.domain_name != "" ? "~$0.50 USD (Route53 hosted zone)" : "$0 USD"
    ssl_certificate = "$0 USD (AWS Certificate Manager - free)"
    total_estimate  = var.domain_name != "" ? "~$1.50-3.50 USD" : "~$1-3 USD"
  }
}

# Security Information
output "security_features" {
  description = "Enabled security features"
  value = {
    https_enabled     = true
    custom_headers    = "Configured via customHttp.yml"
    iam_role         = aws_iam_role.amplify_service_role.arn
    access_control   = "GitHub token-based access"
  }
}

# Performance Information
output "performance_features" {
  description = "Enabled performance features"
  value = {
    performance_mode    = var.enable_performance_mode
    global_cdn         = true
    auto_minification  = true
    compression        = true
    caching           = "Configured via customHttp.yml"
  }
}

# Next Steps Information
output "next_steps" {
  description = "Next steps after deployment"
  value = {
    "1_verify_deployment" = "Visit ${aws_amplify_branch.main.branch_name}.${aws_amplify_app.slightbuild.default_domain} to verify deployment"
    "2_configure_domain"  = var.domain_name != "" ? "DNS verification may be required for custom domain" : "Configure custom domain in variables if needed"
    "3_github_secrets"    = "Add AMPLIFY_APP_ID (${aws_amplify_app.slightbuild.id}) to GitHub secrets"
    "4_monitoring"        = "Set up monitoring and alerts in CloudWatch"
    "5_backups"          = "Consider setting up automated backups"
  }
}