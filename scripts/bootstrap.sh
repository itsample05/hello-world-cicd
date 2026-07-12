#!/usr/bin/env bash
# Creates AWS infrastructure and saves the generated deployment-role ARN in GitHub.
# Run with: bash scripts/bootstrap.sh --github-repository owner/repository
set -Eeuo pipefail

AWS_REGION="us-east-1"
APP_NAME="hello-world"
CONTAINER_IMAGE="hello-world:bootstrap"
GITHUB_REPOSITORY="itsample05/hello-world-cicd"
SKIP_GITHUB_VARIABLE=false

usage() {
  cat <<'EOF'
Usage: bash scripts/bootstrap.sh --github-repository OWNER/REPOSITORY [options]

Options:
  --container-image IMAGE       Bootstrap image name (default: hello-world:bootstrap)
  --aws-region REGION           AWS region (default: us-east-1)
  --app-name NAME               Application name (default: hello-world)
  --skip-github-variable        Do not save AWS_DEPLOY_ROLE_ARN with GitHub CLI
  -h, --help                    Show this help
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --github-repository) GITHUB_REPOSITORY="${2:?A repository is required}"; shift 2 ;;
    --container-image) CONTAINER_IMAGE="${2:?An image is required}"; shift 2 ;;
    --aws-region) AWS_REGION="${2:?A region is required}"; shift 2 ;;
    --app-name) APP_NAME="${2:?An app name is required}"; shift 2 ;;
    --skip-github-variable) SKIP_GITHUB_VARIABLE=true; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; usage >&2; exit 1 ;;
  esac
done

[[ -n "$GITHUB_REPOSITORY" ]] || { echo "--github-repository is required." >&2; usage >&2; exit 1; }

for command in terraform aws; do
  command -v "$command" >/dev/null || { echo "'$command' is required. Install it, then run this script again." >&2; exit 1; }
done

aws sts get-caller-identity >/dev/null

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
terraform_dir="$script_dir/../terraform"
pushd "$terraform_dir" >/dev/null
trap 'popd >/dev/null' EXIT

terraform init
terraform apply -auto-approve \
  -var "aws_region=$AWS_REGION" \
  -var "app_name=$APP_NAME" \
  -var "github_repository=$GITHUB_REPOSITORY" \
  -var "container_image=$CONTAINER_IMAGE"

role_arn="$(terraform output -raw github_deploy_role_arn)"
application_url="$(terraform output -raw application_url)"
echo "AWS bootstrap complete. Application URL: $application_url"

if [[ "$SKIP_GITHUB_VARIABLE" == false ]]; then
  command -v gh >/dev/null || { echo "AWS is ready. Install GitHub CLI, then run: gh variable set AWS_DEPLOY_ROLE_ARN --repo '$GITHUB_REPOSITORY' --body '$role_arn'" >&2; exit 1; }
  gh auth status >/dev/null
  gh variable set AWS_DEPLOY_ROLE_ARN --repo "$GITHUB_REPOSITORY" --body "$role_arn"
  echo "Set AWS_DEPLOY_ROLE_ARN in $GITHUB_REPOSITORY."
fi
