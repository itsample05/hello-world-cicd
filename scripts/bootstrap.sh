#!/usr/bin/env bash
# Writes Terraform-created deployment values to a reviewed, environment-specific
# configuration file. Run this only after you manually apply Terraform. It never
# runs Terraform or changes GitHub repository settings.
set -Eeuo pipefail

usage() {
  cat <<'EOF'
Usage: bash scripts/bootstrap.sh <environment>

Reads deployment values from the existing Terraform state and verifies the IAM
role. It writes a non-secret JSON configuration file that is read by the
deployment workflow at .github/deployments/<environment>.json. The Docker Hub
namespace defaults to the owner of github_repository in Terraform; edit the
generated JSON in your pull request if the Docker Hub namespace is different.

Commit the generated file on a branch and merge it through a pull request.
This script does not run terraform init, plan, or apply, and does not change
GitHub repository variables.
EOF
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

if [[ $# -ne 1 ]]; then
  usage >&2
  exit 1
fi

environment="$1"

[[ "$environment" =~ ^[a-z0-9][a-z0-9-]{0,62}$ ]] || {
  echo "--environment must contain lowercase letters, numbers, and hyphens." >&2
  exit 1
}
for command in terraform aws; do
  command -v "$command" >/dev/null || {
    echo "'$command' is required. Install it, then run this script again." >&2
    exit 1
  }
done

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
terraform_dir="$script_dir/../terraform"
repository_dir="$(cd "$script_dir/.." && pwd)"
output_file="$repository_dir/.github/deployments/$environment.json"

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
dockerhub_username="${github_repository%%/*}"

# Existing state created before the app_name output was introduced can still
# produce a configuration file. The task family is always <app_name>-task.
if ! app_name="$(terraform output -raw app_name 2>/dev/null)"; then
  app_name="${ecs_task_family%-task}"
fi

[[ "$role_arn" =~ ^arn:aws:iam::[0-9]{12}:role/.+$ ]] || {
  echo "Terraform output github_deploy_role_arn is not a valid IAM role ARN: $role_arn" >&2
  exit 1
}

role_name="${role_arn##*/}"
aws iam get-role --role-name "$role_name" --query 'Role.Arn' --output text | grep -Fx "$role_arn" >/dev/null || {
  echo "AWS could not verify IAM role: $role_arn" >&2
  exit 1
}

mkdir -p "$(dirname "$output_file")"
cat > "$output_file" <<EOF
{
  "environment": "$environment",
  "app_name": "$app_name",
  "dockerhub_username": "$dockerhub_username",
  "aws_region": "$aws_region",
  "aws_deploy_role_arn": "$role_arn",
  "ecs_cluster": "$ecs_cluster",
  "ecs_service": "$ecs_service",
  "ecs_task_family": "$ecs_task_family"
}
EOF

echo "Verified $role_arn for $github_repository."
echo "Wrote reviewed deployment configuration: $output_file"
echo "Application URL: $application_url"
