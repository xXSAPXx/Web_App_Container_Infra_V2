

###################################################################################
# Create a VPC / 2_Public_Subnets for teh NAT and ALB / Internet_Gateway
###################################################################################

# Create the VPC: 
resource "aws_vpc" "my_vpc" {
  cidr_block           = var.vpc_cidr_block
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = {
    Name = var.vpc_name
  }
}


# Create a Public_Subnet_1:
resource "aws_subnet" "public_subnet_1" {
  vpc_id                  = aws_vpc.my_vpc.id
  cidr_block              = var.public_subnet_1_cidr
  availability_zone       = var.availability_zone_1 # Replace with your preferred AZ
  map_public_ip_on_launch = true                    # Enable this to auto-assign public IPs
  tags = {
    Name = "Public_Subnet_1_IaC"
  }
}


# Create Public_Subnet_2:
resource "aws_subnet" "public_subnet_2" {
  vpc_id                  = aws_vpc.my_vpc.id
  cidr_block              = var.public_subnet_2_cidr # Make sure the CIDR block doesn't overlap with the first subnet
  availability_zone       = var.availability_zone_2  # Replace with another AZ in your preferred region
  map_public_ip_on_launch = true                     # Enable this to auto-assign public IPs
  tags = {
    Name = "Public_Subnet_2_IaC"
  }
}


# Create an internet gateway:
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.my_vpc.id
  tags = {
    Name = "Internet_Gateway_IaC"
  }
}



##################################################################
# Create NAT GATEWAY in only 1 public subnet in 1 AZ
##################################################################

# NAT Gateway in public subnet AZ1
resource "aws_eip" "nat_eip" {
  domain = "vpc"
}

resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat_eip.id

  # Use a conditional to choose the subnet based on the variable.
  # If the variable is 2, use public_subnet_2.id. Otherwise, use public_subnet_1.id.
  subnet_id  = var.nat_gateway_public_subnet_id == 2 ? aws_subnet.public_subnet_2.id : aws_subnet.public_subnet_1.id
  depends_on = [aws_internet_gateway.igw]
}


##################################################################
# Create 2 private_subnets for the MySQL DB / ASG / SEC GROUP 
##################################################################


# Create a Private_Subnet_1:
resource "aws_subnet" "private_subnet_1" {
  vpc_id                  = aws_vpc.my_vpc.id
  cidr_block              = var.private_subnet_1_cidr # Make sure the CIDR block doesn't overlap with the public subnet
  availability_zone       = var.availability_zone_1   # Same AZ as the first public subnet
  map_public_ip_on_launch = false                     # DO NOT Auto-assign public IPs!
  tags = {
    Name = "Private_Subnet_1_IaC"
  }
}



# Create a Private_Subnet_2:
resource "aws_subnet" "private_subnet_2" {
  vpc_id                  = aws_vpc.my_vpc.id
  cidr_block              = var.private_subnet_2_cidr # Make sure the CIDR block doesn't overlap with the public subnet
  availability_zone       = var.availability_zone_2   # Same AZ as the second public subnet
  map_public_ip_on_launch = false                     # DO NOT Auto-assign public IPs!
  tags = {
    Name = "Private_Subnet_2_IaC"
  }
}



# Create a subnet group for the RDS instance
resource "aws_db_subnet_group" "mydb_subnet_group" {
  name = "var.rds_subnet_group_name"
  subnet_ids = [
    aws_subnet.private_subnet_1.id,
    aws_subnet.private_subnet_2.id
  ]

  tags = {
    Name = var.rds_subnet_group_name
  }
}



##############################################################################
# Create Route_Tables for both public and private subnets: 
##############################################################################


############### PUBLIC ROUTING TABLE and SUBNETS: ###############
# All traffic from the 2 public subnets are going to the Internet Gateway: 
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.my_vpc.id

  route {
    cidr_block = "0.0.0.0/0" # Any traffic destined for an address outside the VPC will be directed to the VPC internet gateway
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "public_rt_IaC"
  }
}

##### PUBLIC SUBNETS: ##### 
# Associate the route table with public_subnet_1
resource "aws_route_table_association" "public_rt_assoc" {
  subnet_id      = aws_subnet.public_subnet_1.id
  route_table_id = aws_route_table.public_rt.id
}

# Associate the route table with public_subnet_2
resource "aws_route_table_association" "public_rt_assoc_2" {
  subnet_id      = aws_subnet.public_subnet_2.id
  route_table_id = aws_route_table.public_rt.id
}


############### PRIVATE ROUTING TABLE and SUBNETS: ###############
# All traffic from the private subnets are going to the NAT Gateway: 
resource "aws_route_table" "private_rt" {
  vpc_id = aws_vpc.my_vpc.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat.id
  }

  tags = {
    Name = "private_rt_IaC"
  }
}

##### PRIVATE SUBNETS: ##### 
# Associate the route table with the 1st PRIVATE subnet:
resource "aws_route_table_association" "private_rt_assoc" {
  subnet_id      = aws_subnet.private_subnet_1.id
  route_table_id = aws_route_table.private_rt.id
}

# Associate the route table with the 2nd PRIVATE subnet: 
resource "aws_route_table_association" "private_rt_assoc_2" {
  subnet_id      = aws_subnet.private_subnet_2.id
  route_table_id = aws_route_table.private_rt.id
}


##############################################################################
# Create Route53 Private Zone for the private subnets: 
##############################################################################

# Pass the Private_ZONE_ID Variable to the userdata script -- (IN RDS CREATION BLOCK)

resource "aws_route53_zone" "private" {
  name = var.private_zone_name
  vpc {
    vpc_id = aws_vpc.my_vpc.id
  }
  comment       = "Private zone for internal DNS resolution"
  force_destroy = true # Allows deletion of the zone even if it contains records
}

