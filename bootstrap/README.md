# Bootstrap

One-time install of Argo CD on an empty cluster. From then on Argo CD syncs itself and everything else.

## Prerequisites

- `kubectl` pointed at the target cluster
- `helm`

## Install Argo CD (wave -2)

```sh
# Pin the chart version — bump deliberately via a PR.
ARGO_CD_CHART_VERSION=7.8.0

kubectl create namespace argocd
helm repo add argo https://argoproj.github.io/argo-helm
helm repo update
helm install argocd argo/argo-cd \
  --namespace argocd \
  --version "$ARGO_CD_CHART_VERSION" \
  -f argocd-values.yaml
```

## Register the cluster

Each cluster that Argo CD manages is an Argo CD cluster Secret with labels. The hub cluster also needs its own Secret so the root ApplicationSet selects it.

Required labels:

| Label | Example | Purpose |
| --- | --- | --- |
| `skylab.io/managed` | `"true"` | ApplicationSet selector |
| `skylab.io/env` | `dev` or `prod` | Overlay via `values-<env>.yaml` |
| `skylab.io/cloud` | `homelab`, `aws`, `gcp` | Cloud-specific wiring |
| `skylab.io/role` | `hub` or `spoke` | Hub/spoke component selection |

For the hub (in-cluster):

```sh
kubectl label secret -n argocd <cluster-secret-name> \
  skylab.io/managed=true \
  skylab.io/env=dev \
  skylab.io/cloud=homelab \
  skylab.io/role=hub
```

## Apply the root ApplicationSet

```sh
kubectl apply -f root-applicationset.yaml
```

This renders a `skylab-apps-<cluster>` Application per managed cluster. Each of those renders N child Applications — one per enabled component in `charts/skylab-apps/values.yaml`, overlaid by `values-<env>.yaml` and `clusters/<cluster>.yaml`.

## Verify

- `kubectl get applicationsets -n argocd` — the root should be `skylab-apps`.
- `kubectl get applications -n argocd` — one `skylab-apps-<cluster>` plus one per enabled component.
- In the Argo CD UI, components with lower wave numbers sync first; higher waves wait on health.
