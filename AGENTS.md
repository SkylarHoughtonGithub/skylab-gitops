# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

Everything Argo CD syncs: per-component wrapper charts, a chart that renders Applications in sync waves, per-cluster config files and workload definitions. This is the delivery hub of the Skylab platform — see `plan.md` for the full rework plan and current cross-repo status.

**Current state (2026-10-16):** bootstrap scaffolding, `skylab-apps` renderer (now with `sourceType: directory` support for raw-manifest workloads), CI pipeline (ct lint, helm-unittest, kubeconform), local k3d dev workflow (`Taskfile.yml` + `dev/`), **Renovate** for OCI/image/action bumps, wrapper charts through wave 6 (skipping wave 2) — `argo-cd` (-2), `cert-manager` + `external-secrets` (-1), `step-ca` + `step-issuer` + `trust-manager` + `kyverno` (0), `crossplane` + `crossplane-providers` (1), `kubevela` (3), `gitea` + `act-runner` (4), `kube-prometheus-stack` + `grafana` + `loki` + `alloy` + `tempo` + `sloth` (5), **`backstage` (6)** — plus the first wave-10 workload at `workloads/demo-service/`. The `backstage` wrapper pins `backstage/backstage@2.10.2` from `backstage.github.io/charts` and ships the `ghcr.io/skylarhoughtongithub/skylab-backstage:latest` image built in that repo's `image` workflow; env vars for OIDC + Gitea + K8s + Argo + Grafana default to empty strings so dev boots in degraded mode (sign-in falls back to guest, discovery logs a config error) and `ExternalSecret`-backed values can wire them per-env later. Postgres is the chart's bundled Bitnami one for dev; prod will swap for a Crossplane-managed instance. The demo workload is a hand-written KubeVela Application with two `webservice` components (nginx + `telemetrygen` → Tempo) and a `k8s-objects` component carrying a Certificate from the `step` StepClusterIssuer, a ServiceMonitor on the nginx Service, and a Sloth PrometheusServiceLevel; the Sloth SLI uses `up{namespace="demo-service"}` so the rule compiles even though `nginxdemos/hello` publishes no /metrics. Wave-0 wiring (StepClusterIssuer + ACME + trust-manager Bundle + ESO ClusterSecretStores + step-ca provisioner ExternalSecret) is in the charts as values-gated resources; the homelab cluster has the trust-manager Bundle flipped on (via `charts/trust-manager/values-homelab.yaml`), the rest remain off pending real inputs (KID, ACME email + solver, AWS SM path). Dev loop runs 15 enabled Applications now (cert-manager, external-secrets, kyverno, kubevela, step-ca, step-issuer, trust-manager, kube-prometheus-stack, grafana, loki, alloy, tempo, sloth, backstage, demo-service); controller-defaulted-field drift suppressed via fleet-wide `resource.customizations.ignoreDifferences` in `argocd-cm` for ClusterPolicy (Kyverno) and APIService (KubeVela). step-ca runs with its auto-generated admin provisioner (dev-only; no AWS SM path wired). StepClusterIssuer is created by a cert-manager PostSync bootstrap Job (`charts/cert-manager/templates/stepclusterissuer-bootstrap.yaml`) that waits for step-ca's config + certs ConfigMaps, extracts the KID from `ca.json`, and applies a StepClusterIssuer with `argocd.argoproj.io/compare-options: IgnoreExtraneous` so the dynamic value stays out of Git. The `workloads` AppProject was widened to allow `""/Namespace` so Argo CD can create the workload namespace via `CreateNamespace=true`; everything else a workload needs (Deployment, Service, Secret, Certificate, PrometheusServiceLevel) is namespaced and rendered downstream by KubeVela, not by Argo CD. act-runner needs a manually-created `gitea-runner-token` Secret in the `gitea` namespace to go healthy. Wave 2 (`skylab-crossplane` Configuration pin) deferred until the `skylab-crossplane` repo publishes an OCI package. `kubevela-defs` deferred to co-land with the first Backstage golden-path template — the shape of the demo-service Application is the baseline that template will match. Next: start **skylab-backstage** (build-order #3) so `demo-service` is regenerated from a golden-path template rather than written by hand. Production/homelab deployment deferred until that end-to-end is proven in dev.

