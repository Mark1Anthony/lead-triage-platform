#!/usr/bin/env bash
#
# Creates the storage account that terraform/azure keeps its state in.
#
# This exists outside Terraform because a configuration cannot create the
# backend it stores its own state in - the backend has to be there before the
# first init. Run once per subscription.
#
# Writes backend.hcl next to the configuration; that file is gitignored,
# because it names an account rather than describing infrastructure.

set -euo pipefail

LOCATION="${LOCATION:-germanywestcentral}"
RESOURCE_GROUP="${RESOURCE_GROUP:-rg-terraform-state}"
CONTAINER="${CONTAINER:-tfstate}"

# Storage account names are globally unique and allow lowercase letters and
# digits only, at most 24 characters.
SUFFIX="$(az account show --query id -o tsv | tr -d '-' | cut -c1-8)"
STORAGE_ACCOUNT="${STORAGE_ACCOUNT:-sttfstate${SUFFIX}}"

echo "Subscription: $(az account show --query name -o tsv)"
echo "Storage account: ${STORAGE_ACCOUNT}"
read -rp "Continue? [y/N] " reply
[[ "${reply}" == "y" ]] || exit 1

az group create --name "${RESOURCE_GROUP}" --location "${LOCATION}" --output none

az storage account create \
  --name "${STORAGE_ACCOUNT}" \
  --resource-group "${RESOURCE_GROUP}" \
  --location "${LOCATION}" \
  --sku Standard_LRS \
  --kind StorageV2 \
  --min-tls-version TLS1_2 \
  --allow-blob-public-access false \
  --output none

# Versioning, because state is the record of what exists. A bad apply that
# corrupts it is recoverable from a previous version; without it, it is not.
az storage account blob-service-properties update \
  --account-name "${STORAGE_ACCOUNT}" \
  --resource-group "${RESOURCE_GROUP}" \
  --enable-versioning true \
  --output none

az storage container create \
  --name "${CONTAINER}" \
  --account-name "${STORAGE_ACCOUNT}" \
  --auth-mode login \
  --output none

cat > "$(dirname "$0")/../terraform/azure/backend.hcl" <<EOF
resource_group_name  = "${RESOURCE_GROUP}"
storage_account_name = "${STORAGE_ACCOUNT}"
container_name       = "${CONTAINER}"
key                  = "azure.tfstate"
EOF

echo
echo "Done. Next:"
echo "  cd terraform/azure && terraform init -backend-config=backend.hcl"
