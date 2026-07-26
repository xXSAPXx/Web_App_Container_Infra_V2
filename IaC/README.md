
# How to set up IaC repo for this project on your own machine:
#
1) Download the Repo in a Code Editor of your choice. (Example: VSCode).
2) Download Terraform on your local machine and configure $PATH - (Check supported versions for this project in providers.tf).
3) Download AWS CLI and configure your AWS Credentials.
4) Download kubectl and Docker.
5) Create the Terraform Remote Backend (Configured in backend.tf).
6) Initialize the Terraform Configuration (`terraform init`).


# Deployment Workflow:

There are **two separate Terraform states** here, on purpose:

- **`IaC/terraform-ecr-repos/`** - the ECR repositories. Apply this **once**,
  ever. It's not part of the destroy/recreate cycle below - images pushed
  into it survive every time you tear down and rebuild the cluster stack, so
  you're not rebuilding/re-pushing images every session. ECR is storage-billed
  (and free under 500MB), not hourly, so there's no cost reason to tear it down.
- **`IaC/terraform/`** - everything else (VPC, EKS, RDS, bastion, ALB
  Controller). This is the ephemeral stack: spin it up for a session, tear it
  down afterward - the EKS control plane and NAT Gateway bill by the hour with
  no "pause" state (see cost notes in the root README), and RDS is restored
  from a snapshot on every apply anyway.

**First time only:**
```
cd IaC/terraform-ecr-repos
terraform init
terraform apply
```

**Every session** (from `IaC/terraform/`):

1. `terraform apply` - provisions the VPC, EKS cluster + managed node group,
   RDS, the bastion host, and installs the AWS Load Balancer Controller into
   the cluster via Helm. (Looks up the ECR repos created above by name - it
   doesn't create them.)
2. Point kubectl at the new cluster:
   `aws eks update-kubeconfig --name $(terraform output -raw eks_cluster_name) --region us-east-1`
3. Build and push the app images (no CI/CD pipeline yet - this is a manual
   step for now; skip this step on repeat sessions if you haven't changed the
   app code since your last push - the images from last time are still there):
   ```
   aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin <account-id>.dkr.ecr.us-east-1.amazonaws.com
   docker build -t $(terraform output -raw ecr_frontend_repository_url):latest ./frontend
   docker push $(terraform output -raw ecr_frontend_repository_url):latest
   docker build -t $(terraform output -raw ecr_backend_repository_url):latest ./backend
   docker push $(terraform output -raw ecr_backend_repository_url):latest
   ```
4. In `k8s/`, replace the `REPLACE_WITH_*` placeholders:
   - `backend-deployment.yaml` / `frontend-deployment.yaml`: the ECR image URLs from step 3.
   - `backend-configmap.yaml`: `DB_HOST` from `terraform output rds_endpoint` (strip the trailing `:3306`).
   - `ingress.yaml` (both Ingress objects): `terraform output acm_certificate_arn`.
   - Create the real DB secret (do **not** edit `backend-secret.yaml` with real values):
     `kubectl create secret generic backend-db-secret -n calc-app --from-literal=DB_USER=<user> --from-literal=DB_PASS=<password>`
5. `kubectl apply -f k8s/` - deploys the frontend/backend and creates the Ingress objects, which the AWS Load Balancer Controller turns into a real ALB.
6. `kubectl get ingress -n calc-app` - once the `ADDRESS` column populates, that's the ALB's DNS name.
7. `terraform apply -var="app_alb_dns_name=<hostname from step 6>"` - wires up the Cloudflare CNAME to point at that ALB.
8. Verify: hit the ALB hostname directly first, then `https://www.xxsapxx.uk` once DNS propagates.

To tear down: delete the `k8s/` resources first (`kubectl delete -f k8s/`) so
the Load Balancer Controller cleans up the ALB/target groups it created,
*then* `terraform destroy` **from `IaC/terraform/` only** - otherwise
Terraform doesn't know about (and can't clean up) resources the controller
created directly in AWS. Do **not** run `terraform destroy` in
`IaC/terraform-ecr-repos/` unless you actually want to delete your pushed
images and start over from an empty registry.


# Network Architecture Diagram:

This architecture describes traffic flow for the domain `www.xxsapxx.uk`,
proxied through Cloudflare in **Full TLS mode**, routed to an AWS Application
Load Balancer (provisioned dynamically by the **AWS Load Balancer Controller**
running in-cluster, not by Terraform), and forwarded to Kubernetes Services
based on Ingress path rules.

```text
                                                    ALB (HTTP:80 -> redirect HTTPS:443)
                                                    Provisioned by the AWS Load Balancer
                                                    Controller from k8s/ingress.yaml
                                                              |
                                                              V
Browser --------------> CloudFlare_Proxy --------------> ALB_DNS ------------------> ALB_HTTPS_LISTENER
`www.xxsapxx.uk`         (FULL_TLS_MODE)               (`AWS_TLS_CERT_WITH_ACM`)            |
                         (CNAME www -> ALB_DNS)                                              |
                                                                              +---------------------------+
                                                                              | Path Rule: '/calculator/  |  URL/*
                                                                              |   api/*'                  |
                                                                              V                            V
                                                              backend Service (:3000)      frontend Service (:80)
                                                              (Target Group Health Check:   (Target Group Health Check:
                                                               GET /backend)                 GET /)
                                                                      |                            |
                                                                      V                            V
                                                              backend pods (EKS)           frontend pods (EKS)
                                                              Managed Node Group, private subnets
```

See the root `README.md` for prerequisites and `k8s/` for the application manifests.
