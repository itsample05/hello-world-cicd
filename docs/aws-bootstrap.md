# AWS bootstrap: run before GitHub CD

The first infrastructure deployment must be started locally because GitHub Actions does not yet have an AWS role to assume. This is a one-time bootstrap step; all later application deployments are performed by GitHub Actions through OIDC.

## What the bootstrap creates

* GitHub Actions OIDC identity provider
* Least-privilege GitHub deployment role
* ECS execution and task roles
* VPC, two public subnets, two private subnets, internet gateway, and NAT gateway
* Public application load balancer and restrictive security groups
* ECS Fargate cluster, service, task definition, and CloudWatch log group

## Before running it

1. Create a public Docker Hub repository named `hello-world-app`.
2. Install Terraform, AWS CLI, and optionally GitHub CLI.
3. Authenticate AWS CLI locally with an identity that may create IAM, VPC, ALB, ECS, and CloudWatch resources. These credentials are only for the bootstrap; do not put them in GitHub.
4. If you want the script to configure the GitHub variable too, run `gh auth login` and authorize access to the target repository.

## Run

From the repository root in Git Bash or WSL (recommended):

```bash
bash scripts/bootstrap.sh --github-repository "YOUR_GITHUB_USERNAME/YOUR_REPOSITORY"
```

Or, from PowerShell:

```powershell
.\scripts\bootstrap.ps1 `
  -GitHubRepository "YOUR_GITHUB_USERNAME/YOUR_REPOSITORY"
```

The script creates the ECS service with zero tasks, so it does not need a local Docker image. It prints the public application URL and sets GitHub repository variable `AWS_DEPLOY_ROLE_ARN` when GitHub CLI is available. If not, copy the displayed Terraform output into **GitHub → Settings → Secrets and variables → Actions → Variables**.

## Afterwards

Enable GitHub Pages with source **GitHub Actions**, add Docker Hub secrets, and merge to `main` or `master`. The CD workflow will deploy without AWS access keys, using the OIDC role created above.

> Cost note: the NAT gateway is not covered by AWS Free Tier. Destroy the demo after evaluation with `terraform destroy` from `terraform/` to prevent ongoing charges.
