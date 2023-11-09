{{/*
Expand the name of the chart.
*/}}
{{- define "vertica-kafka-scheduler.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "vertica-kafka-scheduler.fullname" -}}
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
Create a default fully qualified name for the initializer pod.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "vertica-kafka-scheduler.initializer-fullname" -}}
{{- if .Values.fullnameOverride }}
{{- cat .Values.fullnameOverride "-initializer" | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- printf "%s-initializer" .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s-initializer" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Create a default fully qualified name for the configMap.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "vertica-kafka-scheduler.configmap-fullname" -}}
{{- if .Values.conf.configMapName }}
{{- .Values.conf.configMapName }}
{{- else if .Values.fullnameOverride }}
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
Create chart name and version as used by the chart label.
*/}}
{{- define "vertica-kafka-scheduler.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "vertica-kafka-scheduler.labels" -}}
helm.sh/chart: {{ include "vertica-kafka-scheduler.chart" . }}
{{ include "vertica-kafka-scheduler.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "vertica-kafka-scheduler.selectorLabels" -}}
app.kubernetes.io/name: {{ include "vertica-kafka-scheduler.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "vertica-kafka-scheduler.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "vertica-kafka-scheduler.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Generate te value for VKCONFIG_JVM_OPTS based on values.yaml
*/}}
{{- define "vertica-kafka-scheduler.jvmOpts" -}}
{{- if .Values.tls.enabled -}}
"-Djavax.net.ssl.trustStore={{ .Values.tls.trustStoreMountPath }}/{{ .Values.tls.trustStoreSecretKey }} -Djavax.net.ssl.keyStore={{ .Values.tls.keyStoreMountPath }}/{{ .Values.tls.keyStoreSecretKey }} -Djavax.net.ssl.keyStorePassword={{ .Values.tls.keyStorePassword }} {{ .Values.jvmOpts }}"
{{- else -}}
{{ default (quote "") .Values.jvmOpts }}
{{- end }}
{{- end }}
