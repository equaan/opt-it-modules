{{/*
Expand the name of the chart.
*/}}
{{- define "${{ values.client_name }}.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "${{ values.client_name }}.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "${{ values.client_name }}.labels" -}}
helm.sh/chart: {{ include "${{ values.client_name }}.name" . }}-{{ .Chart.Version }}
{{ include "${{ values.client_name }}.selectorLabels" . }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
managed-by: opt-it-backstage
{{- end }}

{{/*
Selector labels
*/}}
{{- define "${{ values.client_name }}.selectorLabels" -}}
app.kubernetes.io/name: {{ include "${{ values.client_name }}.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}
