# Hello World — CI/CD assignment

This repository implements the requested Spring Boot application, Docker image pipeline, static analysis, GitHub Pages report, and AWS ECS/Fargate deployment.

## Repository layout

```text
.
├── .github/workflows/       # thin entry workflows and reusable jobs
├── src/                     # Spring Boot application and tests
├── terraform/               # VPC, ALB, ECS, IAM/OIDC and logs
├── Dockerfile               # non-root, multi-stage runtime image
└── pom.xml
```

## Pipeline behaviour

| Trigger | What runs |
| --- | --- |
| Push to `feature/**`, `feat/**`, `fix/**`, or `hotfix/**` | tests, Checkstyle, SpotBugs, JaCoCo, Trivy, Docker Hub image tagged with commit SHA |
| Push to `main`/`master` | CI, GitHub Pages report, immutable SHA image, `latest` image, ECS rolling deployment |

Feature-branch reports are retained as GitHub Actions artifacts. The latest default-branch report is published to GitHub Pages. This avoids branches overwriting each other on the single Pages site.

## One-time setup

1. Create a public Docker Hub repository called `hello-world-app` (or update the workflow name). ECS can pull a public Docker Hub image without storing Docker Hub credentials in AWS.
2. In GitHub **Settings → Pages**, set the source to **GitHub Actions**.
3. Copy `terraform/terraform.tfvars.example` to `terraform.tfvars`, replace both placeholders, then run `terraform init` and `terraform apply` from `terraform/` using a suitably limited administrator/bootstrap identity.
4. Add repository secrets `DOCKERHUB_USERNAME` and `DOCKERHUB_TOKEN`.
5. Add repository variable `AWS_DEPLOY_ROLE_ARN` using Terraform output `github_deploy_role_arn`. No long-lived AWS access keys are stored in GitHub.
6. Push to a feature branch, then merge it to the repository's default branch. Terraform output `application_url` is the public URL.

## Design notes

Tasks run in private subnets. Only the public ALB accepts inbound internet traffic; the task security group permits port 8080 only from the ALB. A single NAT gateway gives private tasks outbound access to Docker Hub, AWS APIs, and CloudWatch. It is intentionally documented as a cost/availability trade-off: production should use one NAT gateway per Availability Zone, while a low-cost demonstration may use one.

`terraform.tfvars` and all Terraform state are ignored. For a team or production deployment, bootstrap a separate encrypted S3/DynamoDB Terraform backend and add it to `versions.tf`; backend resources cannot safely be created by the same state that uses them.
