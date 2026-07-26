
# Project Architecture Overview:

# Infrastructure Deployment Requirements:

This project provisions cloud infrastructure using **Terraform**, integrating **AWS (EKS)** and **Cloudflare**.

Compute moved from a planned EC2/ASG design to **AWS EKS** - see `IaC/README.md` for the full architecture and deployment workflow.

---

## 📋 Requirements

Before deploying this infrastructure, ensure the following prerequisites are met:

### 🔧 Software

- **Terraform** `>= 1.10.0`
  _Used for infrastructure as code (IaC) provisioning - VPC, EKS cluster, ECR, RDS, IAM. Also installs two in-cluster controllers via its `helm` provider: the AWS Load Balancer Controller (creates the ALB from `k8s/ingress.yaml`) and **external-dns** (keeps the Cloudflare `www`/root DNS records in sync with that ALB automatically - no manual DNS step)._

- **AWS CLI**
  _Used for authenticating to EKS (`aws eks get-token`), pushing images to ECR, and manual verification._

- **kubectl**
  _Used to apply the application manifests in `k8s/` and inspect the cluster once it's up._

- **Docker**
  _Used to build the `frontend`/`backend` images and push them to ECR (see `IaC/README.md` for the exact commands)._

- **Helm** (optional, for troubleshooting)
  _Terraform installs the AWS Load Balancer Controller chart automatically via the `helm` provider - the CLI is only needed if you want to inspect/debug that release by hand._

---

### 🌐 Accounts & Services

- **AWS Account Must have:**
    - S3 (for Terraform backend) -- [Check `backend.tf`]
    - **Key Pair** must exist or be created for SSH access to the bastion host.

- **Cloudflare Account With:**
    - API Token with DNS edit permissions
    - Zone ID of your domain

- **Own Domain Name**
    - Managed in Cloudflare — used for DNS records and HTTPS via the AWS ALB provisioned by the AWS Load Balancer Controller.

---

### 🔐 Required Terraform Variables

- **Check `terraform.tfvars.example` file and rename it to e.g. `terraform.tfvars.tf`**
    - Fill in the required variables:

```hcl
# Cloudflare (cloudflare_api_token, cloudflare_zone_id, cloudflare_domain_name)
# AWS EC2 Key Pair (aws_key_pair, for the bastion host)
```

Note: there used to be an `app_alb_dns_name` variable for manually wiring up
Cloudflare DNS after the ALB existed - that's gone now, replaced by
external-dns automating it in-cluster (see `IaC/README.md`).
