
##################################################################
# Create a security group for the RDS instance:
##################################################################

resource "aws_security_group" "rds_sg" {
  vpc_id      = var.vpc_id
  description = "RDS - MySQL access from inside the VPC only"

  ingress {
    description = "MySQL from inside the VPC"
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = [var.rds_cidr_block] # (Only inside VPC)
  }

  egress {
    description = "All outbound, scoped to inside the VPC"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [var.rds_cidr_block] # (Only inside VPC)
  }

  tags = {
    Name = var.rds_security_group_name
  }
}


########################################################################
# Security Group for the Public EC2 - Bastion server (SSH / DB testing):
# Prometheus-specific ports (9090/9100) were dropped along with the old
# self-hosted Prometheus role - re-added below, scoped much tighter this
# time (EKS node SG only, not a broad CIDR) for the in-cluster Prometheus's
# EC2 Service Discovery to scrape this box's node_exporter.
########################################################################

resource "aws_security_group" "bastion_prometheus_sg" {
  name        = var.sec_group_name
  description = var.sec_group_description
  vpc_id      = var.vpc_id

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.bastion_host_cidr_block]
  }

  ingress {
    description = "Ping from outside and inside the VPC"
    from_port   = -1
    to_port     = -1
    protocol    = "icmp"
    cidr_blocks = [var.bastion_host_cidr_block, var.vpc_cidr_block]
  }

  ingress {
    description     = "node_exporter - scraped by the in-cluster Prometheus via EC2 Service Discovery"
    from_port       = 9100
    to_port         = 9100
    protocol        = "tcp"
    security_groups = [aws_security_group.eks_node_sg.id]
  }

  # No inbound rule needed for Tailscale - the bastion connects outbound to
  # Tailscale's coordination service and NAT-traverses from there, unlike
  # raw WireGuard which needed a scoped inbound UDP rule for the client to
  # reach it directly.

  egress {
    description = "All outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}


##################################################################
# Security Group allowing HTTP/HTTPS for the Public ALB:
##################################################################

resource "aws_security_group" "alb_security_group" {
  vpc_id      = var.vpc_id
  description = "Public ALB - HTTP/HTTPS from the internet"

  # Allow incoming HTTP traffic
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = [var.alb_sec_group_cidr_block]
    description = "Allow HTTP traffic"
  }

  # Allow incoming HTTPS traffic
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.alb_sec_group_cidr_block]
    description = "Allow HTTPS traffic"
  }

  # Allow all outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic (Ensures that the ELB can reach any required service without restrictions!)"
  }

  tags = {
    Name = var.alb_security_group_name
  }
}


##################################################################
# Security Group for the EKS worker nodes (and, by default under
# the VPC CNI, the pods running on them). This replaces the old
# ASG web-server SG - the EKS-managed cluster security group already
# handles control-plane<->node traffic, this one covers node-to-node
# pod traffic, ALB->pod traffic, and bastion access for troubleshooting.
##################################################################

resource "aws_security_group" "eks_node_sg" {
  vpc_id      = var.vpc_id
  description = "EKS worker nodes - pod-to-pod, ALB-to-pod, and bastion connectivity checks"

  ingress {
    description = "Node-to-node / pod-to-pod traffic within the cluster"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    self        = true
  }

  ingress {
    description     = "Allow the ALB (AWS Load Balancer Controller) to reach pods on any TCP port"
    from_port       = 0
    to_port         = 65535
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_security_group.id]
  }

  ingress {
    description = "Allow ICMP from inside the VPC (e.g. bastion connectivity checks)"
    from_port   = -1
    to_port     = -1
    protocol    = "icmp"
    cidr_blocks = [var.asg_sec_group_cidr_block]
  }

  egress {
    description = "All outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = var.asg_security_group_name
  }
}


