# 5. Nothing in this repository bills

**Status:** accepted

## Context

The obvious version of this project runs on AKS with a managed PostgreSQL,
publishes a URL, and costs around 55 EUR a month. The point of a portfolio
piece is to be looked at, and a live URL is easier to look at than a repository.

## Decision

Nothing billable. The cluster is created inside the CI runner and destroyed in
the same job. Images go to GitHub's registry. `terraform/azure` is written to
be applied and is never applied.

## Why

A monthly bill for a demonstration is a bad trade, and the free tier that would
have covered it has expired.

The consequence is smaller than it looks. What a reviewer can check — that the
charts are sound, that the Terraform is coherent, that the pipeline proves the
service actually serves traffic — is all visible either way. What is lost is a
URL, and a URL on a free tier that sleeps and whose database expires after
thirty days is a liability of its own: a dead link on a CV is worse than none.

What is gained is that the whole platform is reproducible by anyone in about
five minutes, on their own machine, at no cost. A cloud deployment that was
torn down cannot be shown at all; this one can be run.

## What it costs

`terraform/azure` has never been applied. It is validated, linted and
security-scanned on every push, and `terraform validate` catches a missing
argument but not a resource that Azure will refuse for a reason only Azure
knows. The README says so plainly rather than letting the reader assume
otherwise.

Applying it, once, against a subscription with credit is the remaining step —
`docs/runbook.md` has the sequence and the cost.
