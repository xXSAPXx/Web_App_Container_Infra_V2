


#################################################################################################################################
######################################## CLOUDFLARE PROVIDER VARIABLES ##########################################################

provider "cloudflare" {
  api_token = var.cloudflare_api_token
}



# Create a Cloudflare DNS record to the ALB CNAME or IP - [SSL cert validation is handled in module alb_cert_validation]
module "cloudflare_dns" {
  source = "./modules/cloudflare"

  # --- Cloudflare Variables for the Module ---
  cloudflare_api_token = var.cloudflare_api_token
  cloudflare_zone_id   = var.cloudflare_zone_id
  select_domain_name   = var.cloudflare_domain_name
  alb_dns_name         = module.alb.alb_dns_name

  # --- Cloudflare_WWW_DNS_Record Settings ---  
  comment         = "Domain pointed to AWS_ALB"
  sub_domain_name = "www"
  dns_record_type = "CNAME"
  dns_ttl         = 1
  proxied         = true

  # --- Cloudflare_ROOT_to_WWW_DNS_Record Settings ---
  root_domain_comment  = "Domain pointed to AWS_ALB"
  root_domain_name     = "@"
  root_dns_record_type = "CNAME"
  root_dns_ttl         = 1
  root_proxied         = true

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


# Networking: 
# Crate VPC / Subnets / Nat_Gateway / RDS_Subnet_Group /Routing / Route53_Private_Zone
######################################################################################

module "vpc" {
  source = "./modules/vpc"

  # --- General VPC Settings ---
  vpc_name              = "App_VPC_IaC"
  vpc_cidr_block        = "10.0.0.0/24"
  internet_gateway_name = "Internet_Gateway_IaC"

  # --- Availability Zone Settings ---
  availability_zone_1 = "us-east-1a"
  availability_zone_2 = "us-east-1b"

  # --- Subnet CIDR Block Settings ---
  public_subnet_1_cidr  = "10.0.0.0/28"
  public_subnet_2_cidr  = "10.0.0.16/28"
  private_subnet_1_cidr = "10.0.0.32/28"
  private_subnet_2_cidr = "10.0.0.48/28"

  # --- NAT_Gateway Settings ---
  nat_gateway_public_subnet_id = 1

  # --- RDS Subnet Group Settings ---
  rds_subnet_group_name = "App_DB_Subnet_Group_IaC"

  # --- Route 53 Settings ---
  private_zone_name = "internal.xxsapxx.local"
}




# Create ALL Security Groups: 
######################################################################################

module "security_groups" {
  source = "./modules/security_groups"

  # For all SGs:
  vpc_id = module.vpc.vpc_id

  # -------- RDS Sec_Group Settings --------
  rds_cidr_block          = "10.0.0.0/24"
  rds_security_group_name = "RDS_SG_IaC"

  # --- Bastion_Prometheus_Host Sec_Group Settings ---
  bastion_host_cidr_block = "0.0.0.0/0"
  sec_group_name          = "bastion_prometheus_sg"
  sec_group_description   = "Allow SSH and Prometheus and Node_Exporter Ports"
  vpc_cidr_block          = module.vpc.vpc_cidr_block # Used for ICMP (Ping) from inside the VPC.

  # --- ALB Sec_Group Settings ---
  alb_sec_group_cidr_block = "0.0.0.0/0" # Public ALB Allows HTTP / HTTPS 
  alb_security_group_name  = "alb_security_group"

  # --- Web_Servers Sec_Group Settings ---     
  asg_sec_group_cidr_block = "10.0.0.0/24"
  bastion_host_sec_group   = [module.security_groups.bastion_host_security_group_id] # Only the BASTION_Sec_Group can SSH the WEB_SERVERS! 
  asg_security_group_name  = "asg_servers_sg"
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




# Create and EC2: (Bastion / Prometheus Host)
######################################################################################
module "bastion_prometheus" {
  source = "./modules/bastion_prometheus_host"

  # --- Pass PRIVATE_DNS_ZONE to Bastion_Prometheus_Host User_Data_Script: ---
  private_dns_zone_id = module.vpc.private_dns_zone_id

  # --- Pass grafana_user and grafana_api_key to Bastion_Host User_Data_Script: ---
  prometheus_grafana_user    = var.prometheus_grafana_user
  prometheus_grafana_api_key = var.prometheus_grafana_api_key

