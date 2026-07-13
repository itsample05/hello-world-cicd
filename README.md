# Hello World on Amazon ECS

[![CI](https://github.com/itsample05/hello-world-cicd/actions/workflows/ci.yml/badge.svg)](https://github.com/itsample05/hello-world-cicd/actions/workflows/ci.yml)
[![CD](https://github.com/itsample05/hello-world-cicd/actions/workflows/cd.yml/badge.svg)](https://github.com/itsample05/hello-world-cicd/actions/workflows/cd.yml)

This repository packages a Spring Boot service as a container and deploys it to Amazon ECS on Fargate. GitHub Actions validates every change, publishes only approved `main` builds, and rolls those builds out through an Application Load Balancer (ALB).

## Architecture

```text
Internet
   |
Public ALB (one public subnet per AZ)
   |
   +-- target group / health checks
           |
Private subnet, AZ 1       Private subnet, AZ 2
ECS Fargate task           ECS Fargate task
           |                       |
           +---- CloudWatch Logs --+

GitHub Actions -- OIDC --> AWS deployment role --> ECS service
GitHub Actions -- Docker Hub token --> Docker Hub image repository
```

Terraform creates a VPC with two Availability Zones, public subnets for the ALB, and private subnets for ECS tasks. The ALB is the only internet-facing component. Tasks accept port 8080 traffic solely from the ALB security group and use a NAT gateway for outbound connections.

The ECS service desired count is derived from the number of private subnets. With the supplied two-AZ network this is **two tasks**—one task per Availability Zone. ECS deployment balancing maintains the distribution; if an AZ has an outage, the configured desired count may temporarily be unattainable until capacity returns.

> The example uses one NAT gateway to keep demonstration cost down. A production multi-AZ design should create one NAT gateway and private route table per Availability Zone so outbound connectivity is also zone-resilient.

## CI/CD workflow

| Event | Workflow activity | Docker Hub / AWS effect |
| --- | --- | --- |
| Push to any non-`main` branch | Maven tests, package build, Checkstyle, SpotBugs, JaCoCo report | None: no container build, image push, or Trivy scan |
| Pull request targeting `main` | The same Maven validation, then a local Docker image build and Trivy image scan | None: no Docker Hub login/push and no deployment |
| Push or merge to `main` | Full CI/CD: Maven validation, report publication, Docker build, Trivy scan, immutable SHA image push, `latest` tag push, ECS rolling deployment | Publishes and deploys |

GitHub Pages receives the default-branch quality report. Every analysis run also uploads a 30-day Actions artifact. Image tags use the commit SHA for deployments, so ECS always receives an immutable image; `latest` is a convenience tag only.

## Prerequisites

- An AWS account with permission to perform the one-time bootstrap, plus AWS CLI credentials configured locally.
- Terraform 1.x and Git Bash or WSL.
- A GitHub repository with Actions enabled and a Docker Hub repository (for example, `hello-world-app`).
- A Docker Hub access token with permission to push to that repository.
- GitHub Pages configured to use **GitHub Actions** as its source.
- Java 17 and Maven are only needed for local application development; Docker is needed for local container testing.

## One-time setup

1. Copy `terraform/terraform.tfvars.example` to `terraform/terraform.tfvars` and set `github_repository` to `OWNER/REPOSITORY`.
2. Manually run `terraform init`, `terraform validate`, `terraform plan -out=tfplan`, and then `terraform apply tfplan` from `terraform/` after you have reviewed the plan. Next, run:

   ```bash
   bash scripts/bootstrap.sh
   ```

   This script verifies the Terraform-created deployment-role ARN and saves it as `AWS_DEPLOY_ROLE_ARN` in GitHub. It never runs `terraform init`, `terraform plan`, or `terraform apply`. See [AWS bootstrap](docs/aws-bootstrap.md) for the manual review-and-deploy steps.
3. In GitHub repository **Settings → Secrets and variables → Actions**, add:

   | Type | Name | Value |
   | --- | --- | --- |
   | Secret | `DOCKERHUB_TOKEN` | Docker Hub access token |
   | Variable | `DOCKERHUB_USERNAME` | Docker Hub namespace/user name |
   | Variable | `AWS_DEPLOY_ROLE_ARN` | Terraform output `github_deploy_role_arn` |
4. In GitHub **Settings → Pages**, choose **GitHub Actions** as the build source.
5. Push a feature branch, open a pull request to `main`, and merge it after the pull-request checks pass. The main-branch workflow publishes the image and deploys it. Retrieve the endpoint with Terraform output `application_url`.

## Local validation

```powershell
mvn verify checkstyle:check spotbugs:check
docker build -t hello-world-app:local .
docker run --rm -p 8080:8080 hello-world-app:local
```

The application endpoint is available through the ALB after deployment; local container testing exposes the same application on port 8080.

## Operational notes

- Terraform deliberately ignores ECS task-definition revisions because GitHub Actions registers them during deployment. Terraform continues to manage desired capacity.
- Terraform state and `terraform.tfvars` are excluded from source control. For team or production usage, configure a separate encrypted S3/DynamoDB backend before deploying shared infrastructure.
- Protect `main` with the `CI` workflow as a required status check so validation occurs before a merge.
