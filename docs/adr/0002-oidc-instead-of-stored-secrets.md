# 2. OIDC federation instead of stored credentials

**Status:** accepted

## Context

A pipeline that deploys to Azure has to authenticate. The usual approach is a
service principal: create one, generate a client secret, paste it into the
repository's secrets, and rotate it before it expires — which in practice means
after it expires and something breaks.

## Decision

No stored credential. GitHub Actions exchanges its own short-lived workflow
token for an Entra ID token, against a federated credential scoped to this
repository. The workload in the cluster does the same through AKS workload
identity, presenting its Kubernetes service account.

## Why

A client secret is a long-lived credential that exists in at least two places
and is valid from anywhere. The federated credential is bound to a subject —
`repo:owner/name:ref:refs/heads/main` — so a token minted by a fork, a feature
branch or a workflow in another repository is refused by Entra ID rather than
by a check somewhere in the pipeline.

Pull requests get a separate credential bound to `pull_request`, so a plan can
read while only main can apply. That distinction is enforced by the identity
provider, not by a conditional in a workflow file that a contributor could
change in the same pull request.

Nothing expires, so nothing has to be rotated, so nothing breaks at 3am because
a rotation was skipped.

`cicd_client_id` is an output and not a secret: it names the identity, it does
not authenticate as it.

## What it costs

Federated credentials are per-subject, so a new branch pattern or a new
repository is a Terraform change rather than a copied secret. That is the point,
and it is also the friction.
