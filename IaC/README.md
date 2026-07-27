
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

1. Make sure `rds_db_username`/`rds_db_password` are set in `terraform.tfvars`
   (must match the admin user/password already inside the restored RDS
   snapshot - Terraform can't derive these, see the comment on those
   variables in `variables.tf`).
2. `terraform apply` - provisions the VPC, EKS cluster + managed node group,
   RDS, the bastion host, the `calc-app` namespace + backend DB Secret, and
   installs the AWS Load Balancer Controller + external-dns into the cluster
   via Helm. (Looks up the ECR repos created earlier by name - it doesn't
   create them.)
3. Point kubectl at the new cluster:
   `aws eks update-kubeconfig --name $(terraform output -raw eks_cluster_name) --region us-east-1`
4. Build and push the app images (no CI/CD pipeline yet - this is a manual
   step for now; skip this step on repeat sessions if you haven't changed the
   app code since your last push - the images from last time are still there):
   ```
   aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin <account-id>.dkr.ecr.us-east-1.amazonaws.com
   docker build -t $(terraform output -raw ecr_frontend_repository_url):latest ./frontend
   docker push $(terraform output -raw ecr_frontend_repository_url):latest
   docker build -t $(terraform output -raw ecr_backend_repository_url):latest ./backend
   docker push $(terraform output -raw ecr_backend_repository_url):latest
   ```
   (Update the `image:` tags in `k8s/backend-deployment.yaml`/`frontend-deployment.yaml` if you bump the version tag.)
5. `./IaC/deploy-app.sh` - reads `DB_HOST`/`acm_certificate_arn` straight from
   Terraform's outputs, renders the `k8s/*.yaml` templates with them, and
   applies everything. This is the one command that replaces what used to be
   four manual copy-paste steps (DB host, cert ARN, DB secret, `kubectl apply`).
6. Wait for DNS to catch up, then verify: `kubectl get ingress -n calc-app` until the `ADDRESS` column populates, then check `dig www.xxsapxx.uk` (or just try `https://www.xxsapxx.uk` in a browser) - **external-dns** (installed by `terraform apply` in step 2, running in-cluster) watches that Ingress and creates/updates the Cloudflare `www`/root CNAME records automatically. No manual DNS step needed anymore.

To tear down: delete the applied resources first
(`kubectl delete -f k8s/rendered/` - that's the directory `deploy-app.sh`
actually applied; `kubectl delete -f k8s/` also works since delete only
matches on kind/name/namespace, not the templated content) - this both lets
the Load Balancer Controller clean up the ALB/target groups it created, *and*
lets external-dns remove the Cloudflare records it created (its
`policy: sync` setting means it deletes DNS records for Ingresses that no
longer exist). *Then* `terraform destroy` **from `IaC/terraform/` only** -
otherwise Terraform doesn't know about (and can't clean up) resources the
controllers created directly in AWS/Cloudflare. Do **not** run
`terraform destroy` in `IaC/terraform-ecr-repos/` unless you actually want to
delete your pushed images and start over from an empty registry.


# Network Architecture Diagram:

This architecture describes traffic flow for the domain `www.xxsapxx.uk`,
proxied through Cloudflare in **Full TLS mode**, routed to an AWS Application
Load Balancer (provisioned dynamically by the **AWS Load Balancer Controller**
running in-cluster, not by Terraform), and forwarded to Kubernetes Services
based on Ingress path rules. The Cloudflare CNAME pointing at that ALB is
kept in sync automatically by **external-dns**, also running in-cluster -
watching the same Ingress and updating Cloudflare via its API whenever the
ALB's hostname changes or the Ingress is deleted.

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

**Who actually creates/maintains each piece** (this trips people up returning to the
project after a break, since none of it is a single `terraform apply` anymore):
- **ALB + its listeners/target groups/health checks** — created by the **AWS Load
  Balancer Controller** (a pod in-cluster, installed by Terraform's `helm_release`),
  reacting to `k8s/ingress.yaml`. Not a Terraform resource - `terraform destroy`
  doesn't know about it directly, which is why `kubectl delete -f k8s/` has to
  happen *before* `terraform destroy` (see Deployment Workflow above).
- **Cloudflare `www`/root CNAME records** — created/updated/deleted by
  **external-dns** (also a pod in-cluster, also installed by Terraform's
  `helm_release`), watching that same Ingress. Same caveat: not a Terraform
  resource, needs the Ingress deleted first for cleanup to happen.
- **ACM certificate + its Cloudflare DNS-validation records** — this one *is*
  plain Terraform (`module.alb_ssl_cert_validation`), independent of the ALB's
  existence.
- **Everything else in this diagram** (VPC, EKS cluster/node group, RDS,
  bastion, IAM) — plain Terraform, in `IaC/terraform/`.

See the root `README.md` for prerequisites and `k8s/` for the application manifests.
