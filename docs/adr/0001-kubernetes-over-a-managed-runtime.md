# 1. Kubernetes rather than a managed container runtime

**Status:** accepted

## Context

lead-triage is one stateless web process and one database. Azure Container
Apps, App Service or Render all run that with far less machinery than
Kubernetes — the application is already deployed on Render and needs none of
this to work.

## Decision

Kubernetes anyway, with Helm charts and an ingress controller.

## Why

The workload does not need it. The reason is what the platform has to
demonstrate: rollouts that can be paused and rolled back, probes that gate
traffic separately from restarts, autoscaling on a signal, disruption budgets
that survive a node drain, network policy between workloads. A managed runtime
provides several of those and hides all of them, which is fine for shipping and
useless for showing that they are understood.

The job descriptions this targets ask for Kubernetes by name.

## What it costs

More moving parts than the problem justifies, and the honest version of this
decision is that a real team running one small service should choose the
managed runtime. That trade is stated here rather than glossed over, because
"we used Kubernetes because it is Kubernetes" is the wrong answer in an
interview and the right answer is knowing when not to.
