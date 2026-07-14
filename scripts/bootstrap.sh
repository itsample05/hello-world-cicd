#!/usr/bin/env bash
# Publishes the Terraform-created GitHub deployment-role ARN to GitHub.
# Run this only after you manually apply Terraform. It never runs Terraform.
set -Eeuo pipefail

usage() {
  cat <<'EOF'
Usage: bash scripts/bootstrap.sh

Reads deployment values from the existing Terraform state, verifies the IAM
role, and sets GitHub repository variables. This script does not run terraform
init, plan, or apply.
EOF
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

if [[ $# -gt 0 ]]; then
  usage >&2
  exit 1
fi

for command in terraform aws gh; do
  command -v "$command" >/dev/null || {
    echo "'$command' is required. Install it, then run this script again." >&2
    exit 1
  }
done

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
terraform_dir="$script_dir/../terraform"

[[ -d "$terraform_dir" ]] || {
  echo "Terraform directory not found: $terraform_dir" >&2
  exit 1
}

pushd "$terraform_dir" >/dev/null
trap 'popd >/dev/null' EXIT

role_arn="$(terraform output -raw github_deploy_role_arn)"
github_repository="$(terraform output -raw github_repository)"
aws_region="$(terraform output -raw aws_region)"
ecs_cluster="$(terraform output -raw ecs_cluster_name)"
ecs_service="$(terraform output -raw ecs_service_name)"
ecs_task_family="$(terraform output -raw ecs_task_family)"
application_url="$(terraform output -raw application_url)"

[[ "$role_arn" =~ ^arn:aws:iam::[0-9]{12}:role/.+$ ]] || {
  echo "Terraform output github_deploy_role_arn is not a valid IAM role ARN: $role_arn" >&2
  exit 1
}

role_name="${role_arn##*/}"
aws iam get-role --role-name "$role_name" --query 'Role.Arn' --output text | grep -Fx "$role_arn" >/dev/null || {
  echo "AWS could not verify IAM role: $role_arn" >&2
  exit 1
}

gh auth status >/dev/null
gh variable set AWS_DEPLOY_ROLE_ARN --repo "$github_repository" --body "$role_arn"
gh variable set AWS_REGION --repo "$github_repository" --body "$aws_region"
gh variable set ECS_CLUSTER --repo "$github_repository" --body "$ecs_cluster"
gh variable set ECS_SERVICE --repo "$github_repository" --body "$ecs_service"
gh variable set ECS_TASK_FAMILY --repo "$github_repository" --body "$ecs_task_family"
gh variable set APPLICATION_URL --repo "$github_repository" --body "$application_url"

echo "Verified $role_arn and set deployment variables in $github_repository."
