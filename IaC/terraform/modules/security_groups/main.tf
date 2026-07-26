
##################################################################
# Create a security group for the RDS instance:
##################################################################

resource "aws_security_group" "rds_sg" {
  vpc_id = var.vpc_id

  ingress {
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = [var.rds_cidr_block] # (Only inside VPC)
  }

  egress {
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
# Prometheus-specific ports (9090/9100) were dropped along with the
# Prometheus role - this box is now a plain jump host.
########################################################################

resource "aws_security_group" "bastion_prometheus_sg" {
  name        = var.sec_group_name
  description = var.sec_group_description
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.bastion_host_cidr_block]
  }

  ingress {
    from_port   = -1
    to_port     = -1
    protocol    = "icmp"
    cidr_blocks = [var.bastion_host_cidr_block, var.vpc_cidr_block] # Ping from outside and inside the VPC.
  }

  egress {
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
  vpc_id = var.vpc_id

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
  vpc_id = var.vpc_id

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
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = var.asg_security_group_name
  }
}


