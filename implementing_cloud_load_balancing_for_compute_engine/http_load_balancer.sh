#!/bin/bash


# Exit on any error
set -e

# Declare variables
ZONE="us-east4-b"
REGION="${ZONE%-*}"

INSTANCE_NAME="www"
INSTANCE_LIST=()

TAGS="network-lb-tag"
MACHINE_TYPE="e2-small"
FIREWALL_RULE="www-firewall-network-lb"
TRAFFIC="ingress"
PORT="80"

BACKEND_TEMPLATE="lb-backend-template"
BACKEND_TAGS="allow-health-check"
MANAGED_INSTANCE_GROUP="lb-backend-group"
FW_ALLOW_HEALTH_CHECK="fw-allow-health-check"
ALLOW_RANGES="130.211.0.0/22,35.191.0.0/16"

EXTERNAL_IP="lb-ipv4-1"
HEALTH_CHECK="http-basic-check"
URL_MAP="web-map-http"
TARGET_HTTP_PROXY="http-lb-proxy"

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
gcloud compute instance-templates create $BACKEND_TEMPLATE \
   --region=$REGION \
   --network=default \
   --subnet=default \
   --tags=$BACKEND_TAGS \
   --machine-type=e2-medium \
   --image-family=debian-12 \
   --image-project=debian-cloud \
   --metadata=startup-script='#!/bin/bash
     apt-get update
     apt-get install apache2 -y
     a2ensite default-ssl
     a2enmod ssl
     vm_hostname="$(curl -H "Metadata-Flavor:Google" \
     http://169.254.169.254/computeMetadata/v1/instance/name)"
     echo "Page served from: $vm_hostname" | \
     tee /var/www/html/index.html
     systemctl restart apache2'

echo "Instance template $BACKEND_TEMPLATE created"

# Create a managed instance group
gcloud compute instance-groups managed create $MANAGED_INSTANCE_GROUP \
   --template=$BACKEND_TEMPLATE --size=2 --zone=$ZONE

# Create the  firewall rule
gcloud compute firewall-rules create $FW_ALLOW_HEALTH_CHECK \
  --network=default \
  --action=allow \
  --direction=$TRAFFIC \
  --source-ranges=$ALLOW_RANGES \
  --target-tags=$BACKEND_TAGS \
  --rules=tcp:$PORT

# Set up a global static external IP
gcloud compute addresses create $EXTERNAL_IP \
  --ip-version=IPV4 \
  --global

IPV4_ADDRESS=$(gcloud compute addresses describe $EXTERNAL_IP \
  --format="get(address)" --global)
echo "Static external IP address created: $IPV4_ADDRESS"

# Create a health check for the load balancer
gcloud compute health-checks create http $HEALTH_CHECK \
  --port $PORT

echo "Health check $HEALTH_CHECK created"

# Create a backend service
gcloud compute backend-services create web-backend-service \
  --protocol=HTTP \
  --port-name=http \
  --health-checks=$HEALTH_CHECK \
  --global

echo "Backend service web-backend-service created"

# Add the instance group to the backend service
gcloud compute backend-services add-backend web-backend-service \
  --instance-group=$MANAGED_INSTANCE_GROUP \
  --instance-group-zone=$ZONE \
  --global

echo "Instance group $MANAGED_INSTANCE_GROUP added to backend service"

# Create a URL map to route the incoming requests
gcloud compute url-maps create $URL_MAP \
    --default-service web-backend-service

echo "URL map $URL_MAP created"

# Create a target HTTP proxy to route requests to your URL map
gcloud compute target-http-proxies create $TARGET_HTTP_PROXY \
    --url-map $URL_MAP

echo "Target HTTP proxy $TARGET_HTTP_PROXY created"

# Create a global forwarding rule to route incoming requests
gcloud compute forwarding-rules create http-content-rule \
   --address=$EXTERNAL_IP \
   --global \
   --target-http-proxy=$TARGET_HTTP_PROXY \
   --ports=$PORT

echo "Forwarding rule http-content-rule created"
