output "alb_arn" {
  value = aws_lb.this.arn
}

output "alb_arn_suffix" {
  description = "For building an ALBRequestCountPerTarget autoscaling resource_label (\"<alb-arn-suffix>/<target-group-arn-suffix>\") — not the same as alb_arn."
  value       = aws_lb.this.arn_suffix
}

output "dns_name" {
  value = aws_lb.this.dns_name
}

output "zone_id" {
  value = aws_lb.this.zone_id
}

output "security_group_id" {
  value = aws_security_group.this.id
}

output "target_group_arns" {
  description = "Map keyed by each target_groups[*].key, e.g. target_group_arns[\"bff\"]."
  value       = { for k, tg in aws_lb_target_group.this : k => tg.arn }
}

output "target_group_arn_suffixes" {
  description = "Same keys as target_group_arns, but the arn_suffix form an ALBRequestCountPerTarget resource_label needs."
  value       = { for k, tg in aws_lb_target_group.this : k => tg.arn_suffix }
}
