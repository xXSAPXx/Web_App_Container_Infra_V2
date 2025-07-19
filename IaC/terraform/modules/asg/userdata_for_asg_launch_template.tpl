#!/bin/bash


##############################################################################################
############################ System and Terraform Variables:  ################################

# Variables from Terraform: 
DB_ENDPOINT_SCRIPT="${db_endpoint}"
PRIVATE_DNS_ZONE_ID="${private_dns_zone_id}"
echo "DB_ENDPOINT_SCRIPT is: $DB_ENDPOINT_SCRIPT" >> /tmp/debug_env.txt
echo "PRIVATE_DNS_ZONE_ID is: $PRIVATE_DNS_ZONE_ID" >> /tmp/debug_env.txt


# Variables:
REPO_URL="https://github.com/xXSAPXx/Web_App_Infra_V1.git"  # Replace with your actual repository URL
APP_BASE_DIR="/var/www"
FRONTEND_DIR="$APP_BASE_DIR/html/calculator"                # Actual web root will be $FRONTEND_DIR/public_frontend
BACKEND_DIR="$APP_BASE_DIR/backend"
STAGING_DIR="/tmp/app_deploy_$(date +%s)"
NODE_APP_USER="nodeapp"                                     # Dedicated user for the Node.js app


##############################################################################################################
#################################### Configure Frondend and Backend: #########################################

# Install / Eenable HTTPD Service:
sudo dnf install -y bash-completion
sudo dnf install -y vim
sudo dnf install -y httpd
sudo systemctl start httpd
sudo systemctl enable httpd


# Creating dedicated user for Node.js app:
if ! id "$NODE_APP_USER" &>/dev/null; then
    sudo useradd -m -r -s /bin/false "$NODE_APP_USER"
else
    echo "User $NODE_APP_USER already exists."
fi


# Install git:
sudo dnf install -y git

# Clone git repo to STAGING_DIR: 
sudo git clone "$REPO_URL" "$STAGING_DIR"

# Setting up Frontend: 
sudo mkdir -p "$FRONTEND_DIR/public_frontend"
sudo cp -R "$STAGING_DIR/public_frontend/." "$FRONTEND_DIR/public_frontend/"
sudo chown -R apache:apache "$FRONTEND_DIR/public_frontend"

# Setting up Backend: 
sudo mkdir -p "$BACKEND_DIR"
sudo cp "$STAGING_DIR/src_backend/server.js" "$BACKEND_DIR/"
sudo cp "$STAGING_DIR/package.json" "$BACKEND_DIR/"
sudo chown -R "$NODE_APP_USER:$NODE_APP_USER" "$BACKEND_DIR"


################################################################################################################### 
################################## Set the DB_ENDPOINT on the Backend: ############################################

# Set the DB_ENDPOINT file for DB address parsing: 
DB_ENDPOINT_FILE="$BACKEND_DIR/AWS_RDS_ENDPOINT"

# Create DB_ENDPOINT_FILE and adjust permissions:
sudo touch $DB_ENDPOINT_FILE
sudo chown "$NODE_APP_USER:$NODE_APP_USER" "$DB_ENDPOINT_FILE"

# Add the RDS endpoint to a file for application use:
echo $DB_ENDPOINT_SCRIPT | sudo tee $DB_ENDPOINT_FILE > /dev/null

# Extract just the hostname from the DB_Endpoint without the PORT:
DB_ENDPOINT_NO_PORT=$(sudo awk -F: '{print $1}' "$DB_ENDPOINT_FILE")

# Replace db_endpoint placeholder in server.js
sudo sed -i "s|REPLACE_WITH_DB_ENDPOINT|$DB_ENDPOINT_NO_PORT|g" $BACKEND_DIR/server.js


######################################################################################################################## 
########################### Configure and Start APACHE and NODE_JS Servers #############################################

# Install Node.js 18.x
curl -fsSL https://rpm.nodesource.com/setup_18.x | sudo bash -
sudo dnf install -y nodejs

# Install Backend NodeJS Dependencies: 
cd "$BACKEND_DIR"

# Use npm ci if package-lock.json is in the repo: 
if [ -f "package-lock.json" ]; then
    sudo -u "$NODE_APP_USER" npm ci
else
    sudo -u "$NODE_APP_USER" npm install
fi


