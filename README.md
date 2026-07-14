# Hello World on Amazon ECS (Fargate)

[![CI](https://github.com/itsample05/hello-world-cicd/actions/workflows/ci.yml/badge.svg)](https://github.com/itsample05/hello-world-cicd/actions/workflows/ci.yml)
[![CD](https://github.com/itsample05/hello-world-cicd/actions/workflows/cd.yml/badge.svg)](https://github.com/itsample05/hello-world-cicd/actions/workflows/cd.yml)

A production-grade demonstration of a **Spring Boot** application built, validated, containerized, and deployed to **Amazon ECS on Fargate** using **Terraform** and **modular GitHub Actions**.

This repository implements the DevOps assignment using industry-standard security, automation, and CI/CD best practices.

---

# 🚀 Assignment Compliance Matrix

| Requirement | Implementation | Best Practice |
|-------------|----------------|---------------|
| **Java Compilation & Verification** | Performed by reusable `static-analysis.yml` workflow using Maven | Maven dependency caching for faster builds |
| **Static Code Analysis** | Checkstyle, SpotBugs and JaCoCo integrated | Prevents low-quality code from progressing through the pipeline |
| **Publish Reports** | HTML reports published to GitHub Pages on successful `main` builds | Feature branches cannot overwrite production reports |
| **Docker Image Build & Push** | Multi-stage Docker build with Docker Buildx | Immutable SHA tagging and Docker layer caching |
| **Container Security** | Trivy vulnerability scanning before publishing image | Blocks builds containing High/Critical vulnerabilities |
| **AWS Deployment** | ECS Fargate behind Application Load Balancer | Zero public IPs on containers; application runs in private subnets |

---

# 🏗️ Architecture

```text
                    Internet
                        │
                        ▼
           +-------------------------+
           | Application Load Balancer|
           |  Public Subnets (2 AZs) |
           +------------+------------+
                        │
                HTTP : 8080
                        │
          +-------------+-------------+
          │                           │
          ▼                           ▼
 +------------------+       +------------------+
 | Private Subnet   |       | Private Subnet   |
 | ECS Fargate Task |       | ECS Fargate Task |
 +---------+--------+       +---------+--------+
           │                          │
           └──────────┬───────────────┘
                      ▼
              Amazon CloudWatch Logs
```

---

# 🔒 Security Highlights

- **OIDC Authentication**
  - GitHub Actions authenticates to AWS using OpenID Connect.
  - No long-lived AWS Access Keys are stored in GitHub.

- **Private ECS Tasks**
  - Containers run in private subnets.
  - Only the ALB is publicly accessible.

- **Least Privilege Security Groups**
  - ECS accepts traffic only from the ALB Security Group.

- **High Availability**
  - Multi-AZ deployment across two Availability Zones.

- **Cost Optimization**
  - Single NAT Gateway used for testing and learning purposes.

---

# ⚙️ CI/CD Pipeline

The pipeline is modular and reusable.

```text
.github/workflows/
├── ci.yml
├── cd.yml
├── static-analysis.yml
├── build-and-push.yml
└── deploy-aws.yml
```

## Workflow Responsibilities

| Workflow | Responsibility |
|-----------|----------------|
| **ci.yml** | CI orchestration |
| **cd.yml** | CD orchestration |
| **static-analysis.yml** | Build, Unit Tests, Checkstyle, SpotBugs, JaCoCo |
| **build-and-push.yml** | Docker Build, Trivy Scan, Docker Hub Push |
| **deploy-aws.yml** | AWS OIDC Authentication & ECS Deployment |

---

# 🔄 Pipeline Lifecycle

```text
Developer
    │
    ├──────────── Push to Feature Branch ─────────────┐
    │                                                 │
    ▼                                                 │
Static Analysis                                       │
Build Docker Image                                    │
Trivy Security Scan                                   │
    │                                                 │
    ▼                                                 │
Developer fixes issues                                │
                                                      │
Open Pull Request                                     │
      │                                               │
      ▼                                               │
Run Full CI Validation                               │
      │                                               │
      ▼                                               │
Merge to main                                         │
      │                                               │
      ▼                                               │
Publish Reports to GitHub Pages                       │
Build & Push Docker Image                             │
Deploy to Amazon ECS                                  │
```

---

# 📋 Prerequisites

- AWS Account
- Docker Hub Account
- GitHub Account
- AWS CLI
- Terraform 1.x+
- Git
- GitHub CLI (`gh`)

---

# 🚀 Setup Guide

## 1. Configure Terraform Variables

Copy the example file.

```bash
cp terraform/terraform.tfvars.example terraform/terraform.tfvars
```

Update the values.

```hcl
aws_region        = "us-east-1"
app_name          = "hello-world"
container_image   = "YOUR_DOCKERHUB_USERNAME/hello-world-app:bootstrap"
github_repository = "YOUR_GITHUB_USERNAME/hello-world-cicd"
```

> **Bootstrap Image**
>
> Push an initial image (for example `nginx` or a simple Spring Boot image) tagged as `bootstrap`. This allows ECS to create the service before the CI/CD pipeline publishes the first application image.

---

## 2. Provision AWS Infrastructure

```bash
cd terraform

terraform init
terraform validate
terraform plan -out=tfplan
terraform apply tfplan
```

Terraform provisions:

- VPC
- Public & Private Subnets
- NAT Gateway
- Application Load Balancer
- ECS Cluster
- ECS Service
- IAM Roles
- OIDC Provider
- CloudWatch Log Group

---

## 3. Bootstrap GitHub

Authenticate using GitHub CLI.

```bash
gh auth login
```

Run the bootstrap helper.

```bash
bash scripts/bootstrap.sh
```

This automatically configures the GitHub repository variable:

```
AWS_DEPLOY_ROLE_ARN
```

---

## 4. Configure GitHub Secrets

Navigate to:

```
Repository
→ Settings
→ Secrets and variables
→ Actions
```

### Secrets

| Name |
|------|
| DOCKERHUB_TOKEN |

### Variables

| Name |
|------|
| DOCKERHUB_USERNAME |
| AWS_DEPLOY_ROLE_ARN |

---

## 5. Enable GitHub Pages

Navigate to

```
Settings
→ Pages
```

Choose

```
Build and deployment

Source:
GitHub Actions
```

---

# 📈 Verification

After the CD pipeline succeeds:

```bash
cd terraform

terraform output -raw application_url
```

Open the returned URL in your browser.

---

# 📊 Static Analysis Reports

After every successful deployment to `main`, GitHub Pages hosts:

- JaCoCo Coverage Report
- Checkstyle Report
- SpotBugs Report

---

# 🧹 Clean Up

To avoid AWS charges:

```bash
cd terraform

terraform destroy
```

---

# 🛠️ Technologies Used

- Java 17
- Spring Boot
- Maven
- Docker
- Docker Buildx
- Trivy
- GitHub Actions
- Terraform
- AWS ECS Fargate
- Application Load Balancer
- IAM OIDC
- CloudWatch
- GitHub Pages

---

# 📜 License

This repository is intended for educational and demonstration purposes as part of a DevOps CI/CD assignment.