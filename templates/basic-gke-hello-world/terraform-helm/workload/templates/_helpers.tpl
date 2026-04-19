{{- define "hello-world.name" -}}
{{- .Chart.Name | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "hello-world.fullname" -}}
{{- printf "%s-%s" .Release.Name .Chart.Name | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "hello-world.labels" -}}
helm.sh/chart: {{ .Chart.Name }}-{{ .Chart.Version }}
{{ include "hello-world.selectorLabels" . }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
project: gcp-template-forge
template: basic-gke-hello-world
{{- end }}

{{- define "hello-world.selectorLabels" -}}
app.kubernetes.io/name: {{ include "hello-world.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}
