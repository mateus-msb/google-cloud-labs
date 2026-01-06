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
EXTERNAL_IP="network-lb-ip-1"
TARGET_POOL="www-pool"
HEALTH_CHECK="basic-check"
FORWARDING_RULE="www-rule"

echo "Starting Network Load Balancer setup for Compute Engine"

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

# Add HTTP health check
gcloud compute http-health-checks create $HEALTH_CHECK

echo "HTTP health check $HEALTH_CHECK created"

# Create the target pool with the health check
gcloud compute target-pools create $TARGET_POOL \
  --region $REGION \
  --http-health-check $HEALTH_CHECK

echo "Target pool $TARGET_POOL created with health check $HEALTH_CHECK"

# Add instances to the target pool
# Define comma as separator
IFS=, 
echo "INSTANCE_LIST = ${INSTANCE_LIST[*]}"
gcloud compute target-pools add-instances $TARGET_POOL \
    --instances ${INSTANCE_LIST[*]}

unset IFS
echo "Instances ${INSTANCE_LIST[*]} added to target pool $TARGET_POOL"

# Add a forwarding rule
gcloud compute forwarding-rules create $FORWARDING_RULE \
    --region $REGION \
    --ports $PORT \
    --address $EXTERNAL_IP \
    --target-pool $TARGET_POOL

echo "Forwarding rule $FORWARDING_RULE created to route traffic to target pool $TARGET_POOL"

IPADDRESS=$(gcloud compute forwarding-rules describe $FORWARDING_RULE \
  --region $REGION \
  --format="value(IPAddress)")

echo "Network Load Balancer setup complete. Access your web servers at http://$IPADDRESS/"
