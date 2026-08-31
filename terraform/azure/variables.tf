variable "name" {
  description = "Prefix for every resource name."
  type        = string
  default     = "leadtriage"

  validation {
    condition     = can(regex("^[a-z][a-z0-9]{2,15}$", var.name))
    error_message = "Lowercase letters and digits, 3-16 characters. Storage and registry names allow nothing else."
  }
}

variable "environment" {
  description = "Environment this stack represents."
  type        = string
  default     = "prod"
}

variable "location" {
  description = "Azure region. germanywestcentral keeps data in Germany."
  type        = string
  default     = "germanywestcentral"
}

variable "kubernetes_version" {
  description = "AKS control plane version."
  type        = string
  default     = "1.31"
}

variable "node_count" {
  description = "Nodes in the system pool."
  type        = number
  default     = 2
}

variable "node_size" {
  description = <<-EOT
    VM size for the node pool. The default is the smallest size that still
    supports the AKS system pool requirements; it is also the single biggest
    line on the bill, which is why it is a variable and not a constant.
  EOT
  type        = string
  default     = "Standard_B2s"
}

variable "postgres_sku" {
  description = "Burstable tier - this workload is idle most of the time."
  type        = string
  default     = "B_Standard_B1ms"
}

variable "monthly_budget_eur" {
  description = "Spend that triggers an alert. Not a hard cap: Azure has none."
  type        = number
  default     = 20
}

variable "budget_alert_email" {
  description = "Where budget alerts go."
  type        = string
  default     = ""
}

variable "github_repository" {
  description = "owner/repo allowed to deploy this stack through OIDC."
  type        = string
  default     = "Mark1Anthony/lead-triage-platform"
}

variable "tags" {
  description = "Applied to everything, so a stray resource can be traced back."
  type        = map(string)
  default = {
    project    = "lead-triage"
    managed-by = "terraform"
  }
}
