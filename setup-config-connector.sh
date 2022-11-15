#!/bin/sh
# https://cloud.google.com/config-connector/docs/how-to/install-upgrade-uninstall 

if [[ -z "$PROJECT_ID" ]]; then
    echo "Must provide PROJECT_ID in environment" 1>&2
    exit 1
fi

gcloud config set project $PROJECT_ID
export SERVICE_ACCOUNT_NAME="cymbal-kcc-admin"
export MANAGED_NAMESPACE="kcc-admin"

kcc_install() {
    CLUSTER_NAME=$1

    echo "☁️ Enabling ConfigConnector add-on in $CLUSTER_NAME..."
    gcloud container clusters update $CLUSTER_NAME \
        --update-addons ConfigConnector=ENABLED
}


setup_kcc () {
    CLUSTER_NAME=$1 
    CLUSTER_ZONE=$2 
    echo "☸️ Setting up Config Connector: $CLUSTER_NAME, zone: $CLUSTER_ZONE" 

    kubectl ctx $CLUSTER_NAME

    echo "☁️ Creating a Kubernetes Namespace to manage GCP resources..."
    kubectl create namespace $MANAGED_NAMESPACE
    kubectl annotate namespace $MANAGED_NAMESPACE cnrm.cloud.google.com/project-id=$PROJECT_ID

    echo "☁️ Creating a Google Service Account (GSA) for Config Connector..."
    gcloud iam service-accounts create $SERVICE_ACCOUNT_NAME \
        --project=$PROJECT_ID

    echo "☁️ Granting the GSA cloud resource management permissions..." 
    gcloud projects add-iam-policy-binding ${PROJECT_ID} \
        --member="serviceAccount:${SERVICE_ACCOUNT_NAME}@${PROJECT_ID}.iam.gserviceaccount.com" \
        --role="roles/owner"

    echo "☁️ Connecting your Google Service Account to the Kubernetes Service Account (KSA) that Config Connector uses..."
    gcloud iam service-accounts add-iam-policy-binding \
    $SERVICE_ACCOUNT_NAME@$PROJECT_ID.iam.gserviceaccount.com \
        --member="serviceAccount:$PROJECT_ID.svc.id.goog[cnrm-system/cnrm-controller-manager-${MANAGED_NAMESPACE}]" \
        --role="roles/iam.workloadIdentityUser"

    kubectl apply -f configconnector.yaml
    # kubectl annotate namespace $MANAGED_NAMESPACE cnrm.cloud.google.com/project-id=$PROJECT_ID
    kubectl apply -f configconnectorcontext.yaml

}


# Replace NAMESPCE for configconnectorcontext.yaml
sed -i "s/NAMESPACE_GSA/${SERVICE_ACCOUNT_NAME}/g" configconnectorcontext.yaml
sed -i "s/HOST_PROJECT_ID/${PROJECT_ID}/g" configconnectorcontext.yaml

kcc_install "admin"
setup_kcc "admin" "europe-north1-a"

echo "✅ Finished installing Config Connector on the admin cluster."