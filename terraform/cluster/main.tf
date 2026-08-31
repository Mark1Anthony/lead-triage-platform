locals {
  # One place that decides how the application addresses the database. The
  # hostname is the headless service the postgres chart creates, resolved
  # inside the namespace.
  database_url = format(
    "postgresql://%s:%s@%s:5432/%s",
    local.db_username,
    urlencode(random_password.postgres.result),
    helm_release.postgres.name,
    local.db_name,
  )

  db_name     = "leads"
  db_username = "leads"
}

resource "kubernetes_namespace" "this" {
  metadata {
    name = var.namespace
    labels = {
      "app.kubernetes.io/part-of" = "lead-triage"
    }
  }
}

# ─── Secrets ──────────────────────────────────────────────────────
#
# Generated here rather than committed or passed in. Terraform keeps them in
# state, which is why state is treated as sensitive - see docs/adr/0003.

resource "random_password" "postgres" {
  length = 32
  # The password ends up inside a URL. Restricting the alphabet to what is safe
  # there would weaken it, so it is percent-encoded at the point of use instead.
  special = true
}

resource "random_password" "api_token" {
  length  = 48
  special = false # travels in an HTTP header
}

resource "kubernetes_secret" "postgres" {
  metadata {
    name      = "postgres-credentials"
    namespace = kubernetes_namespace.this.metadata[0].name
  }

  data = {
    password = random_password.postgres.result
  }
}

resource "kubernetes_secret" "app" {
  metadata {
    name      = "lead-triage-secrets"
    namespace = kubernetes_namespace.this.metadata[0].name
  }

  data = {
    # Setting DATABASE_URL is what makes the app use Postgres instead of its
    # SQLite fallback. If this secret is missing the app still starts, which is
    # why the smoke test asserts on the backend it reports rather than on a 200.
    DATABASE_URL      = local.database_url
    LEAD_TRIAGE_TOKEN = random_password.api_token.result
  }
}

# ─── Releases ─────────────────────────────────────────────────────

resource "helm_release" "postgres" {
  name      = "postgres"
  chart     = "${path.module}/../../charts/postgres"
  namespace = kubernetes_namespace.this.metadata[0].name

  # Wait for the pod to pass its readiness probe. Without this the application
  # release starts against a database that is not accepting connections yet.
  wait    = true
  timeout = 300

  values = [yamlencode({
    auth = {
      database       = local.db_name
      username       = local.db_username
      existingSecret = kubernetes_secret.postgres.metadata[0].name
    }
    networkPolicy = {
      enabled = var.network_policy_enabled
    }
  })]
}

resource "helm_release" "app" {
  name      = "lead-triage"
  chart     = "${path.module}/../../charts/lead-triage"
  namespace = kubernetes_namespace.this.metadata[0].name

  wait    = true
  timeout = 300

  values = [yamlencode({
    image = {
      repository = var.image_repository
      tag        = var.image_tag
    }
    replicaCount   = var.replicas
    existingSecret = kubernetes_secret.app.metadata[0].name
    ingress = {
      enabled   = true
      className = "nginx"
      host      = var.ingress_host
    }
    networkPolicy = {
      enabled = var.network_policy_enabled
    }
  })]

  depends_on = [helm_release.postgres]
}
