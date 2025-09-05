# SlightBuild Infrastructure Variables
# Define all input variables for the Terraform configuration

variable "app_name" {
  description = "Name of the Amplify application"
  type        = string
  default     = "slightbuild"
  
  validation {
    condition     = can(regex("^[a-z][a-z0-9-]*[a-z0-9]$", var.app_name))
    error_message = "App name must start with a letter, contain only lowercase letters, numbers, and hyphens, and end with a letter or number."
  }
}

variable "environment" {
  description = "Environment name (e.g., production, staging, development)"
  type        = string
  default     = "production"
  
  validation {
    condition     = contains(["production", "staging", "development"], var.environment)
    error_message = "Environment must be one of: production, staging, development."
  }
}

variable "aws_region" {
  description = "AWS region for resources"
  type        = string
  default     = "us-east-1"
}

variable "domain_name" {
  description = "Custom domain name for the website (leave empty to skip domain setup)"
  type        = string
  default     = ""
  
  validation {
    condition = var.domain_name == "" || can(regex("^([a-z0-9-]+\\.)*[a-z0-9-]+\\.[a-z]{2,}$", var.domain_name))
    error_message = "Domain name must be a valid domain (e.g., example.com)."
  }
}

variable "github_repository" {
  description = "GitHub repository URL (e.g., https://github.com/username/repo)"
  type        = string
  
  validation {
    condition     = can(regex("^https://github\\.com/.+/.+$", var.github_repository))
    error_message = "GitHub repository must be a valid GitHub URL (https://github.com/username/repo)."
  }
}

variable "github_token" {
  description = "GitHub personal access token for Amplify to access the repository"
  type        = string
  sensitive   = true
  
  validation {
    condition     = length(var.github_token) >= 20
    error_message = "GitHub token must be at least 20 characters long."
  }
}

variable "enable_staging_branch" {
  description = "Whether to create a staging branch"
  type        = bool
  default     = false
}

variable "create_state_bucket" {
  description = "Whether to create S3 bucket for Terraform state storage"
  type        = bool
  default     = false
}

# Monitoring and Alerting Variables
variable "enable_monitoring" {
  description = "Enable CloudWatch monitoring and alerts"
  type        = bool
  default     = true
}

variable "cost_budget_limit" {
  description = "Monthly cost budget limit in USD"
  type        = number
  default     = 10.0
  
  validation {
    condition     = var.cost_budget_limit > 0 && var.cost_budget_limit <= 1000
    error_message = "Cost budget limit must be between 0 and 1000 USD."
  }
}

variable "notification_email" {
  description = "Email address for cost and monitoring alerts"
  type        = string
  default     = ""
  
  validation {
    condition = var.notification_email == "" || can(regex("^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$", var.notification_email))
    error_message = "Notification email must be a valid email address."
  }
}

# Performance and Optimization Variables
variable "enable_performance_mode" {
  description = "Enable Amplify performance mode for faster builds"
  type        = bool
  default     = true
}

variable "enable_pull_request_previews" {
  description = "Enable automatic previews for pull requests"
  type        = bool
  default     = true
}

# Security Variables
variable "allowed_origins" {
  description = "List of allowed origins for CORS"
  type        = list(string)
  default     = ["https://slightbuild.com", "https://www.slightbuild.com"]
}

variable "content_security_policy" {
  description = "Content Security Policy directives"
  type        = map(list(string))
  default = {
    default-src = ["'self'"]
    script-src  = ["'self'", "'unsafe-inline'", "https://www.google-analytics.com", "https://cdnjs.cloudflare.com"]
    style-src   = ["'self'", "'unsafe-inline'", "https://fonts.googleapis.com", "https://cdnjs.cloudflare.com"]
    font-src    = ["'self'", "https://fonts.gstatic.com", "https://cdnjs.cloudflare.com"]
    img-src     = ["'self'", "data:", "https:", "*.unsplash.com"]
    connect-src = ["'self'", "https://www.google-analytics.com"]
  }
}

# Feature Flags
variable "feature_flags" {
  description = "Feature flags for the application"
  type        = map(bool)
  default = {
    enable_analytics          = true
    enable_error_tracking     = true
    enable_performance_monitoring = true
    enable_live_chat         = false
    enable_newsletter        = true
    enable_dark_mode         = false
    enable_blog              = false
  }
}

# Build Configuration
variable "build_timeout" {
  description = "Build timeout in minutes"
  type        = number
  default     = 10
  
  validation {
    condition     = var.build_timeout >= 1 && var.build_timeout <= 60
    error_message = "Build timeout must be between 1 and 60 minutes."
  }
}

variable "node_version" {
  description = "Node.js version for builds"
  type        = string
  default     = "18"
  
  validation {
    condition     = contains(["16", "18", "20"], var.node_version)
    error_message = "Node version must be one of: 16, 18, 20."
  }
}

# Tags
variable "additional_tags" {
  description = "Additional tags to apply to all resources"
  type        = map(string)
  default     = {}
}