{{/*
Name of the release, truncated to what Kubernetes accepts for a label value.
*/}}
{{- define "lead-triage.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "lead-triage.fullname" -}}
{{- if contains .Chart.Name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name .Chart.Name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}

{{/*
Labels every object carries. app.kubernetes.io/* are the names kubectl,
dashboards and the Prometheus operator already know how to group by.
*/}}
{{- define "lead-triage.labels" -}}
helm.sh/chart: {{ printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" }}
{{ include "lead-triage.selectorLabels" . }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels are a strict subset: they go into Deployment.spec.selector,
which is immutable. Anything that changes between releases - the version, the
chart revision - must stay out of here or upgrades fail.
*/}}
{{- define "lead-triage.selectorLabels" -}}
app.kubernetes.io/name: {{ include "lead-triage.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{- define "lead-triage.image" -}}
{{- printf "%s:%s" .Values.image.repository (default .Chart.AppVersion .Values.image.tag) }}
{{- end }}
