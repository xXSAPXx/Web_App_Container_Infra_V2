#!/bin/bash


# Variables from Terraform:
PRIVATE_DNS_ZONE_ID="${private_dns_zone_id}"
echo "PRIVATE_DNS_ZONE_ID is: $PRIVATE_DNS_ZONE_ID" > /tmp/debug_env.txt


# Install MySQL Client: (Connect to the DB)
sudo dnf install -y mysql



#####################################################################################
###################### AUTOMATIC (Hostname) DNS REGISTRATION ########################

# Generate a token lastng 6-hours for the EC2 metadata retrival process from AWS:
TOKEN=$(curl -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")

# Fetch the private IPv4 address of the EC2 instance.
LOCAL_IP=$(curl -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/local-ipv4)

# Replace dots with dashes in the IP address
DASHED_IP=$(echo "$LOCAL_IP" | tr '.' '-')

# Construct the hostname
HOSTNAME="bastion-$DASHED_IP.internal.xxsapxx.local"

# Set the system hostname
sudo hostnamectl set-hostname "$HOSTNAME"




# Install AWS CLI:
sudo dnf install -y awscli


##### NEEDS IAM ROLE --- (BECAUSE AWS CLI ASKS FOR CREDENTIALS):

# Automatic DNS Registration for the Bastion Host:
sudo aws route53 change-resource-record-sets --hosted-zone-id "$PRIVATE_DNS_ZONE_ID" --change-batch "{
  \"Comment\": \"Register DNS Record for EC2 instance in Route53 private_zone \",
  \"Changes\": [{
    \"Action\": \"UPSERT\",
    \"ResourceRecordSet\": {
      \"Name\": \"$HOSTNAME\",
      \"Type\": \"A\",
      \"TTL\": 120,
      \"ResourceRecords\": [{ \"Value\": \"$LOCAL_IP\" }]
    }
  }]
}"