  # --- Bastion_Prometheus_Host Settings ---
  ami_id                = "ami-0583d8c7a9c35822c"
  instance_type         = "t2.micro"
  subnet_id             = module.vpc.public_subnet_2_id
  bastion_sec_group_ids = [module.security_groups.bastion_host_security_group_id]
  key_name              = var.aws_key_pair
  iam_instance_profile  = module.iam.prometheus_server_instance_profile_name

  # EBS Volume Settings:
  volume_size = 10
  volume_type = "gp2"

  bastion_host_tag_name = "bastion-prometheus-host"
}




# Create Frontend/Backend - Target Groups / ALB / ALB_Listeners / ALB Rules 
######################################################################################
module "alb" {
  source = "./modules/alb"


  # --- Target Groups Settings (Frontend / Backend) ---
  vpc_id = module.vpc.vpc_id

  # ----------- Frontend TG -----------
  frontend_tg_name     = "frontend-tg"
  frontend_tg_port     = 80
  frontend_tg_protocol = "HTTP"

  # Health_Check:
  frontend_tg_path                = "/" # Path to your health_check.html file OR "/" FOR GENERIC ROOT_PATH HEALTH_CHECK
  frontend_tg_interval            = 30
  frontend_tg_timeout             = 5
  frontend_tg_healthy_threshold   = 2
  frontend_tg_unhealthy_threshold = 2
  frontend_tg_matcher             = "200"

  frontend_tg_tag_name = "FrontendTargetGroup"


  # ----------- Backend TG ----------- 
  backend_tg_name     = "backend-tg"
  backend_tg_port     = 3000
  backend_tg_protocol = "HTTP"

  # Health_Check:
  backend_tg_path                = "/backend"
  backend_tg_interval            = 30
  backend_tg_timeout             = 5
  backend_tg_healthy_threshold   = 2
  backend_tg_unhealthy_threshold = 2
  backend_tg_matcher             = "200"

  backend_tg_tag_name = "BackendTargetGroup"


  # ----------- ALB Configuration Settings -----------
  alb_name                       = "alb-web-servers-asg"
  alb_subnets                    = [module.vpc.public_subnet_1_id, module.vpc.public_subnet_2_id] # We need 2 Subnets for the ALB to work
  alb_security_groups            = [module.security_groups.alb_security_group_id]
  alb_load_balancer_type         = "application"
  alb_internal                   = false
  alb_enable_deletion_protection = false

  alb_tag_name = "asg-web-servers-alb"


  # ----------- ALB Listeners Configuration Settings -----------

  # HTTP Listener: 
  # Forwards All Taffic on port 80 to HTTPS(443) --> aws_lb_target_group.frontend_tg.arn
  http_listener_port = 80
  # Redirect to HTTPS: 
  http_listener_redirect_protocol    = "HTTPS"
  http_listener_redirect_port        = "443"
  http_listener_redirect_status_code = "HTTP_301"


  # HTTPS Listener: 
  # Forwards All Taffic on port 443 to --> aws_lb_target_group.frontend_tg.arn
  https_listener_port            = 443
  https_listener_ssl_policy      = "ELBSecurityPolicy-2016-08"
  https_listener_certificate_arn = module.alb_ssl_cert_validation.alb_certificate_arn

  # ALB Rules for HTTPS Listener: 
  # List of path patterns to forward to the backend_tg
  backend_path_patterns = ["/api/*"]
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



# Create Containerized Application:  
# Container Scaling Policies:
########################################################################################################
module "container_app" {
  source = "./modules/container_app"
  depends_on = [module.database]

  # --- Pass DB_ENDPOINT and PRIVATE_DNS_ZONE to the Containers: ---
  database_endpoint   = module.database.rds_endpoint
  private_dns_zone_id = module.vpc.private_dns_zone_id

  # --- Container App Settings ---

}




# Print all dynamic variables passed to specified modules after terrafrom deployment: 
# Usefull for debuging purposes.
# This ensures the modules received the correct env variables. 
########################################################################################################

output "private_dns_zone_id" {
  value = module.container_app.private_dns_zone_debug
}

output "rds_endpoint_id" {
  value = module.container_app.rds_endpoint_debug
}

output "bastion_host_public_ip" {
  value = module.bastion_prometheus.bastion_host_public_ip
}

