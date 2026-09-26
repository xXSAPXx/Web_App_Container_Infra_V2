



#################################################################################################################################
######################################## CLOUDFLARE PROVIDER VARIABLES ##########################################################

provider "cloudflare" {
  api_token = var.cloudflare_api_token
}



# Cloudflare zone-level config that's independent of the ALB's existence
# (Page Rule + Always-Use-HTTPS). The actual www/root -> ALB CNAME records
# are owned by external-dns now (see helm_release.external_dns below) -
# it's the only thing that reliably knows the ALB's current DNS name.
# [SSL cert validation is handled separately in module alb_ssl_cert_validation]
module "cloudflare_dns" {
  source = "./modules/cloudflare"

  # --- Cloudflare Variables for the Module ---
  cloudflare_api_token = var.cloudflare_api_token
  cloudflare_zone_id   = var.cloudflare_zone_id
  select_domain_name   = var.cloudflare_domain_name

  # --- Cloudflare Page Rule to Redirect from ROOT to WWW-Sub_Domain ---
  rule_target          = "xxsapxx.uk/*" # (Catches requests to: http://xxsapxx.uk, https://xxsapxx.uk, xxsapxx.uk/path, etc.)
  rule_priority        = 1
  rule_status          = "active"
  rule_redirect_to_url = "https://www.xxsapxx.uk"
  rule_status_code     = 301


  # --- Use a redirect rule to enforce https:// (not just http → https at ALB level) -- Cloudflare: (Always Use HTTPS) ---
  setting_id             = "always_use_https"
  always_use_https_value = "on"


  # Enable HSTS (Strict-Transport-Security) in Cloudflare: (NOT AVAILABLE IN TERRAFORM)


  # Use Rate Limiting Rules for DDoS Protection:
}




####################################################################################################################################
######################################## AWS PROVIDER VARIABLES ####################################################################

# AWS provider region:
provider "aws" {
  region = "us-east-1" # Or use a variable if you prefer

  # Applied to every taggable resource in this stack, modules included.
  # Resource-level tags win on key collisions, so resources belonging to a
  # different Service (calc-app, access, observability) override just that
  # key. Doesn't reach anything AWS/controllers create on their own (the
  # ALB, PVC-backed EBS volumes, EKS worker instances) - those get
  # local.common_tags through their own config instead.
  default_tags {
    tags = merge(local.common_tags, {
      Service   = "platform"
      ManagedBy = "terraform"
    })
  }
}

locals {
  # Shared cluster name - passed to both the VPC module (subnet discovery
  # tags) and the EKS module (the cluster itself), so they can't drift apart.
  eks_cluster_name = "app-eks-cluster"

  # Tags every AWS resource in this stack carries, whoever creates it -
  # Terraform (default_tags above), the ALB controller (defaultTags) or the
  # EBS CSI driver (extraVolumeTags). Service and ManagedBy are left to each
  # consumer: ManagedBy names whatever actually owns the resource, so it
  # points at the right place to change it.
  common_tags = {
    Environment = var.environment
    Owner       = var.owner
    Repo        = var.repository
  }
}


# Networking:
# Crate VPC / Subnets / Nat_Gateway / RDS_Subnet_Group /Routing / Route53_Private_Zone
######################################################################################

module "vpc" {
  source = "./modules/vpc"

  # --- General VPC Settings ---
  vpc_name              = "App_VPC_IaC"
  vpc_cidr_block        = "10.0.0.0/16"
  internet_gateway_name = "Internet_Gateway_IaC"

  # --- Availability Zone Settings ---
  availability_zone_1 = "us-east-1a"
  availability_zone_2 = "us-east-1b"

  # --- Subnet CIDR Block Settings ---
  public_subnet_1_cidr  = "10.0.0.0/20"
  public_subnet_2_cidr  = "10.0.16.0/20"
  private_subnet_1_cidr = "10.0.32.0/19"
  private_subnet_2_cidr = "10.0.64.0/19"

  # --- NAT_Gateway Settings ---
  nat_gateway_public_subnet_id = 1

