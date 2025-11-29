resource "random_id" "bucket_suffix" {
  byte_length = 4
}

# --- Log Buckets ---
# 1. App Logs (from User Data)
resource "aws_s3_bucket" "logs" {
  bucket        = var.logs_bucket_name != "" ? var.logs_bucket_name : "assignment3-app-logs-${random_id.bucket_suffix.hex}"
  force_destroy = true
}

# 2. ALB Access Logs (New Requirement)
resource "aws_s3_bucket" "alb_logs" {
  bucket        = "assignment3-alb-logs-${random_id.bucket_suffix.hex}"
  force_destroy = true
}

# Policy to allow ALB to write to S3
resource "aws_s3_bucket_policy" "alb_logs_policy" {
  bucket = aws_s3_bucket.alb_logs.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        AWS = "arn:aws:iam::718504428378:root" # AWS ALB Account ID for ap-south-1
      }
      Action   = "s3:PutObject"
      Resource = "${aws_s3_bucket.alb_logs.arn}/*"
    }]
  })
}

# --- DDoS Protection (WAF) ---
resource "aws_wafv2_web_acl" "rate_limit" {
  name        = "assignment3-waf-ddos"
  scope       = "REGIONAL"
  description = "Rate limit for DDoS protection"

  default_action {
    allow {}
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "waf-main"
    sampled_requests_enabled   = true
  }

  rule {
    name     = "rate-limit"
    priority = 1
    action {
      block {}
    }
    statement {
      rate_based_statement {
        limit              = 2000
        aggregate_key_type = "IP"
      }
    }
    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "rate-limit"
      sampled_requests_enabled   = true
    }
  }
}

resource "aws_wafv2_web_acl_association" "assoc" {
  resource_arn = aws_lb.app_alb.arn
  web_acl_arn  = aws_wafv2_web_acl.rate_limit.arn
}

# --- Richer Dashboard (Advanced Requirements) ---
resource "aws_cloudwatch_dashboard" "main" {
  dashboard_name = "Assignment3-Advanced-Dashboard"
  dashboard_body = jsonencode({
    widgets = [
      # Row 1: Scaling & CPU
      {
        type = "metric", x = 0, y = 0, width = 12, height = 6,
        properties = {
          metrics = [["AWS/EC2", "CPUUtilization", "AutoScalingGroupName", aws_autoscaling_group.asg.name]],
          period = 300, stat = "Average", region = var.region, title = "ASG CPU %"
        }
      },
      {
        type = "metric", x = 12, y = 0, width = 12, height = 6,
        properties = {
          metrics = [["AWS/AutoScaling", "GroupInServiceInstances", "AutoScalingGroupName", aws_autoscaling_group.asg.name]],
          period = 60, stat = "Average", region = var.region, title = "Active Instances"
        }
      },
      # Row 2: Traffic & Latency
      {
        type = "metric", x = 0, y = 6, width = 12, height = 6,
        properties = {
          metrics = [["AWS/ApplicationELB", "RequestCount", "LoadBalancer", aws_lb.app_alb.arn_suffix]],
          period = 60, stat = "Sum", region = var.region, title = "Total Requests"
        }
      },
      {
        type = "metric", x = 12, y = 6, width = 12, height = 6,
        properties = {
          metrics = [["AWS/ApplicationELB", "TargetResponseTime", "LoadBalancer", aws_lb.app_alb.arn_suffix]],
          period = 60, stat = "Average", region = var.region, title = "ALB Latency (Response Time)"
        }
      },
      # Row 3: Health & Networking
      {
        type = "metric", x = 0, y = 12, width = 12, height = 6,
        properties = {
          metrics = [
            ["AWS/ApplicationELB", "HealthyHostCount", "TargetGroup", aws_lb_target_group.app_tg.arn_suffix, "LoadBalancer", aws_lb.app_alb.arn_suffix],
            [".", "UnHealthyHostCount", ".", ".", ".", "."]
          ],
          period = 60, stat = "Average", region = var.region, title = "Healthy vs Unhealthy Hosts"
        }
      },
      {
        type = "metric", x = 12, y = 12, width = 12, height = 6,
        properties = {
          metrics = [
            ["AWS/EC2", "NetworkIn", "AutoScalingGroupName", aws_autoscaling_group.asg.name],
            [".", "NetworkOut", ".", "."]
          ],
          period = 300, stat = "Average", region = var.region, title = "Network In/Out"
        }
      }
    ]
  })
}

# --- Alarms & Notifications ---
resource "aws_autoscaling_policy" "cpu_policy" {
  name                   = "cpu-tracking"
  autoscaling_group_name = aws_autoscaling_group.asg.name
  policy_type            = "TargetTrackingScaling"
  
  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }
    target_value = 6.0
  }
}

resource "aws_sns_topic" "alerts" {
  name = "assignment3-alerts-final"
}

resource "aws_sns_topic_subscription" "email" {
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = var.email
}

# 1. Scale Out Alarm
resource "aws_cloudwatch_metric_alarm" "cpu_high" {
  alarm_name          = "high-cpu-alarm"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 300
  statistic           = "Average"
  threshold           = 6
  alarm_actions       = [aws_sns_topic.alerts.arn]
  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.asg.name
  }
}

# 2. Unhealthy Hosts Alarm
resource "aws_cloudwatch_metric_alarm" "unhealthy_hosts" {
  alarm_name          = "unhealthy-hosts-alarm"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "UnHealthyHostCount"
  namespace           = "AWS/ApplicationELB"
  period              = 60
  statistic           = "Average"
  threshold           = 0
  alarm_actions       = [aws_sns_topic.alerts.arn]
  
  dimensions = {
    TargetGroup  = aws_lb_target_group.app_tg.arn_suffix
    LoadBalancer = aws_lb.app_alb.arn_suffix
  }
}

# 3. ASG Lifecycle Notifications
resource "aws_autoscaling_notification" "asg_notifications" {
  group_names = [aws_autoscaling_group.asg.name]

  notifications = [
    "autoscaling:EC2_INSTANCE_LAUNCH",
    "autoscaling:EC2_INSTANCE_TERMINATE",
    "autoscaling:EC2_INSTANCE_LAUNCH_ERROR"
  ]

  topic_arn = aws_sns_topic.alerts.arn
}