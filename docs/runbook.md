# Runbook

## Local cluster

```bash
kind create cluster --config kind/cluster.yaml
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml
kubectl wait -n ingress-nginx --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller --timeout=180s

cd terraform/cluster && terraform init && terraform apply
```

`http://lead-triage.localtest.me`. Tear down with `terraform destroy` and
`kind delete cluster --name lead-triage`.

### When it does not come up

| Symptom | Cause |
|---|---|
| `/health` says `"database":"sqlite"` | The secret did not reach the pod. The application falls back rather than failing, so this is the only signal. `kubectl -n lead-triage get secret lead-triage-secrets` |
| Pods `Pending` | No node has capacity for the requests, or the PVC has no storage class. `kubectl -n lead-triage describe pod` |
| Ingress 503 | The controller is up before the pods are ready. It resolves itself; if it does not, the readiness probe is failing |
| `ImagePullBackOff` | The image was never loaded into the cluster. `kind load docker-image <tag> --name lead-triage` |
| Terraform hangs on `helm_release` | `wait = true` is waiting for a pod that will never be ready. Watch it in another shell |

## Azure

**This has not been run.** It creates billable resources. Read
[ADR 5](adr/0005-no-billable-resources.md) first.

### What it costs

| Resource | Roughly |
|---|---|
| AKS control plane, Free tier | 0 EUR |
| 2 × Standard_B2s nodes | ~60 EUR/month |
| PostgreSQL Flexible Server, B_Standard_B1ms | ~13 EUR/month |
| Container Registry, Basic | ~4.50 EUR/month |
| Key Vault, Log Analytics, load balancer, egress | ~10 EUR/month |
| | **~88 EUR/month**, about 3 EUR a day |

Azure enforces no spending cap. The budget in `observability.tf` alerts at 80%
of actual and 100% of forecast spend; it does not stop anything. Destroying the
resource group is what stops the meter.

### Sequence

```bash
# 1. State storage. Once per subscription, outside Terraform - a configuration
#    cannot create the backend it stores its own state in.
./scripts/bootstrap.sh

# 2. The stack.
cd terraform/azure
terraform init -backend-config=backend.hcl
terraform plan -out=tf.plan          # read this before applying
terraform apply tf.plan

# 3. Cluster credentials. Local accounts are disabled, so this is an Entra login.
az aks get-credentials \
  --resource-group "$(terraform output -raw resource_group)" \
  --name "$(terraform output -raw cluster_name)"
```

`terraform plan` alone is free and makes no change — it is also the only part
of this that has to reach Azure to tell you whether the configuration is right.

### Afterwards

Point the pipeline at the identity Terraform created:

```bash
terraform output -raw cicd_client_id
```

That value goes into the `azure/login` step as `client-id`. It is not a secret.

### Tearing it down

```bash
terraform destroy
```

Key Vault has purge protection, so the vault survives for seven days as a
soft-deleted object and its name stays taken. A second apply with the same
`name` and `environment` fails until it is purged or the names change. That is
the protection working, not a bug.
