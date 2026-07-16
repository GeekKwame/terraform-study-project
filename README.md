# Terraform Study Project

A hands-on Terraform learning project that provisions AWS infrastructure using a secure, keyless CI/CD pipeline via GitHub Actions and OIDC.

---

## Architecture Overview

```
GitHub Actions (CI/CD)
       │
       │  OIDC (no long-lived keys)
       ▼
AWS IAM Role (github-actions-terraform-role)
       │
       ├── S3 Bucket (Remote State)
       ├── DynamoDB Table (State Locking)
       └── Phase 1 Infrastructure
              ├── VPC (10.0.0.0/16)
              ├── Public Subnet (10.0.1.0/24)
              ├── Internet Gateway
              ├── Route Table
              ├── Security Group (SSH restricted, HTTP open)
              └── EC2 Instance (Amazon Linux 2023, t3.micro)
```

---

## Project Structure

```
terraform-study-project/
├── .github/
│   └── workflows/
│       └── terraform.yml       # CI/CD pipeline
├── phase1-vpc-ec2/
│   ├── provider.tf             # AWS provider + S3 remote backend
│   ├── vpc.tf                  # VPC, subnet, IGW, route table
│   ├── ec2.tf                  # Security group, key pair, EC2 instance
│   ├── oidc.tf                 # GitHub Actions OIDC provider + IAM role/policy
│   ├── outputs.tf              # Instance IP, ID, SSH command, etc.
│   └── terraform.tfvars        # Local variable values (gitignored)
├── .gitignore
└── README.md
```

---

## Phase 1 — VPC + EC2

### Resources Provisioned

| Resource | Name | Details |
|---|---|---|
| VPC | `study-vpc` | CIDR `10.0.0.0/16`, DNS enabled |
| Public Subnet | `study-public-subnet` | CIDR `10.0.1.0/24`, us-east-1a |
| Internet Gateway | `study-igw` | Attached to VPC |
| Route Table | `study-public-rt` | Routes `0.0.0.0/0` to IGW |
| Security Group | `study-web-sg` | SSH from your IP only; HTTP from anywhere |
| Key Pair | `study-key` | ED25519 key for SSH access |
| EC2 Instance | `study-ec2` | Amazon Linux 2023, `t3.micro` |
| OIDC Provider | GitHub Actions | `token.actions.githubusercontent.com` |
| IAM Role | `github-actions-terraform-role` | Assumed by GitHub Actions via OIDC |

### Outputs

After `terraform apply`, the following are printed:

| Output | Description |
|---|---|
| `instance_public_ip` | Public IP of the EC2 instance |
| `instance_id` | EC2 instance ID |
| `vpc_id` | VPC ID |
| `public_subnet_id` | Public subnet ID |
| `ssh_command` | Ready-to-run SSH command |
| `github_actions_role_arn` | ARN of the GitHub Actions IAM role |

---

## Remote State Backend

Terraform state is stored remotely to enable team collaboration and safe CI/CD runs.

| Config | Value |
|---|---|
| S3 Bucket | `jemimah-eddie-s3-164824552172-us-east-1-an` |
| State Key | `phase1/terraform.tfstate` |
| Region | `us-east-1` |

---

## CI/CD Pipeline (GitHub Actions + OIDC)

The pipeline in `.github/workflows/terraform.yml` runs on every push or pull request to `main` that touches the `phase1-vpc-ec2/` directory.

### How OIDC Works (No Long-Lived Keys)

Instead of storing AWS access keys as secrets, GitHub Actions requests a short-lived OIDC token and exchanges it for temporary AWS credentials by assuming the `github-actions-terraform-role` IAM role. This is more secure because:
- No static credentials stored anywhere
- Credentials expire automatically after the job
- Trust is scoped to a specific repo and branch

### Workflow Jobs

| Job | Trigger | Steps |
|---|---|---|
| `plan` | Pull Request to `main` | fmt check → init → validate → plan → post plan as PR comment |
| `apply` | Push to `main` | init → apply |

---

## Prerequisites & Setup

### 1. Generate an SSH Key Pair

```bash
ssh-keygen -t ed25519 -f phase1-vpc-ec2/study-key -N ""
```

### 2. Create `terraform.tfvars` (local only — gitignored)

```hcl
my_ip      = "YOUR.PUBLIC.IP.ADDRESS/32"   # curl ifconfig.me → append /32
public_key = "ssh-ed25519 AAAA... user@host"
```

Get your current IP (PowerShell):
```powershell
(Invoke-WebRequest -Uri "https://ifconfig.me/ip").Content.Trim() + "/32"
```

Get your public key:
```powershell
Get-Content "phase1-vpc-ec2/study-key.pub"
```

### 3. Set GitHub Actions Secrets

Go to **Settings → Secrets and variables → Actions** in your GitHub repo and add:

| Secret | Value |
|---|---|
| `AWS_ROLE_ARN` | `arn:aws:iam::164824552172:role/github-actions-terraform-role` |
| `MY_IP` | Your public IP in CIDR form, e.g. `203.0.113.4/32` |
| `PUBLIC_KEY` | Full contents of `study-key.pub` |

### 4. Deploy Locally

```bash
cd phase1-vpc-ec2
terraform init
terraform plan
terraform apply
```

### 5. SSH into the Instance

```bash
ssh -i phase1-vpc-ec2/study-key ec2-user@<instance_public_ip>
```

---

## Teardown

```bash
cd phase1-vpc-ec2
terraform destroy
```

> **Warning:** This will permanently destroy all resources in Phase 1 including the EC2 instance, VPC, and key pair.

---

## Troubleshooting

### `Not authorized to perform sts:AssumeRoleWithWebIdentity`
The OIDC subject claim in the IAM trust policy did not match what GitHub sent. This can happen when GitHub uses its new immutable subject format (`repo:owner@id/repo@id`). The trust policy uses `StringLike` with wildcards to handle both formats.

### `"" is not a valid CIDR block`
The `MY_IP` GitHub secret is empty. Update it with your public IP in CIDR notation (e.g. `154.161.7.227/32`).

### `aws_key_pair must be replaced`
The `PUBLIC_KEY` GitHub secret is empty. Paste the full contents of `study-key.pub` into the secret.

### `iam:GetOpenIDConnectProvider` AccessDenied
The IAM role policy was missing this permission. It has been added to `oidc.tf` under the `terraform_permissions` policy.

### `MY_IP` secret becomes stale
Your public IP changes when you restart your router or switch networks. Re-run the IP command and update the `MY_IP` GitHub secret whenever SSH access breaks.

---

## Tech Stack

- **Terraform** >= 1.5.0
- **AWS Provider** ~> 5.0
- **GitHub Actions** with OIDC (no static credentials)
- **Amazon Linux 2023** on `t3.micro`
- **S3** remote backend with state locking