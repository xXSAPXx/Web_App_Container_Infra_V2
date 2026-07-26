



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
}

data "aws_caller_identity" "current" {}

# Shared cluster name - passed to both the VPC module (subnet discovery tags)
# and the EKS module (the cluster itself), so they can't drift apart.
locals {
  eks_cluster_name = "app-eks-cluster"
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
  bastion_host_cidr_block = "0.0.0.0/0"
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




# Create All IAM Policies / Roles and IAM Instance Profiles:
######################################################################################

module "iam" {
  source = "./modules/iam"

  # --- IAM Policy Route53 Zone ID ---
  private_dns_zone_id = module.vpc.private_dns_zone_id

}




# RDS Configuration and Creation:
######################################################################################

module "database" {
  source = "./modules/database"

  # -------- RDS Configuration Settings --------

  rds_engine            = "mysql"
  rds_engine_version    = "8.0.35"
  rds_instance_class    = "db.t3.micro"
  rds_allocated_storage = 20
  rds_storage_encrypted = true

  #db_name             = "calc_app_rds_iac"    # No need since we restore from snapshot.
  #username            = "admin"               # No need since we restore from snapshot.
  #password            = "12345678"            # No need since we restore from snapshot.

  rds_port                 = "3306"
  rds_parameter_group_name = "default.mysql8.0"
  rds_publicly_accessible  = false

  rds_security_group_ids = [module.security_groups.rds_security_group_id]
  rds_subnet_group_name  = module.vpc.rds_subnet_group_name

  rds_snapshot_identifier = "calculator-app-rds-final-snapshot-iac" # Replace with your snapshot ID from which you want the DB to be created
  maintenance_window      = "mon:19:00-mon:19:30"

  # Prevent deletion of the database
  skip_final_snapshot           = true
  rds_final_snapshot_identifier = "calculator-app-rds-final-snapshot-iac2"
}




# Create an EC2: (Bastion jump host - SSH + DB connectivity testing)
######################################################################################
module "bastion_prometheus" {
  source = "./modules/bastion_prometheus_host"

  # --- Pass PRIVATE_DNS_ZONE to Bastion_Host User_Data_Script: ---
  private_dns_zone_id = module.vpc.private_dns_zone_id

  # --- Bastion Host Settings ---
  ami_id                = "ami-0583d8c7a9c35822c"
  instance_type         = "t2.micro"
  subnet_id             = module.vpc.public_subnet_2_id
  bastion_sec_group_ids = [module.security_groups.bastion_host_security_group_id]
  key_name              = var.aws_key_pair
  iam_instance_profile  = module.iam.bastion_instance_profile_name

  # EBS Volume Settings:
  volume_size = 10
  volume_type = "gp2"

  bastion_host_tag_name = "bastion-host"
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
  admin_principal_arn        = data.aws_caller_identity.current.arn
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




# Print all dynamic variables passed to specified modules after terrafrom deployment:
# Usefull for debuging purposes.
########################################################################################################

output "bastion_host_public_ip" {
  value = module.bastion_prometheus.bastion_host_public_ip
}

output "rds_endpoint" {
  value = module.database.rds_endpoint
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
