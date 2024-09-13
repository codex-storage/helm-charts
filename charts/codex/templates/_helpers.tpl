{{/*
Expand the name of the chart.
*/}}
{{- define "codex.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "codex.fullname" -}}
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
Create chart namespace.
*/}}
{{- define "codex.namespace" -}}
{{ default .Release.Namespace .Values.namespaceOverride }}
{{- end }}

{{/*
Create ingress name.
*/}}
{{- define "codex.ingress.name" -}}
{{- if .Values.ingress.fullnameOverride }}
{{- .Values.ingress.fullnameOverride }}
{{- else }}
{{- include "codex.fullname" . }}
{{- end }}
{{- end }}

{{- define "codex.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels.
*/}}
{{- define "codex.labels" -}}
helm.sh/chart: {{ include "codex.chart" . }}
{{ include "codex.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels.
*/}}
{{- define "codex.selectorLabels" -}}
app.kubernetes.io/name: {{ include "codex.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use.
*/}}
{{- define "codex.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "codex.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Role name.
*/}}
{{- define "codex.clusterRole.name" -}}
{{ print (include "codex.namespace" .) "-" (include "codex.serviceAccountName" .) }}
{{- end }}

{{- define "codex.role.name" -}}
{{ include "codex.serviceAccountName" . }}
{{- end }}

{{/*
StatefulSets count.
*/}}
{{- define "codex.statefulSetCount" -}}
{{- if eq (include "codex.service.nodeport.enabled" .) "true" }}
{{- .Values.replica.count }}
{{- else }}
{{- 1 }}
{{- end }}
{{- end }}

{{/*
Replica count.
*/}}
{{- define "codex.replica.count" -}}
{{- if eq (int (include "codex.statefulSetCount" .)) 1 }}
{{- .Values.replica.count }}
{{- else }}
{{- 1 }}
{{- end }}
{{- end }}

{{/*
Enable NodePort service.
*/}}
{{- define "codex.service.nodeport.enabled" -}}
{{- if has "nodeport" .Values.service.type }}
{{- "true" }}
{{- else }}
{{- "false" }}
{{- end }}
{{- end }}

{{/*
Enable initEnv container.
For single replica, initEnv container is enabled only if initEnv.enabled is set to true.
For multiple replicas, initEnv container is enabled if initEnv.enabled or we have multiple StatefulSets with NodePort service enabled.
*/}}
{{- define "codex.initEnv.enabled" -}}
{{- if or .Values.initEnv.enabled (eq (include "codex.service.nodeport.enabled" .) "true") }}
{{- "true" }}
{{- else }}
{{- "false" }}
{{- end }}
{{- end }}

{{/*
Mount CODEX_ETH_PRIVATE_KEY.
*/}}
{{- define "codex.env.ethPrivateKey.mount" -}}
{{- if .Values.codex.env.CODEX_ETH_PRIVATE_KEY }}
{{- "true" }}
{{- else }}
{{- "false" }}
{{- end }}
{{- end }}
