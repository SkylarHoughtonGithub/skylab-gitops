{{/* Chart path for a component, with a sensible default. */}}
{{- define "skylab-apps.componentPath" -}}
{{- $name := .name -}}
{{- $comp := .component -}}
{{- default (printf "charts/%s" $name) $comp.path -}}
{{- end -}}

{{/* Namespace for a component, with a sensible default. */}}
{{- define "skylab-apps.componentNamespace" -}}
{{- $name := .name -}}
{{- $comp := .component -}}
{{- default $name $comp.namespace -}}
{{- end -}}
