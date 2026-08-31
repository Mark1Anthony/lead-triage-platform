variable "kubeconfig_path" {
  description = "Path to the kubeconfig holding the target cluster."
  type        = string
  default     = "~/.kube/config"
}

variable "kube_context" {
  description = "Context to use. kind names its contexts kind-<cluster>."
  type        = string
  default     = "kind-lead-triage"
}

variable "namespace" {
  description = "Namespace everything is deployed into."
  type        = string
  default     = "lead-triage"
}

variable "image_repository" {
  description = "Container image for the application."
  type        = string
  default     = "ghcr.io/mark1anthony/lead-triage"
}

variable "image_tag" {
  description = <<-EOT
    Image tag to deploy. CI passes the tag it just built and pushed, so a
    rollout always refers to one specific image rather than to a moving tag.
  EOT
  type        = string
  default     = "main"
}

variable "ingress_host" {
  description = "Hostname the ingress answers on."
  type        = string
  default     = "lead-triage.localtest.me"
}

variable "replicas" {
  description = "Replicas when autoscaling is off, and the floor when it is on."
  type        = number
  default     = 2

  validation {
    condition     = var.replicas >= 1
    error_message = "At least one replica, or there is nothing to serve traffic."
  }
}

variable "network_policy_enabled" {
  description = <<-EOT
    Whether the charts install their NetworkPolicies. On by default, because a
    cluster that enforces them is the normal case. CI turns it off: kind's CNI
    accepts the policies and then drops traffic they permit.
  EOT
  type        = bool
  default     = true
}
