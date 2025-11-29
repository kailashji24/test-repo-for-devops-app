output "alb_url" {
  value = "http://${aws_lb.app_alb.dns_name}"
}

output "log_bucket" {
  value = aws_s3_bucket.logs.bucket
}

output "sns_topic" {
  value = aws_sns_topic.alerts.arn
}