# Hello World on Amazon ECS

[![CI](https://github.com/itsample05/hello-world-cicd/actions/workflows/ci.yml/badge.svg)](https://github.com/itsample05/hello-world-cicd/actions/workflows/ci.yml)
[![CD](https://github.com/itsample05/hello-world-cicd/actions/workflows/cd.yml/badge.svg)](https://github.com/itsample05/hello-world-cicd/actions/workflows/cd.yml)

This project builds a Spring Boot service into a Docker image and deploys it to Amazon ECS on Fargate. GitHub Actions validates changes, publishes approved `main` builds, and deploys them through an Application Load Balancer (ALB).

## Architecture

```text
Internet
   |
Public ALB (HTTP, port 80)
   |
   +-- target group / health check
           |
Private subnet, AZ 1       Private subnet, AZ 2
ECS Fargate task           ECS Fargate task
           |                       |
           +---- CloudWatch Logs --+

GitHub Actions -- OIDC --> AWS deployment role --> ECS service
GitHub Actions -- Docker Hub token --> Docker Hub image repository
```

Terraform creates two Availability Zones, public ALB subnets, and private ECS subnets. The ECS desired count equals the number of private subnets, giving one task per Availability Zone. The ALB is the only internet-facing component; tasks accept port 8080 traffic only from the ALB.

> This demonstration uses one NAT gateway to reduce cost. For production availability, use one NAT gateway and private route table per Availability Zone. The supplied ALB is HTTP-only; HTTPS needs a domain, ACM certificate, and a port-443 listener.

## CI/CD workflow

| Event | Activity | External effect |
| --- | --- | --- |
| Push to any non-`main` branch | Tests, package build, Checkstyle, SpotBugs, JaCoCo | No image build, scan, publish, or deployment |
| Pull request to `main` | The same validation, local Docker build, and Trivy image scan | No Docker Hub login/push or deployment |
| Push/merge to `main` | Validation, GitHub Pages report, Docker build, Trivy scan, image publishing, ECS deployment | Publishes immutable SHA image, `latest`, and deploys |

Every validation run uploads a 30-day report artifact. GitHub Pages publishes only the latest `main` report so a pull request cannot overwrite it.

## Prerequisites

- AWS CLI credentials that may create IAM, VPC, ALB, ECS, and CloudWatch resources for the initial deployment.
- Terraform 1.x, Git Bash or WSL, and GitHub CLI (`gh`).
- A public Docker Hub repository named `hello-world-app` (or update the workflow image name).
- GitHub Actions and GitHub Pages enabled for the repository.
- A Docker Hub access token with permission to push images.

## Initial infrastructure setup

1. Copy `terraform/terraform.tfvars.example` to `terraform/terraform.tfvars` and set these values:

   ```hcl
   aws_region        = "us-east-1"
   app_name          = "hello-world"
   container_image   = "YOUR_DOCKERHUB_USER/hello-world-app:bootstrap"
   github_repository = "YOUR_GITHUB_USER/YOUR_REPOSITORY"
   ```

   The bootstrap image must already exist in the public Docker Hub repository. It is used only for the first ECS task definition; a `main` deployment replaces it with an immutable commit-SHA image.

2. Review and apply the infrastructure manually. From `terraform/`:

   ```bash
   terraform init
   terraform validate
   terraform plan -out=tfplan
   terraform apply tfplan
   ```

   Read the plan before applying it. It creates the OIDC deployment role, ECS roles, VPC, subnets, NAT gateway, ALB, Fargate cluster/service, task definition, and CloudWatch log group.

3. Authenticate GitHub CLI (`gh auth login`), then run the post-deployment helper from the repository root:

   ```bash
   bash scripts/bootstrap.sh
   ```

   It verifies the Terraform-created IAM role and adds the `AWS_DEPLOY_ROLE_ARN` repository variable. It never runs Terraform commands.

4. In GitHub **Settings → Secrets and variables → Actions**, add:

   | Type | Name | Value |
   | --- | --- | --- |
   | Secret | `DOCKERHUB_TOKEN` | Docker Hub access token |
   | Variable | `DOCKERHUB_USERNAME` | Docker Hub namespace/user name |

5. In GitHub **Settings → Pages**, choose **GitHub Actions** as the source. Protect `main` with the pull-request checks `analysis` and `build-and-scan-image`.

6. Push a feature branch, open a pull request to `main`, and merge after checks pass. The `main` workflow publishes and deploys the application. Obtain the endpoint with:

   ```bash
   cd terraform
   terraform output -raw application_url
   ```

## Operations notes

- Terraform ignores ECS task-definition revisions because GitHub Actions registers new revisions during deployment. Terraform continues to manage capacity.
- State and `terraform.tfvars` are ignored. Use an encrypted remote S3/DynamoDB Terraform backend before team or production use.
- The deployment workflow targets the `production` GitHub Environment. Configure required reviewers there if deployment approval is needed.
- Destroy demo infrastructure when finished to prevent charges:

  ```bash
  cd terraform
  terraform destroy
  ```
