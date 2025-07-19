
# Project Architecture Overview:

# Infrastructure Deployment Requirements: 

This project provisions cloud infrastructure using **Terraform**, integrating **AWS**, **Cloudflare**, and **Grafana Cloud**

---

## 📋 Requirements

Before deploying this infrastructure, ensure the following prerequisites are met:

### 🔧 Software

- **Terraform** `>= 1.10.0`  
  _Used for infrastructure as code (IaC) provisioning._

- **AWS CLI**  
  _Used for checking resources, managing credentials, and manual verification (e.g., EC2 status, logs)._

- **Docker**
  _TO BE ADDED !!!!_
  
---

### 🌐 Accounts & Services

- **AWS Account Must have:**
    - S3 (for Terraform backend) -- [Check `backend.tf`]
    - **Key Pair** must exist or be created for SSH access.

- **Cloudflare Account With:**
    - API Token with DNS edit permissions
    - Zone ID of your domain

- **Own Domain Name**
    - Managed in Cloudflare — used for DNS records and HTTPS via AWS ALB.

- **Grafana Cloud Account With **Prometheus Remote Write** credentials and datasource:**
    - `prometheus_grafana_user`
    - `prometheus_grafana_api_key`

---

### 🔐 Required Terraform Variables

- **Check `terraform.tfvars.example` file and rename it to e.g. `terraform.tfvars.tf`**
    - Fill in the required variables: 

```hcl
# Cloudflare
# AWS EC2 Key Pair
# Grafana Cloud (Prometheus Remote Write)

