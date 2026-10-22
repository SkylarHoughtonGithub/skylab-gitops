{{/* Short component name used for resource names + labels. */}}
{{- define "aws-signing-helper.name" -}}
aws-signing-helper
{{- end -}}

{{- define "aws-signing-helper.labels" -}}
app.kubernetes.io/name: {{ include "aws-signing-helper.name" . }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
skylab.io/component: aws-signing-helper
{{- end -}}

{{/* Rendered download URL with the pinned version substituted. */}}
{{- define "aws-signing-helper.downloadUrl" -}}
{{- $v := .Values.awsSigningHelper.version -}}
{{- $t := .Values.awsSigningHelper.downloadUrlTemplate -}}
{{- $t | replace "{version}" $v -}}
{{- end -}}
