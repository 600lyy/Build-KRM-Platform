#!/bin/bash 

# Installs Config Sync on GKE clusters 

########### VARIABLES  ##################################
if [[ -z "$PROJECT_ID" ]]; then
    echo "Must provide PROJECT_ID in environment" 1>&2
    exit 1
fi

if [[ -z "$GITHUB_USERNAME" ]]; then
    echo "Must provide GITHUB_USERNAME in environment" 1>&2
    exit 1
fi

if [[ -z "$GITHUB_TOKEN" ]]; then
    echo "Must provide Github Personal Access Token (PAT) in environment" 1>&2
    exit 1
fi


##########################################################

register_cluster () {
    CLUSTER_NAME=$1 
    CLUSTER_ZONE=$2 
    echo "🏔 Registering cluster to a fleet: $CLUSTER_NAME, zone: $CLUSTER_ZONE" 
    kubectl ctx ${CLUSTER_NAME}

    URI="https://container.googleapis.com/v1/projects/${PROJECT_ID}/zones/${CLUSTER_ZONE}/clusters/${CLUSTER_NAME}"
    gcloud container fleet memberships register ${CLUSTER_NAME} \
    --gke-uri=${URI} \
    --enable-workload-identity
}

install_config_sync () {
    CLUSTER_NAME=$1 
    CLUSTER_ZONE=$2 
    
    echo "********** Creating Secret to grant Config Sync access to your repos: $CLUSTER_NAME, zone: $CLUSTER_ZONE ***************"
    kubectl ctx $CLUSTER_NAME

    kubectl create ns config-management-system && \
    kubectl create secret generic git-creds \
        --namespace="config-management-system" \
        --from-literal=username=$GITHUB_USERNAME \
        --from-literal=token=$GITHUB_TOKEN

    echo "********** Installing Config Sync: $CLUSTER_NAME, zone: $CLUSTER_ZONE ***************" 

    kubectl ctx $CLUSTER_NAME 

    gcloud beta container hub config-management apply \
        --membership=$CLUSTER_NAME \
        --config=apply-spec.yaml \
        --project=$PROJECT_ID
}

# Enable config management feature in Anthos 
gcloud config set project $PROJECT_ID
# Disable/Enable ACM feature to wrok around the FIFO queue full bug
gcloud beta container hub config-management disable
gcloud beta container hub config-management enable

# Replace GITHUB_USERNAME for policy repo in install "apply_spec"
sed -i "s/GITHUB_USERNAME/${GITHUB_USERNAME}/g" apply-spec.yaml

# Install Config Sync on admin, dev, and prod

register_cluster "admin" "europe-north1-a"
install_config_sync "admin" "europe-north1-a"

#register_cluster "dev" "europe-north1-a"
#install_config_sync "dev" "europe-north1-a"

#register_cluster "prod" "europe-north1-a"
#install_config_sync "prod" "europe-north1-a"