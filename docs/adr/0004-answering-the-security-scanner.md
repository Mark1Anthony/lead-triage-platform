# 4. How security findings are handled

**Status:** accepted

## Context

Checkov reported 28 findings on the first run. Two easy responses were
available: turn the scan off, or set `soft_fail: true` so it reports and never
blocks. Both produce a green pipeline and neither produces a safer system.

## Decision

The scan blocks. Every finding is either fixed or skipped with the reason
written next to the code it concerns.

## The rule

- **Fixed** when there is no real downside. Azure Policy admission control, a
  patch upgrade channel, secret rotation, an expiry and a content type on the
  connection string, network security groups, NetworkPolicies on both
  workloads, no service account token where the API is never called, and the
  container hardening the Postgres chart was missing.
- **Skipped, with the reason in the file**, when the finding is a real trade.
  Twenty of them are. Eight are one decision — a Basic container registry
  rather than Premium, which is roughly ten times the price for a registry
  holding one image. Three more are the same trade as a private API server:
  closing the network would lock out the GitHub-hosted runner that deploys it.
  The honest answer there is a self-hosted runner inside the VNet, and saying
  so is better than pretending the finding does not apply.
- **One false positive.** The database has no public endpoint at all; it joins
  a delegated subnet and resolves through a private DNS zone. Checkov looks for
  a private endpoint resource and does not recognise VNet integration, which
  reaches the same result by another mechanism.
- **One repository-wide exception**, in `.checkov.yaml`: CKV_K8S_21 reports the
  default namespace because Checkov renders each chart on its own. Terraform
  creates the namespace and installs into it. Annotating every namespaced
  object in both charts would satisfy the scanner and tell a reader nothing.

## Why the reason goes in the file

A skip without a reason is indistinguishable from a skip added to make a build
pass. Six months later nobody can tell which finding was considered and which
was silenced, and the only safe assumption is the pessimistic one. Written
where the resource is, the reason is in front of whoever next changes it — and
if the trade stops holding, the comment is the thing that no longer reads true.
