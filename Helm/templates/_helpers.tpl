{{- define "giropops.fullname" -}}
{{ .Release.Name }}-{{ .Chart.Name }}
{{- end }}

{{- define "giropops.labels" -}}
app: {{ $.Chart.Name | default "giropops-app" }}
release: {{ $.Release.Name }}
env: {{ (index $.Values "global" "environment") | default "dev" }}
{{- end }}

{{- define "giropops.image" -}}
{{ .image | default "geforce8400gsd/giropops-senhas:latest}}
{{- end }}

{{- define "giropops.env" -}}
{{- if eq .component "giropops-senhas" }}
- name: REDIS_HOST
  value: "redis"
- name: REDIS_PORT
  value: "6379"
{{- end }}
{{- end }}

{{- define "giropops.serviceName" -}}
{{ $.Release.Name }}-{{ $.Chart.Name }}-{{ .component }}
{{- end }}

{{- define "giropops.servicePorts" -}}
{{- range .ports }}
- port: {{ .port }}
  targetPort: {{ .targetPort }}
  protocol: TCP
  name: {{ .name }}
  {{- if eq .serviceType "NodePort" }}
  nodePort: {{ .NodePort }}
  {{- end }}
{{- end }}
{{- end }}
