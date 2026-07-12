output "application_url" {
  value = "http://${aws_lb.this.dns_name}"
}

output "github_deploy_role_arn" {
  value = aws_iam_role.github_deploy.arn
}
