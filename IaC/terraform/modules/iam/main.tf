
#####################################################################################
# IAM FOR BASTION DNS REGISTRATION:
# (The old Prometheus-specific EC2/ELB/CloudWatch/ASG describe policy was removed
# along with the Prometheus role on the bastion - see modules/bastion_prometheus_host.
# Cluster observability moves in-cluster in a later phase.)
#####################################################################################

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
# IAM ROLE FOR THE BASTION HOST:
#####################################################################################

# Create the IAM Role for the Bastion Host (self-registers its hostname in the
# private Route53 zone on boot - see userdata_for_bastion_prometheus_host.tpl):
resource "aws_iam_role" "bastion" {
  name = "bastion-instance-role"

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
    Name = "bastion-ec2-role"
  }
}

resource "aws_iam_role_policy_attachment" "bastion_route53_attach" {
  role       = aws_iam_role.bastion.name
  policy_arn = aws_iam_policy.route53_register.arn
}

resource "aws_iam_instance_profile" "bastion" {
  name = "bastion-instance-profile"
  role = aws_iam_role.bastion.name
}





