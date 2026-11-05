# 0003. Cluster-as-data instead of path-based environments

**Status:** Accepted
**Date:** 2026-11-05

## Context

Skylab is a fleet: a homelab hub cluster plus (eventually) EKS and GKE spoke clusters, with the dev k3d cluster as a fourth target used only locally. Every cluster gets a different subset of the ~22 platform components: the hub runs the full control plane (Argo CD, Crossplane, Backstage, Gitea, observability backends, AI layer); spokes run a lean profile (Alloy, ESO, cert-manager, KubeVela, Kyverno). Per-cluster values differ too: cluster name, region, provisioner KIDs, credentials paths.

Two placement models compete in the Argo CD ecosystem:

1. **Path-based environments.** A folder per environment (`envs/dev/`, `envs/prod/`), an ApplicationSet per folder, per-env `values-<env>.yaml` files. Adding a cluster means creating a folder and copying ApplicationSet YAML.
2. **Cluster-as-data.** One ApplicationSet uses a cluster generator; each cluster is an Argo CD cluster Secret labeled with metadata; the ApplicationSet renders per cluster based on label selection and reads per-cluster config from a data file.

## Decision

**Adopt cluster-as-data.** A single root ApplicationSet (`bootstrap/root-applicationset.yaml`) uses Argo CD's cluster generator. Each cluster is represented by an Argo CD cluster Secret with labels `cloud`, `region`, `env`, `role` (plus any application-specific labels). The ApplicationSet renders `charts/skylab-apps/` once per matching cluster, passing per-cluster values through a three-layer file chain:

```
charts/skylab-apps/values.yaml     # fleet-wide defaults
charts/skylab-apps/values-<env>.yaml  # per-environment overlay (env from cluster label)
clusters/<cluster-name>.yaml       # per-cluster overrides
```

`ignoreMissingValueFiles: true` means a new cluster only needs the files that actually contain overrides. A new cluster is added in two steps:

1. Create its Argo CD cluster Secret with the right labels.
2. Create `clusters/<cluster-name>.yaml` listing the enabled components and any overrides.

No ApplicationSet changes. No new folders. No copied YAML.

## Alternatives considered

**Path-based environments.** Rejected for three reasons:

- *Scales poorly with cluster count.* Each new cluster is a folder + an ApplicationSet copy; renaming a cluster is a destructive git operation; splitting dev into dev-a / dev-b churns several files.
- *Promotion is YAML duplication.* Moving a component from dev to prod means editing both `envs/dev/` and `envs/prod/` ApplicationSets; forgetting one is a real outage mode.
- *Cluster identity isn't data.* Labels on the Argo CD cluster Secret are the only durable cluster identity; a folder path is a secondary and lossy representation of it.

**Hybrid (ApplicationSet per env + cluster generator inside).** Rejected because it reintroduces the folder-per-env problem while keeping the cluster-generator benefits. Not a stable midpoint — complexity of both models, discipline of neither.

## Consequences

**Positive.** Adding a cluster is two files. Fleet-wide policy changes (e.g. "enable Kyverno everywhere") land by editing `values.yaml` once. Promotion from dev to prod is editing one line in `clusters/prod.yaml`, not synchronizing two folders. Cluster metadata (labels) is the single source of truth for both placement and config — one data model, consulted in two places.

**Negative.** "What's deployed to cluster X" is not a file listing in a folder — it's the result of rendering `skylab-apps` against the cluster's values stack. Inspection requires running `helm template` or using Argo CD's UI. The CI pipeline mitigates this: `kubeconform` renders `skylab-apps` once per cluster values file in `clusters/` and validates the output.

**Neutral.** Cluster metadata lives in two places: the Argo CD cluster Secret labels (used for `generator.clusters.selector`) and `clusters/<name>.yaml` (used for values). These serve different purposes — selection vs configuration — so the duplication is deliberate, not accidental. If the two drift (label says `env: prod` but the file is named `clusters/dev.yaml`), the cluster won't match the selector it expects. Convention keeps them aligned; CI could enforce it in the future.
