#!/bin/bash


# Exit on any error
set -e

# Declare variables
ZONE="us-west3-a"
REGION="${ZONE%-*}"

INSTANCE_NAME="www"
INSTANCE_LIST=()

TAGS="network-lb-tag"
MACHINE_TYPE="e2-small"
FIREWALL_RULE="www-firewall-network-lb"
PORT="80"
BACKEND_TEMPLATE="lb-backend-template"
EXTERNAL_IP="network-lb-ip-1"
TARGET_POOL="www-pool"
HEALTH_CHECK="http-basic-check"
FORWARDING_RULE="www-rule"

echo "Starting HTTP Load Balancer setup for Compute Engine"

# Set the default region and zone
gcloud config set compute/region $REGION
gcloud config set compute/zone $ZONE

# Create multiple web server instances
for i in 1 2 3; do

    # Create dynamic naming
    NAME="$INSTANCE_NAME$i" 
    echo "Criando instância: $NAME"

    # Create VM
    gcloud compute instances create $NAME \
        --zone=$ZONE \
        --tags=$TAGS \
        --machine-type=$MACHINE_TYPE \
        --image-family=debian-12 \
        --image-project=debian-cloud \
        --metadata=startup-script="#!/bin/bash
          apt-get update
          apt-get install apache2 -y
          service apache2 restart
          # Aqui usamos a variável $NAME para que cada site mostre seu próprio nome
          echo '<h3>Web Server: $NAME</h3>' | tee /var/www/html/index.html"
          
    # Append to VMs list
    INSTANCE_LIST+=("$NAME")
done

echo "INSTANCE_LIST = ${INSTANCE_LIST[@]}"

# Create firewall rule to allow external traffic
gcloud compute firewall-rules create $FIREWALL_RULE \
    --target-tags $TAGS \
    --allow tcp:$PORT \
    --source-ranges 0.0.0.0/0

echo "Firewall rule $FIREWALL_RULE created to allow traffic on port $PORT"

# Create a static external IP address 
gcloud compute addresses create $EXTERNAL_IP \
  --region $REGION

echo "Static external IP address $EXTERNAL_IP created"


# Create the load balancer template

# Create a managed instance group

# Create the  firewall rule

# Set up a global static external IP

echo "Static external IP address created: $IPV4_ADDRESS"