  # --- RDS Subnet Group Settings ---
  rds_subnet_group_name = "App_DB_Subnet_Group_IaC"

  # --- Route 53 Settings ---
  private_zone_name = "internal.xxsapxx.local"

  # --- EKS Subnet Discovery Tag Settings ---
  eks_cluster_name = local.eks_cluster_name
}




# Create ALL Security Groups:
######################################################################################

module "security_groups" {
  source = "./modules/security_groups"

  # For all SGs:
  vpc_id = module.vpc.vpc_id

  # -------- RDS Sec_Group Settings --------
  rds_cidr_block          = "10.0.0.0/16" # RDS stays reachable from anywhere in the VPC (incl. the bastion) for DB testing.
  rds_security_group_name = "RDS_SG_IaC"

  # --- Bastion Sec_Group Settings ---
  bastion_host_cidr_block = var.my_ip_cidr
  sec_group_name          = "bastion_sg"
  sec_group_description   = "Allow SSH access for the bastion jump host"
  vpc_cidr_block          = module.vpc.vpc_cidr_block # Used for ICMP (Ping) from inside the VPC.

  # --- ALB Sec_Group Settings ---
  alb_sec_group_cidr_block = "0.0.0.0/0" # Public ALB Allows HTTP / HTTPS
  alb_security_group_name  = "alb_security_group"

  # --- EKS Node Sec_Group Settings ---
  asg_sec_group_cidr_block = "10.0.0.0/16"
  asg_security_group_name  = "eks_node_sg"
}




# RDS Configuration and Creation:
######################################################################################

module "database" {
  source = "./modules/database"

  # -------- RDS Configuration Settings --------

  rds_engine            = "mysql"
  rds_engine_version    = "8.0.35" # Matches the snapshot's own native version (verify with `aws rds describe-db-snapshots` if the snapshot is ever replaced) - restoring at a different version silently triggers an in-place upgrade on every apply. Only bump this if you deliberately want to upgrade the restored instance, and only right after a full destroy so there's no live instance to conflict with (RDS can't downgrade via ModifyDBInstance).
  rds_instance_class    = "db.t3.micro"
  rds_allocated_storage = 20
  rds_storage_encrypted = true

  #db_name             = "calc_app_rds_iac"    # No need since we restore from snapshot.
  #username            = "admin"               # No need since we restore from snapshot.
  #password            = "12345678"            # No need since we restore from snapshot.

  rds_port                = "3306"
  rds_publicly_accessible = false

  rds_security_group_ids = [module.security_groups.rds_security_group_id]
  rds_subnet_group_name  = module.vpc.rds_subnet_group_name

  rds_snapshot_identifier = "calculator-app-rds-final-snapshot-iac" # Replace with your snapshot ID from which you want the DB to be created
  maintenance_window      = "mon:19:00-mon:19:30"

  # Prevent deletion of the database
  skip_final_snapshot           = true
  rds_final_snapshot_identifier = "calculator-app-rds-final-snapshot-iac2"

  # --- Terraform-managed static DNS record for RDS (see the note in
  # modules/database/main.tf) ---
  private_dns_zone_id   = module.vpc.private_dns_zone_id
  private_dns_zone_name = module.vpc.private_dns_zone_name
}




# Create an EC2: (Bastion jump host - SSH + DB connectivity testing)
######################################################################################
module "bastion_prometheus" {
  source = "./modules/bastion_prometheus_host"

  # --- Terraform-managed static DNS record for the bastion (see the note in
  # modules/bastion_prometheus_host/main.tf) ---
  private_dns_zone_id   = module.vpc.private_dns_zone_id
  private_dns_zone_name = module.vpc.private_dns_zone_name

  # --- Bastion Host Settings ---
  ami_id                = "ami-0583d8c7a9c35822c"
  instance_type         = "t2.micro"
  subnet_id             = module.vpc.public_subnet_2_id
  bastion_sec_group_ids = [module.security_groups.bastion_host_security_group_id]
  key_name              = var.aws_key_pair