# Create Apache_Host Configuration:
sudo cat <<EOL | sudo tee /etc/httpd/conf.d/calculator.conf
<VirtualHost *:80>
    DocumentRoot "$FRONTEND_DIR/public_frontend"
    <Directory "$FRONTEND_DIR/public_frontend">
        AllowOverride None
        Require all granted
    </Directory>
</VirtualHost>
EOL


# Restart httpd service: 
sudo systemctl restart httpd


# Setting up Node.js Backend Service (systemd): 
sudo cat <<EOL | sudo tee /etc/systemd/system/nodeapp.service
[Unit]
Description=Node.js Backend Application for Calculator
After=network.target

[Service]
Environment="NODE_ENV=production"
Environment="PORT=3000"
Type=simple
User=$NODE_APP_USER
WorkingDirectory=$BACKEND_DIR
ExecStart=/usr/bin/node $BACKEND_DIR/server.js
Restart=on-failure
RestartSec=10

StandardOutput=journal
StandardError=journal
SyslogIdentifier=nodeapp-calculator

[Install]
WantedBy=multi-user.target
EOL


# Start Node.js with logging:
sudo chmod 664 /etc/systemd/system/nodeapp.service
sudo systemctl daemon-reload
sudo systemctl enable nodeapp.service
sudo systemctl start nodeapp.service

# Clean up Staging Directory: 
sudo rm -rf "$STAGING_DIR"


#####################################################################################
###################### AUTOMATIC (Hostname) DNS REGISTRATION ########################

# Generate a token lastng 6-hours for the EC2 metadata retrival process from AWS: 
TOKEN=$(curl -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")

# Fetch the private IPv4 address of the EC2 instance.
LOCAL_IP=$(curl -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/local-ipv4)

# Replace dots with dashes in the IP address
DASHED_IP=$(echo "$LOCAL_IP" | tr '.' '-')

# Construct the hostname
HOSTNAME="web-server-$DASHED_IP.internal.xxsapxx.local"

# Set the system hostname
sudo hostnamectl set-hostname "$HOSTNAME"



# Install AWS CLI: 
sudo dnf install -y awscli


##### NEEDS IAM ROLE --- (BECAUSE AWS CLI ASKS FOR CREDENTIALS): 

# Automatic DNS Registration for every EC2 inside the ASG: 
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


#####################################################################################
############################### INSTALL NODE EXPORTER ###############################

NODE_EXPORTER_UNIT_FILE="/etc/systemd/system/node_exporter.service"
NODE_EXPORTER_DIR="/var/lib/node_exporter"
NODE_EXPORTER_BINARY_DIR="/usr/local/bin"
NODE_EXPORTER_USER="node_exporter"
NODE_EXPORTER_VERSION="1.9.0"


# Node_exporter version:
sudo useradd -M -r -s /bin/false $NODE_EXPORTER_USER
sudo mkdir -p $NODE_EXPORTER_DIR
cd $NODE_EXPORTER_DIR
sudo dnf install -y wget
sudo wget https://github.com/prometheus/node_exporter/releases/download/v$NODE_EXPORTER_VERSION/node_exporter-$NODE_EXPORTER_VERSION.linux-amd64.tar.gz
sudo tar -xzf node_exporter-$NODE_EXPORTER_VERSION.linux-amd64.tar.gz
sudo cp node_exporter-$NODE_EXPORTER_VERSION.linux-amd64/node_exporter $NODE_EXPORTER_BINARY_DIR
sudo chown "$NODE_EXPORTER_USER":"$NODE_EXPORTER_USER" $NODE_EXPORTER_BINARY_DIR/node_exporter


# SystemD Config: 
sudo cat <<EOL | sudo tee $NODE_EXPORTER_UNIT_FILE
[Unit]
Description=Node_Exporter
Documentation=https://prometheus.io/docs/guides/node-exporter/
Wants=network-online.target
After=network-online.target

[Service]
User=$NODE_EXPORTER_USER
Group=$NODE_EXPORTER_USER
Type=simple
Restart=on-failure
ExecStart=$NODE_EXPORTER_BINARY_DIR/node_exporter \
  --web.listen-address=:9100

[Install]
WantedBy=multi-user.target
EOL


# Reload all systemd services: 
sudo chmod 664 $NODE_EXPORTER_UNIT_FILE
sudo systemctl daemon-reload
sudo systemctl enable node_exporter.service
sudo systemctl start node_exporter.service
