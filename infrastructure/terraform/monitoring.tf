# SlightBuild Monitoring and Cost Management
# CloudWatch monitoring, budgets, and alerting configuration

# SNS Topic for Notifications
resource "aws_sns_topic" "alerts" {
  count = var.enable_monitoring && var.notification_email != "" ? 1 : 0
  
  name         = "${var.app_name}-alerts"
  display_name = "SlightBuild Alerts"
  
  tags = {
    Name    = "${var.app_name}-alerts"
    Purpose = "Monitoring and cost alerts"
  }
}

# SNS Topic Subscription
resource "aws_sns_topic_subscription" "email_alerts" {
  count = var.enable_monitoring && var.notification_email != "" ? 1 : 0
  
  topic_arn = aws_sns_topic.alerts[0].arn
  protocol  = "email"
  endpoint  = var.notification_email
}

# Cost Budget
resource "aws_budgets_budget" "monthly_cost" {
  count = var.enable_monitoring ? 1 : 0
  
  name         = "${var.app_name}-monthly-budget"
  budget_type  = "COST"
  limit_amount = var.cost_budget_limit
  limit_unit   = "USD"
  time_unit    = "MONTHLY"
  
  time_period_start = "2024-01-01_00:00"
  time_period_end   = "2087-06-15_00:00"
  
  cost_filters = {
    Service = ["Amazon Amplify", "Amazon CloudFront", "Amazon Route 53", "AWS Certificate Manager"]
  }
  
  # Alert when 80% of budget is reached
  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                 = 80
    threshold_type            = "PERCENTAGE"
    notification_type         = "ACTUAL"
    subscriber_email_addresses = var.notification_email != "" ? [var.notification_email] : []
  }
  
  # Alert when 100% of budget is reached
  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                 = 100
    threshold_type            = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = var.notification_email != "" ? [var.notification_email] : []
  }
  
  # Forecast alert when projected to exceed budget
  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                 = 100
    threshold_type            = "PERCENTAGE"
    notification_type          = "FORECASTED"
    subscriber_email_addresses = var.notification_email != "" ? [var.notification_email] : []
  }
}

# CloudWatch Dashboard
resource "aws_cloudwatch_dashboard" "slightbuild_dashboard" {
  count = var.enable_monitoring ? 1 : 0
  
  dashboard_name = "${var.app_name}-dashboard"
  
  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6
        
        properties = {
          metrics = [
            ["AWS/Amplify", "Requests", "App", aws_amplify_app.slightbuild.name]
          ]
          view    = "timeSeries"
          stacked = false
          region  = var.aws_region
          title   = "Amplify Requests"
          period  = 300
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 6
        width  = 12
        height = 6
        
        properties = {
          metrics = [
            ["AWS/Amplify", "BytesDownloaded", "App", aws_amplify_app.slightbuild.name]
          ]
          view    = "timeSeries"
          stacked = false
          region  = var.aws_region
          title   = "Data Transfer"
          period  = 300
        }
      }
    ]
  })
}

# CloudWatch Log Group for Amplify Builds
resource "aws_cloudwatch_log_group" "amplify_builds" {
  count = var.enable_monitoring ? 1 : 0
  
  name              = "/aws/amplify/${aws_amplify_app.slightbuild.name}"
  retention_in_days = 14  # 2 weeks retention to control costs
  
  tags = {
    Name        = "${var.app_name}-build-logs"
    Purpose     = "Amplify build logs"
    Environment = var.environment
  }
}

# CloudWatch Alarm for High Error Rate
resource "aws_cloudwatch_metric_alarm" "high_error_rate" {
  count = var.enable_monitoring && var.notification_email != "" ? 1 : 0
  
  alarm_name          = "${var.app_name}-high-error-rate"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "4xxError"
  namespace           = "AWS/CloudFront"
  period              = "300"
  statistic           = "Sum"
  threshold           = "10"
  alarm_description   = "This metric monitors CloudFront 4xx errors"
  alarm_actions       = [aws_sns_topic.alerts[0].arn]
  
  dimensions = {
    DistributionId = aws_amplify_app.slightbuild.default_domain
  }
  
  tags = {
    Name = "${var.app_name}-high-error-rate-alarm"
  }
}

# CloudWatch Alarm for Build Failures
resource "aws_cloudwatch_metric_alarm" "build_failures" {
  count = var.enable_monitoring && var.notification_email != "" ? 1 : 0
  
  alarm_name          = "${var.app_name}-build-failures"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "BuildFailures"
  namespace           = "AWS/Amplify"
  period              = "300"
  statistic           = "Sum"
  threshold           = "0"
  alarm_description   = "This metric monitors Amplify build failures"
  alarm_actions       = [aws_sns_topic.alerts[0].arn]
  
  dimensions = {
    App = aws_amplify_app.slightbuild.name
  }
  
  tags = {
    Name = "${var.app_name}-build-failures-alarm"
  }
}

# Cost Anomaly Detection
resource "aws_ce_anomaly_detector" "cost_anomaly" {
  count = var.enable_monitoring ? 1 : 0
  
  name         = "${var.app_name}-cost-anomaly-detector"
  monitor_type = "DIMENSIONAL"
  
  specification = jsonencode({
    Dimension = "SERVICE"
    MatchOptions = ["EQUALS"]
    Values = ["Amazon Amplify"]
  })
  
  tags = {
    Name    = "${var.app_name}-cost-anomaly-detector"
    Purpose = "Cost anomaly detection"
  }
}

# Cost Anomaly Subscription
resource "aws_ce_anomaly_subscription" "cost_anomaly_subscription" {
  count = var.enable_monitoring && var.notification_email != "" ? 1 : 0
  
  name      = "${var.app_name}-cost-anomaly-subscription"
  frequency = "DAILY"
  
  monitor_arn_list = [
    aws_ce_anomaly_detector.cost_anomaly[0].arn
  ]
  
  subscriber {
    type    = "EMAIL"
    address = var.notification_email
  }
  
  threshold_expression {
    and {
      dimension {
        key           = "ANOMALY_TOTAL_IMPACT_ABSOLUTE"
        values        = ["100"]
        match_options = ["GREATER_THAN_OR_EQUAL"]
      }
    }
  }
  
  tags = {
    Name    = "${var.app_name}-cost-anomaly-subscription"
    Purpose = "Cost anomaly notifications"
  }
}

# CloudWatch Insights Queries for Analysis
resource "aws_cloudwatch_query_definition" "amplify_build_analysis" {
  count = var.enable_monitoring ? 1 : 0
  
  name = "${var.app_name}/amplify/build-analysis"
  
  log_group_names = [
    aws_cloudwatch_log_group.amplify_builds[0].name
  ]
  
  query_string = <<EOF
fields @timestamp, @message
| filter @message like /ERROR/ or @message like /FAILED/
| sort @timestamp desc
| limit 20
EOF
}

resource "aws_cloudwatch_query_definition" "amplify_performance" {
  count = var.enable_monitoring ? 1 : 0
  
  name = "${var.app_name}/amplify/performance"
  
  log_group_names = [
    aws_cloudwatch_log_group.amplify_builds[0].name
  ]
  
  query_string = <<EOF
fields @timestamp, @message, @duration
| filter @type = "REPORT"
| stats avg(@duration), max(@duration), min(@duration) by bin(5m)
EOF
}