  # EBS Volume Settings:
  volume_size = 10
  volume_type = "gp2"

  bastion_host_tag_name = "bastion-host"

  # --- Tailscale VPN Settings ---
  tailscale_authkey = var.tailscale_authkey
}




# Create Amazon-issued TLS certificate for our domain: [Specifies DNS validation.] AND VALIDATE CERT!
########################################################################################################

module "alb_ssl_cert_validation" {
  source             = "./modules/alb_ssl_cert_validation"
  domain_name        = "xxsapxx.uk"
  san                = ["www.xxsapxx.uk"]
  cloudflare_zone_id = var.cloudflare_zone_id
  validation_method  = "DNS"
}




# ECR Repositories for the frontend/backend app images:
# These are NOT created here - they live in their own persistent state
# (IaC/terraform-ecr/), applied once, so images survive every destroy/apply
# cycle of this stack. This just looks up the existing repos by name.
########################################################################################################

data "aws_ecr_repository" "frontend" {
  name = "calc-app-frontend"
}

data "aws_ecr_repository" "backend" {
  name = "calc-app-backend"
}




# EKS Cluster (control plane, managed node group, OIDC/IRSA, ALB Controller IAM):
########################################################################################################

module "eks" {
  source     = "./modules/eks"
  depends_on = [module.vpc, module.security_groups]

  cluster_name       = local.eks_cluster_name
  vpc_id             = module.vpc.vpc_id
  public_subnet_ids  = module.vpc.public_subnet_ids
  private_subnet_ids = module.vpc.private_subnet_ids

  eks_node_security_group_id = module.security_groups.eks_node_security_group_id
  my_ip_cidr                 = var.my_ip_cidr

  # Tags the EBS CSI driver puts on every PVC-backed volume it creates.
  # No Service: that comes from the StorageClass the PVC uses
  # (tagSpecification), since one driver serves every app's volumes.
  ebs_csi_volume_tags = merge(local.common_tags, {
    ManagedBy = "ebs-csi-driver"
  })
}


# Install the AWS Load Balancer Controller via Helm - this is the piece that
# watches k8s/ingress.yaml and provisions the actual ALB in AWS.
# Pin/verify chart `version` against the latest release before applying:
# https://github.com/aws/eks-charts/releases
resource "helm_release" "aws_load_balancer_controller" {
  name       = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  namespace  = "kube-system"
  version    = "1.8.1"

  set {
    name  = "clusterName"
    value = module.eks.cluster_name
  }

  set {
    name  = "region"
    value = "us-east-1"
  }

  set {
    name  = "vpcId"
    value = module.vpc.vpc_id
  }

  set {
    name  = "serviceAccount.create"
    value = "true"
  }

  set {
    name  = "serviceAccount.name"
    value = "aws-load-balancer-controller"
  }

  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = module.eks.alb_controller_irsa_role_arn
  }

  # Tags on everything the controller creates (ALB, target groups, its
  # security groups). No Service here on purpose: the controller's
  # defaultTags take priority over Ingress annotation tags, so a Service
  # set here would force every ALB into one. Service is set per
  # IngressGroup instead, via alb.ingress.kubernetes.io/tags in
  # k8s/ingress.yaml.
  dynamic "set" {
    for_each = merge(local.common_tags, {
      ManagedBy = "aws-load-balancer-controller"
    })
    content {
      name  = "defaultTags.${set.key}"
      value = set.value
    }
  }

  depends_on = [module.eks]
}


# Cloudflare API token, made available in-cluster for external-dns.
# Reuses the same token Terraform itself uses (already scoped to DNS-edit
# per the README's setup instructions) rather than requiring a second one.
resource "kubernetes_secret" "cloudflare_api_token" {
  metadata {
    name      = "cloudflare-api-token"
    namespace = "kube-system"
  }

  data = {
    cloudflare_api_token = var.cloudflare_api_token
  }

  type = "Opaque"

  depends_on = [module.eks]
}


