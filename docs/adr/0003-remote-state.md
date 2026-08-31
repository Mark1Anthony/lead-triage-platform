# 3. Remote state for Azure, local state for the cluster

**Status:** accepted

## Context

Terraform state records what exists. Two configurations here have different
answers to who else might be writing it.

## Decision

`terraform/azure` uses an Azure Storage backend. `terraform/cluster` keeps
state on disk.

## Why

The Azure stack is long-lived and applied from more than one place — a
workstation and a pipeline. Two applies against separate local state files
would produce two sets of resources and no way to reconcile them. The storage
backend also holds a lease for the duration of an apply, so a second one waits
instead of interleaving.

The cluster configuration describes a cluster that is created and destroyed
inside a single CI job. There is no second writer, no next run that inherits
anything, and nothing that outlives the job. A remote backend would add a
dependency for no benefit.

The storage account is created by `scripts/bootstrap.sh` and is not managed by
the configuration that stores its state there — a configuration cannot create
its own backend.

## State is sensitive

State holds generated passwords in clear text. Both `random_password` values
and everything read out of Key Vault are in there. The storage account is
therefore private, encrypted, and versioned; local state files are gitignored.
Anyone who can read state can read the database password — that is a property
of Terraform, not of this setup, and it is the reason state is treated as a
credential rather than as a build artifact.
