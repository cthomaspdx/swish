{{/*
Expand the name of the chart.
*/}}
{{- define "dev-env.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Fully qualified app name.
*/}}
{{- define "dev-env.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Common labels.
*/}}
{{- define "dev-env.labels" -}}
helm.sh/chart: {{ printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
app.kubernetes.io/name: {{ include "dev-env.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- if .Values.team }}
swish.io/team: {{ .Values.team }}
{{- end }}
{{- if .Values.project }}
swish.io/project: {{ .Values.project }}
{{- end }}
{{- end }}

{{/*
Selector labels.
*/}}
{{- define "dev-env.selectorLabels" -}}
app.kubernetes.io/name: {{ include "dev-env.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}
