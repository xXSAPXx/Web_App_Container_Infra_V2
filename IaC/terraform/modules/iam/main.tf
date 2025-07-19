
#####################################################################################
# IAM FOR PROMETHEUS AUTO SERVICE DISCOVERY AND DNS REGISTRATION:
#####################################################################################

# Create the IAM policy for the Prometheus Server:
resource "aws_iam_policy" "prometheus" {
  name        = "prometheus-instance-policy"
  description = "Policy for Prometheus EC2 instance to allow EC2, ELB, CloudWatch, and ASG reads"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "ec2:Describe*",
          "ec2:GetSecurityGroupsForVpc"
        ],
        Resource = "*"
      },
      {
        Effect   = "Allow",
        Action   = "elasticloadbalancing:Describe*",
        Resource = "*"
      },
      {
        Effect = "Allow",
        Action = [
          "cloudwatch:ListMetrics",
          "cloudwatch:GetMetricStatistics",
          "cloudwatch:Describe*"
        ],
        Resource = "*"
      },
      {
        Effect   = "Allow",
        Action   = "autoscaling:Describe*",
        Resource = "*"
      }
    ]
  })

  tags = {
    Name = "prometheus-iam-policy"
  }
}

# Create the IAM policy for DNS Registration for all servers: 
resource "aws_iam_policy" "route53_register" {
  name        = "route53-register-records"
  description = "Allow EC2 to register DNS records in private Route53 zones"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "route53:ChangeResourceRecordSets"
        ],
        Resource = "arn:aws:route53:::hostedzone/${var.private_dns_zone_id}"
      },
      {
        Effect   = "Allow",
        Action   = "route53:ListHostedZones",
        Resource = "*"
      }
    ]
  })
}


#####################################################################################
# IAM ROLES FOR PROMETHEUS SERVER AND LAUCH TEMPLATE:
#####################################################################################

# Create the IAM Role for the Prometheus Server: 
resource "aws_iam_role" "prometheus" {
  name = "prometheus-instance-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Service = "ec2.amazonaws.com"
        },
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Name = "prometheus-ec2-role"
  }
}


# Create the IAM Role for the DNS Registration:
resource "aws_iam_role" "dns_registration" {
  name = "dns-updater-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Service = "ec2.amazonaws.com"
        },
        Action = "sts:AssumeRole"
      }
    ]
  })
}



################## PROMETHEUS SERVER INSTANCE_PROFILE ##################

# Attach BOTH polices to the Prometheus Server Role: 
resource "aws_iam_role_policy_attachment" "prometheus" {
  role       = aws_iam_role.prometheus.name
  policy_arn = aws_iam_policy.prometheus.arn
}

resource "aws_iam_role_policy_attachment" "bastion_route53_attach" {
  role       = aws_iam_role.prometheus.name
  policy_arn = aws_iam_policy.route53_register.arn
}

# Create the IAM instance profile for the Prometheus Server and attach the required IAM Role: 
resource "aws_iam_instance_profile" "prometheus" {
  name = "prometheus-instance-profile"
  role = aws_iam_role.prometheus.name
}




################## LAUNCH TEMPLATE INSTANCE_PROFILE ##################

# Attach ONLY the DNS REGISTRATION Policy to the Launch Template Role:   
resource "aws_iam_role_policy_attachment" "dns_attach" {
  role       = aws_iam_role.dns_registration.name
  policy_arn = aws_iam_policy.route53_register.arn
}

resource "aws_iam_instance_profile" "dns_registration_instance_profile" {
  name = "dns-registration-instance-profile"
  role = aws_iam_role.dns_registration.name
}





