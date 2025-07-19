
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
# Security Group for the Public EC2 - Bastion + Prometheus server: 
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
    from_port   = 9090
    to_port     = 9090
    protocol    = "tcp"
    cidr_blocks = [var.bastion_host_cidr_block]
  }

  ingress {
    from_port   = 9100
    to_port     = 9100
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
# Security Group for the EC2s (Web_Servers)
##################################################################

resource "aws_security_group" "web_servers_sg" {
  vpc_id = var.vpc_id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = [var.asg_sec_group_cidr_block] # Only inside VPC
  }

  ingress {
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = var.bastion_host_sec_group # Only the BASTION_Sec_Group can SSH the WEB_SERVERS! 
  }

  ingress {
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = [var.asg_sec_group_cidr_block] # Only inside VPC
  }

  ingress {
    from_port   = 9100
    to_port     = 9100
    protocol    = "tcp"
    cidr_blocks = [var.asg_sec_group_cidr_block] # Node Exporter / # Only inside VPC
  }

  ingress {
    from_port   = -1
    to_port     = -1
    protocol    = "icmp"
    cidr_blocks = [var.asg_sec_group_cidr_block] # Ping Only Inside VPC
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


