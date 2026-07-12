<#
Creates the AWS OIDC provider, ECS infrastructure, and the GitHub repository
variable used by the CD workflow. Run from the repository root.

Prerequisites: Terraform, AWS CLI credentials with permission to create IAM,
VPC, ECS, ALB, and CloudWatch resources, and an authenticated GitHub CLI.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)] [string] $GitHubRepository,
    [string] $ContainerImage = "hello-world:bootstrap",
    [string] $AwsRegion = "us-east-1",
    [string] $AppName = "hello-world",
    [switch] $SkipGitHubVariable
)

$ErrorActionPreference = "Stop"

foreach ($command in @("terraform", "aws")) {
    if (-not (Get-Command $command -ErrorAction SilentlyContinue)) {
        throw "'$command' is required. Install it, then run this script again."
    }
}

aws sts get-caller-identity | Out-Null

$terraformDirectory = Join-Path $PSScriptRoot "..\terraform"
Push-Location $terraformDirectory
try {
    terraform init
    terraform apply -auto-approve `
        -var "aws_region=$AwsRegion" `
        -var "app_name=$AppName" `
        -var "github_repository=$GitHubRepository" `
        -var "container_image=$ContainerImage"
    $roleArn = terraform output -raw github_deploy_role_arn
    $applicationUrl = terraform output -raw application_url
}
finally {
    Pop-Location
}

Write-Host "AWS bootstrap complete. Application URL: $applicationUrl"

if (-not $SkipGitHubVariable) {
    if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
        throw "AWS is ready, but GitHub CLI ('gh') is not installed. Set AWS_DEPLOY_ROLE_ARN to '$roleArn' in the repository variables."
    }
    gh auth status | Out-Null
    gh variable set AWS_DEPLOY_ROLE_ARN --repo $GitHubRepository --body $roleArn
    Write-Host "Set AWS_DEPLOY_ROLE_ARN in $GitHubRepository."
}