## Layer

**Delivery (Argo CD).** Owns applying Git state to clusters and deciding which cluster gets what. Never touches resources rendered by KubeVela.

## Workflow

- `main` is protected: direct pushes are rejected. Branch for every change and open a PR (self-merge, 0 approvals required).
- No `Co-Authored-By` trailers in commit messages.
- Pin `targetRevision` everywhere; no `HEAD`.
- Local dev loop: `task dev:up` builds a k3d cluster, installs Argo CD, applies the root ApplicationSet, and reconciles the components enabled in `clusters/skylab-dev.yaml`. See `dev/README.md`.
- **Record progress in the same PR as the change.** Every substantive change (new wrapper chart, flipped-on component, infra fix, deferred follow-up resolved) updates the `## Current state` line below _and_ `plan.md`'s Status section. Stale status is treated as a bug, not documentation debt.

## Target repo shape

```
bootstrap/       # Argo CD values + root Application, run once
clusters/        # one file per cluster: labels, enabled components, overrides
charts/
  skylab-apps/   # renders Applications, AppProjects, sync waves
  <component>/   # one wrapper chart per component (cert-manager, kubevela, …)
dev/             # local k3d cluster: config, Argo CD cluster Secret, README
workloads/       # platform-owned KubeVela Applications
docs/adr/
Taskfile.yml     # dev loop + lint entry points
```

## Architecture decisions

**Wrapper chart per component.** Each `Chart.yaml` depends on the upstream chart and adds its own templates (Namespace, ExternalSecrets, ClusterIssuers). No platform-wide umbrella chart — each component keeps its own health and blast radius.

**Sync waves instead of appset sprawl.** `skylab-apps` renders one Application per enabled component with a wave annotation. The `argoproj.io_Application` health-check Lua must be in `argocd-cm` so waves wait on child Application health (Argo stopped assessing it in 1.8).

**Cluster-as-data.** One ApplicationSet with a cluster generator renders `skylab-apps` per cluster from labels on its Argo cluster Secret. Values layer: `values.yaml` → `values-<env>.yaml` → `clusters/<name>.yaml`, with `ignoreMissingValueFiles: true`.

**OCI promotion.** CI pushes changed charts to GHCR as OCI. Dev tracks chart paths on `main`; prod pins OCI versions. Promotion is a one-line PR.

## Sync wave reference

| Wave | Components |
| --- | --- |
| -2 | Argo CD (self-managed) |
| -1 | cert-manager, External Secrets Operator |
| 0 | step-ca, step-issuer, trust-manager, ClusterSecretStores, Kyverno |
| 1 | Crossplane and providers (AWS, GCP, Kubernetes) |
| 2 | skylab-crossplane Configuration package |
| 3 | KubeVela, kubevela-defs |
| 4 | Gitea, act_runner |
| 5 | Alloy, Prometheus, Loki, Tempo, Grafana, SLO rules |
| 6 | Backstage, Headlamp, SonarQube |
| 7 | Model gateway, HolmesGPT, kagent, MCP servers, tack-ai |
| 10 | Workloads |

## Cross-repo map

- `skylab-terraform` — AWS/GCP foundations: IAM, Roles Anywhere, buckets, qdevice
- `skylab-backstage` — catalog, templates, MCP actions
- `skylab-crossplane` — cloud-agnostic XRDs; this repo installs the OCI package at wave 2
- Gitea `platform/tenants` — scaffolder output; a second ApplicationSet watches it
- `tack-ai` — governed remediation agent; chart ships from here at wave 7