# external-dns - watches Ingress resources in-cluster and syncs matching
# Cloudflare DNS records automatically, closing the loop that used to need
# a manual `terraform apply -var="app_alb_dns_name=..."` after every
# `kubectl apply -f k8s/`. policy=sync means it also DELETES the Cloudflare
# record when the Ingress is deleted (e.g. during teardown) - matches the
# spin-up/tear-down-per-session workflow this stack is built around.
# Verify chart values against the current schema before applying:
# https://github.com/kubernetes-sigs/external-dns/blob/master/charts/external-dns/values.yaml
resource "helm_release" "external_dns" {
  name       = "external-dns"
  repository = "https://kubernetes-sigs.github.io/external-dns/"
  chart      = "external-dns"
  namespace  = "kube-system"
  version    = "1.15.0"

  set {
    name  = "provider.name"
    value = "cloudflare"
  }

  set {
    name  = "env[0].name"
    value = "CF_API_TOKEN"
  }

  set {
    name  = "env[0].valueFrom.secretKeyRef.name"
    value = kubernetes_secret.cloudflare_api_token.metadata[0].name
  }

  set {
    name  = "env[0].valueFrom.secretKeyRef.key"
    value = "cloudflare_api_token"
  }

  set {
    name  = "policy"
    value = "sync"
  }

  set {
    name  = "sources[0]"
    value = "ingress"
  }

  set {
    name  = "domainFilters[0]"
    value = var.cloudflare_domain_name
  }

  set {
    name  = "txtOwnerId"
    value = local.eks_cluster_name
  }

  depends_on = [kubernetes_secret.cloudflare_api_token, helm_release.aws_load_balancer_controller]
}


# Deletes k8s/ (specifically the Ingress) at destroy time, while BOTH
# controllers below are still alive to react to it. This has to live on its
# own null_resource rather than a provisioner on either helm_release directly:
# external_dns depends_on aws_load_balancer_controller, so Terraform destroys
# external_dns FIRST (dependents are destroyed before what they depend on) -
# by the time a provisioner on aws_load_balancer_controller fired, external-dns
# was already gone and never saw the Ingress deletion, so it never synced the
# deletion to Cloudflare (confirmed live: CNAME + 2 TXT ownership records were
# left dangling after a clean destroy that DID correctly deprovision the ALB
# itself, since the ALB controller was still alive for that one).
# Depending on both helm releases here makes this null_resource a dependent of
# both, so it's destroyed before either of them - guaranteeing the Ingress
# delete fires while both controllers are still up. The sleep afterward gives
# external-dns's reconcile loop (default --interval=1m, no --events flag set)
# a real chance to run before its own pod gets torn down next.
resource "null_resource" "destroy_k8s_manifests" {
  depends_on = [helm_release.aws_load_balancer_controller, helm_release.external_dns]

  provisioner "local-exec" {
    when    = destroy
    command = "kubectl delete -f ${path.module}/../../k8s/ --ignore-not-found --wait --timeout=120s || true"
  }

  provisioner "local-exec" {
    when    = destroy
    command = "sleep 75"
  }
}


# The calc-app namespace is created here (not in k8s/00-namespace.yaml) so
# the backend DB secret below can live in it - Terraform has to create the
# namespace before it can create anything inside it, and this secret's
# credentials aren't something kubectl/k8s manifests can know.
# k8s/ manifests still assume this namespace already exists by the time
# `kubectl apply -f k8s/` runs (i.e. always apply Terraform first).
resource "kubernetes_namespace" "calc_app" {
  metadata {
    name = "calc-app"
  }

  depends_on = [module.eks]
}


# Backend DB Secret - replaces the manual
# `kubectl create secret generic backend-db-secret ...` step.
# JWT signing secret - purely internal to the backend, nothing external it
# needs to match (unlike the DB credentials below), so Terraform generates
# and owns it rather than asking for it in terraform.tfvars. One shared
# value across all backend replicas is required, not just convenient - it's
# what lets a token signed by one pod be verified by any other pod behind
# the same Service.
resource "random_password" "jwt_secret" {
  length  = 48
  special = false
}

