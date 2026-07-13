# AWS bootstrap: manual review and deployment

The first infrastructure deployment must be performed locally because GitHub Actions does not yet have an AWS role to assume. The Bash helper is deliberately non-destructive: it checks prerequisites only and never runs Terraform commands that change infrastructure.

## Before Terraform

1. Create a public Docker Hub repository named `hello-world-app`.
2. Copy `terraform/terraform.tfvars.example` to `terraform/terraform.tfvars` and set these values once:

   ```hcl
   aws_region        = "us-east-1"
   app_name          = "hello-world"
   container_image   = "YOUR_DOCKERHUB_USER/hello-world-app:bootstrap"
   github_repository = "YOUR_GITHUB_USER/YOUR_REPOSITORY"
   ```
3. Install Terraform and AWS CLI. Authenticate the AWS CLI using an identity permitted to create IAM, VPC, ALB, ECS, and CloudWatch resources.
## Review and deploy manually

Run these commands from the `terraform` directory:

```bash
terraform init
terraform validate
terraform plan -out=tfplan
```

Read the plan carefully. It creates the OIDC deployment role, ECS roles, VPC, subnets, NAT gateway, ALB, Fargate cluster/service, task definition, and CloudWatch log group. With the supplied two-AZ configuration, the service starts two tasks—one in each Availability Zone.

Only after approving the plan, deploy the exact saved plan:

```bash
terraform apply tfplan
```

## After deployment

From the repository root, use the Bash helper to verify the Terraform-created IAM role and set `AWS_DEPLOY_ROLE_ARN` in GitHub:

```bash
bash scripts/bootstrap.sh
```

The helper requires Terraform, AWS CLI credentials, and an authenticated GitHub CLI. It does not run `terraform init`, `plan`, or `apply`.

Enable GitHub Pages with source **GitHub Actions**, add the `DOCKERHUB_TOKEN` secret and `DOCKERHUB_USERNAME` variable, then merge to `main`. The CD workflow deploys through OIDC with no AWS access keys stored in GitHub.

> Cost note: the NAT gateway is not covered by AWS Free Tier. When finished, run `terraform destroy` from `terraform/` to avoid ongoing charges.
