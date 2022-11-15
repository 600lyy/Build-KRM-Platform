#!/bin/sh
# https://cloud.google.com/config-connector/docs/how-to/advanced-install#namespaced-mode

# In this demo examplem, host project and managed project are one project


if [[ -z "$PROJECT_ID" ]]; then
    echo "Must provide PROJECT_ID in environment" 1>&2
    exit 1
fi

export SERVICE_ACCOUNT_NAME="kcc-sa-alpha"
export MANAGED_NAMESPACE="alpha"


setup_sa_for_kcc () {
    echo "☸️ Setting up IAM Service Account, role bindings and permissions for KCC..." 

    echo "☁️ Creating a Google Service Account (GSA) in your kcc host project..."
    gcloud iam service-accounts create $SERVICE_ACCOUNT_NAME \
        --project=$PROJECT_ID

    echo "☁️ Granting the GSA cloud resource management permissions on your managed project..." 
    gcloud projects add-iam-policy-binding ${PROJECT_ID} \
        --member="serviceAccount:${SERVICE_ACCOUNT_NAME}@${PROJECT_ID}.iam.gserviceaccount.com" \
        --role="roles/owner"

    echo "☁️ Connecting your Google Service Account to the Kubernetes Service Account (KSA) that kcc uses..."
    gcloud iam service-accounts add-iam-policy-binding \
    $SERVICE_ACCOUNT_NAME@$PROJECT_ID.iam.gserviceaccount.com \
        --member="serviceAccount:$PROJECT_ID.svc.id.goog[cnrm-system/cnrm-controller-manager-${MANAGED_NAMESPACE}]" \
        --role="roles/iam.workloadIdentityUser"
}

setup_sa_for_kcc

echo "✅ Finished setting up service account and necessary permissions for kcc in the host project $PROJECT_ID."

# Replace NAMESPCE for configconnectorcontext.yaml
# sed -i "s/NAMESPACE_GSA/${SERVICE_ACCOUNT_NAME}/g" configconnectorcontext.yaml
# sed -i "s/HOST_PROJECT_ID/${PROJECT_ID}/g" configconnectorcontext.yaml