resource "kubernetes_secret" "backend_db" {
  metadata {
    name      = "backend-secrets"
    namespace = kubernetes_namespace.calc_app.metadata[0].name
  }

  data = {
    DB_USER    = var.rds_db_username
    DB_PASS    = var.rds_db_password
    JWT_SECRET = random_password.jwt_secret.result
  }

  type = "Opaque"
}


# Dedicated namespace for observability tooling (kube-prometheus-stack etc.)
# so it gets its own resource budget instead of sharing calc-app's or
# landing unbounded in default. kubectl describe nodes currently shows
# ~1.6 vCPU / ~1.8Gi free across both t3.small nodes after calc-app + the
# platform pods (aws-node, coredns, kube-proxy, ebs-csi, ALB controller,
# external-dns) - these numbers stay comfortably under that with room to
# spare for calc-app to grow. Bump them here if a real install needs more.
resource "kubernetes_namespace" "monitoring" {
  metadata {
    name = "monitoring"
  }

  depends_on = [module.eks]
}

# Belt-and-suspenders for the "resources: {}" problem found in
# kube-prometheus-stack's default values.yaml (most of its containers
# declare no requests/limits at all, so they'd otherwise be free to consume
# as much of a node's real CPU/memory as exists). Any container landing in
# this namespace without its own resources block gets these defaults
# auto-injected by the API server - a bad `helm install` can no longer go
# unbounded by accident.
#
# "request" = what a container is guaranteed to get, and what the scheduler
# uses to decide which node has room for it.
# "limit" = the hard ceiling a container can never exceed at runtime - go
# over the memory limit and the container gets OOM-killed; go over the CPU
# limit and it just gets throttled, not killed.
resource "kubernetes_limit_range" "monitoring" {
  metadata {
    name      = "monitoring-default-limits"
    namespace = kubernetes_namespace.monitoring.metadata[0].name
  }

  spec {
    limit {
      type = "Container"

      # Applied automatically to any container that doesn't set its own
      # resources.limits - this is what neutralizes kube-prometheus-stack's
      # bare "resources: {}" default.
      default = {
        cpu    = "500m"  # 0.5 vCPU ceiling
        memory = "512Mi" # hard cap - OOM-killed if exceeded
      }

      # Applied automatically to any container that doesn't set its own
      # resources.requests - this is what the scheduler reserves for it up
      # front when deciding which node to place it on.
      default_request = {
        cpu    = "100m"  # 0.1 vCPU reserved
        memory = "128Mi" # reserved, not a hard cap by itself
      }

      # Even a container that DOES set its own resources can't ask for more
      # than this, no matter what its own values.yaml says.
      max = {
        cpu    = "1"
        memory = "1Gi"
      }

      # ...or less than this - stops something being configured so small
      # it gets starved/killed constantly.
      min = {
        cpu    = "10m"
        memory = "16Mi"
      }
    }
  }
}

# Namespace-wide hard ceiling - unlike the LimitRange above (which only sets
# per-container defaults/bounds), this caps the *sum* across every object in
# the namespace. Once hit, the API server rejects new pods/PVCs outright
# instead of letting them schedule and starve calc-app or the platform pods.
resource "kubernetes_resource_quota" "monitoring" {
  metadata {
    name      = "monitoring-quota"
    namespace = kubernetes_namespace.monitoring.metadata[0].name
  }

  spec {
    hard = {
      # Sum of every container's CPU/memory *request* in this namespace
      # can't exceed these - blocks new pods once the reserved total is hit.
      "requests.cpu"    = "1500m" # 1.5 vCPU total reserved across all pods here
      "requests.memory" = "2Gi"   # 2Gi total reserved across all pods here

      # Sum of every container's CPU/memory *limit* can't exceed these -
      # the absolute ceiling this namespace could ever consume at runtime.
      "limits.cpu"    = "8"   # 8 vCPU max even if everything spikes at once
      "limits.memory" = "8Gi" # 8Gi max even if everything spikes at once

      # Total size of all PersistentVolumeClaims (EBS volumes) combined.
      "requests.storage" = "15Gi"

      # Simple headcounts - cheap guardrails against a chart or a typo'd
      # replica count spinning up way more objects than intended.
      "persistentvolumeclaims" = "5"  # max number of PVCs/EBS volumes
      "pods"                   = "20" # max number of pods
    }
  }
}


