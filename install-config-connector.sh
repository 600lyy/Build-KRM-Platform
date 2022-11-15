#!/bin/sh
# https://cloud.google.com/config-connector/docs/how-to/install-upgrade-uninstall 

if [[ -z "$PROJECT_ID" ]]; then
    echo "Must provide PROJECT_ID in environment" 1>&2
    exit 1
fi


kcc_install() {
    CLUSTER_NAME=$1

    echo "☁️ Enabling ConfigConnector add-on for $CLUSTER_NAME..."
    gcloud container clusters update $CLUSTER_NAME \
        --update-addons ConfigConnector=ENABLED
}

kcc_install "admin"

echo "✅ Finished installing Config Connector for $CLUSTER_NAME."