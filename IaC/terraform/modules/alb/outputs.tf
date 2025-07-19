
output "alb_dns_name" {
  value = aws_lb.web_alb.dns_name
}

output "frontend_target_group_arn" {
  value = aws_lb_target_group.frontend_tg.arn
}

output "backend_target_group_arn" {
  value = aws_lb_target_group.backend_tg.arn
}