# One general-purpose StorageClass for the whole cluster - gp3 is AWS's
# cheapest current-generation SSD tier (successor to gp2, actually cheaper
# per-GB and better baseline performance). Left iops/throughput unset on
# purpose - that keeps it on gp3's free baseline (3000 IOPS / 125 MB/s
# regardless of size), plenty for Prometheus/Alertmanager/Grafana at this
# scale, and the actual "cheap" part - setting either would raise the bill.
resource "kubernetes_storage_class" "ebs_gp3" {
  metadata {
    name = "ebs-gp3"

    # No default StorageClass exists on EKS out of the box (unlike GKE,
    # which auto-provisions one). Marking this default means any PVC that
    # doesn't set storageClassName just uses this one automatically.
    annotations = {
      "storageclass.kubernetes.io/is-default-class" = "true"
    }
  }

  storage_provisioner = "ebs.csi.aws.com"
  reclaim_policy      = "Delete" # EBS volume dies with the PVC - matches
  # the destroy-per-session workflow; "Retain"
  # would leave real, billed EBS volumes
  # orphaned after every terraform destroy
  volume_binding_mode = "WaitForFirstConsumer" # delays volume creation
  # until a pod is actually scheduled, so
  # the volume lands in the SAME AZ as the
  # pod - see modules/eks's AZ-locking notes
  allow_volume_expansion = false

  parameters = {
    type      = "gp3"
    encrypted = "true"
  }

  depends_on = [module.eks] # needs the ebs_csi addon (modules/eks/addons.tf)
}


# Same as ebs-gp3 above, but tags every volume it creates
# Service=observability - for the monitoring stack's PVCs (Prometheus,
# Alertmanager, Grafana), so their storage shows up under observability in
# Cost Explorer. A separate class because Service can only be set per
# StorageClass (the driver's extraVolumeTags is one fixed set for every
# volume), and ebs-gp3 is the cluster-wide default. The common tags
# (Environment/Owner/Repo/ManagedBy) come from extraVolumeTags.
resource "kubernetes_storage_class" "ebs_gp3_observability" {
  metadata {
    name = "ebs-gp3-observability"
  }

  storage_provisioner    = "ebs.csi.aws.com"
  reclaim_policy         = "Delete"               # same reasoning as ebs-gp3
  volume_binding_mode    = "WaitForFirstConsumer" # same reasoning as ebs-gp3
  allow_volume_expansion = false

  parameters = {
    type               = "gp3"
    encrypted          = "true"
    tagSpecification_1 = "Service=observability"
  }

  depends_on = [module.eks] # needs the ebs_csi addon (modules/eks/addons.tf)
}


# Grafana admin credentials - Terraform-generated and Terraform-owned,
# replacing the chart's own default behavior (a fresh random password
# generated on every install, thrown away with nothing to retrieve it from
# except `kubectl get secret`). Same reasoning as random_password.jwt_secret
# above. Referenced via grafana.admin.existingSecret in
# values/kube-prometheus-stack.yaml.
resource "random_password" "grafana_admin_password" {
  length  = 24
  special = false
}

