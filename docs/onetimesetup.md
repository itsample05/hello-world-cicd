## 🛠️ One-Time Setup (AWS Infrastructure & GitHub)

Before the CI/CD pipeline can deploy to AWS, the infrastructure and GitHub OIDC integration must be bootstrapped once from your local machine. This creates the required AWS resources and securely configures GitHub Actions to deploy without storing long-lived AWS credentials.

---

### 1. Prerequisites & Configure Variables

Ensure the following are installed and configured:

- AWS CLI (authenticated with an account that can create IAM, VPC, ALB, ECS, etc.)
- Terraform 1.x+
- Git
- GitHub CLI (`gh`)
- Docker

Copy the Terraform variables example file:

```bash
cp terraform/terraform.tfvars.example terraform/terraform.tfvars
```

Update the values:

```hcl
aws_region        = "us-east-1"
app_name          = "hello-world"
container_image   = "YOUR_DOCKERHUB_USERNAME/hello-world-app:bootstrap"
github_repository = "YOUR_GITHUB_USERNAME/YOUR_REPOSITORY"
```

> 💡 **Bootstrap Image**
>
> Before provisioning the infrastructure, push a temporary Docker image tagged as **`bootstrap`** (for example `nginx` or a simple Spring Boot application) to your Docker Hub repository.
>
> Docker Hub automatically creates the repository on the first push. The bootstrap image allows ECS to create the initial service before the CI/CD pipeline publishes the first application image.

---

### 2. Provision AWS Infrastructure

Navigate to the Terraform directory and provision the infrastructure.

```bash
cd terraform

terraform init
terraform validate
terraform plan -out=tfplan

# Review the execution plan carefully.

terraform apply tfplan
```

This provisions:

- VPC
- Public & Private Subnets
- NAT Gateway
- Application Load Balancer
- ECS Cluster & Service
- IAM Roles
- GitHub OIDC Provider
- CloudWatch Log Group

---

### 3. Configure GitHub Integration

Authenticate with GitHub CLI:

```bash
gh auth login
```

Run the bootstrap helper script from the repository root:

```bash
bash scripts/bootstrap.sh
```

The script automatically retrieves the AWS Deployment Role ARN created by Terraform and registers it as a GitHub repository variable.

Next, configure the following GitHub Actions credentials:

**Repository → Settings → Secrets and variables → Actions**

#### Secrets

| Name | Description |
|------|-------------|
| `DOCKERHUB_TOKEN` | Docker Hub Personal Access Token with push permissions |

#### Variables

| Name | Description |
|------|-------------|
| `DOCKERHUB_USERNAME` | Docker Hub username/namespace |
| `AWS_DEPLOY_ROLE_ARN` | IAM Role ARN created by Terraform (added automatically by the bootstrap script) |

---

### 4. In **Settings → Pages**, choose **GitHub Actions** as the build source.
### 5. Push a feature branch, open a PR into `main`, and merge once checks pass. The `main` workflow publishes the image and deploys it. Grab the public URL from the Terraform output `application_url`