# Tailscale Kubernetes Operator - lets Grafana (see grafana.ingress in
# values/kube-prometheus-stack.yaml) be exposed directly onto the tailnet
# via a `tailscale`-class Ingress, with a free MagicDNS hostname and a real
# auto-provisioned HTTPS cert. No AWS networking at all - the operator makes
# an outbound-only connection to Tailscale's control plane per proxy it
# creates, same pattern as the bastion's subnet router in
# modules/bastion_prometheus_host. Deliberately chosen over building a
# second internal ALB + a second external-dns + a new IRSA role for the
# private Route53 zone - see the bastion module README for the full
# comparison and mechanism notes.
resource "helm_release" "tailscale_operator" {
  name             = "tailscale-operator"
  repository       = "https://pkgs.tailscale.com/helmcharts"
  chart            = "tailscale-operator"
  namespace        = "tailscale"
  create_namespace = true
  version          = "1.102.3"

  # set_sensitive (not set) - these are real OAuth credentials, not just
  # references to something else (unlike every other helm_release in this
  # file, which only ever passes ARNs/resource names through `set`).
  set_sensitive {
    name  = "oauth.clientId"
    value = var.tailscale_oauth_client_id
  }

  set_sensitive {
    name  = "oauth.clientSecret"
    value = var.tailscale_oauth_client_secret
  }

  depends_on = [module.eks]
}


resource "kubernetes_secret" "grafana_admin" {
  metadata {
    name      = "grafana-admin-credentials"
    namespace = kubernetes_namespace.monitoring.metadata[0].name
  }

  data = {
    admin-user     = "admin"
    admin-password = random_password.grafana_admin_password.result
  }

  type = "Opaque"
}


# kube-prometheus-stack - Prometheus + Alertmanager + Grafana + node-exporter +
# kube-state-metrics + the Prometheus Operator, replacing the manual
# `helm install` used earlier to explore it. Version pinned to the one
# already validated by hand against this namespace's quota.
#
# Values live in their own file rather than inline `set` blocks - this
# chart's config surface (thousands of lines in its own values.yaml) makes
# `set` impractical the way it's used for aws_load_balancer_controller/
# external_dns above.
resource "helm_release" "kube_prometheus_stack" {
  name       = "my-kube-prometheus-stack"
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "kube-prometheus-stack"
  namespace  = kubernetes_namespace.monitoring.metadata[0].name
  version    = "88.2.0"

  values = [
    file("${path.module}/values/kube-prometheus-stack.yaml")
  ]

  # Terraform-computed value (an ARN), so it goes through `set` rather than
  # the static values file - same reasoning as aws_load_balancer_controller's
  # serviceAccount annotation above. Grants ec2_sd_configs (see the values
  # file) permission to actually call ec2:DescribeInstances.
  set {
    name  = "prometheus.serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = module.eks.prometheus_irsa_role_arn
  }

  # LimitRange/ResourceQuota must exist before any of this chart's pods do -
  # both apply at admission time, not retroactively. The StorageClass must
  # exist before any PVC referencing it by name (once values.yaml turns on
  # persistence) can bind.
  depends_on = [
    kubernetes_namespace.monitoring,
    kubernetes_limit_range.monitoring,
    kubernetes_resource_quota.monitoring,
    kubernetes_storage_class.ebs_gp3,
    kubernetes_secret.grafana_admin,
    helm_release.tailscale_operator,
  ]
}


# Print all dynamic variables passed to specified modules after terrafrom deployment:
# Usefull for debuging purposes.
########################################################################################################

output "bastion_host_public_ip" {
  value = module.bastion_prometheus.bastion_host_public_ip
}

output "bastion_private_dns_name" {
  value = module.bastion_prometheus.bastion_private_dns_name
}

output "rds_endpoint" {
  value = module.database.rds_endpoint
}

output "rds_private_dns_name" {
  value = module.database.rds_private_dns_name
}

output "eks_cluster_name" {
  value = module.eks.cluster_name
}

output "eks_cluster_endpoint" {
  value = module.eks.cluster_endpoint
}

output "ecr_frontend_repository_url" {
  value = data.aws_ecr_repository.frontend.repository_url
}

output "ecr_backend_repository_url" {
  value = data.aws_ecr_repository.backend.repository_url
}

output "acm_certificate_arn" {
  description = "Pass this into the alb.ingress.kubernetes.io/certificate-arn annotation on k8s/ingress.yaml"
  value       = module.alb_ssl_cert_validation.alb_certificate_arn
}

output "grafana_admin_password" {
  description = "Grafana admin login - retrieve with: terraform output -raw grafana_admin_password"
  value       = random_password.grafana_admin_password.result
  sensitive   = true
}

