# dev

Local k3d cluster that mirrors the hub-cluster bootstrap flow end-to-end: install Argo CD, register the cluster, apply the root ApplicationSet, let Argo reconcile the per-component wrappers.

## Prereqs

- `docker` (or compatible)
- [`k3d`](https://k3d.io)
- `kubectl`
- `helm`
- [`helm-unittest`](https://github.com/helm-unittest/helm-unittest) — `helm plugin install https://github.com/helm-unittest/helm-unittest`
- [`task`](https://taskfile.dev)

## Bring-up

```sh
task dev:up
```

This runs, in order:

1. `dev:cluster` — `k3d cluster create` using `dev/k3d-config.yaml` (1 server, 2 agents, traefik disabled).
2. `dev:argocd` — `helm install argocd argo/argo-cd` using `bootstrap/argocd-values.yaml`.
3. `dev:register` — applies `dev/argocd-cluster-secret.yaml` so the ApplicationSet selector picks up the cluster.
4. `dev:root` — applies `bootstrap/root-applicationset.yaml`.

Once up:

```sh
task dev:ui        # port-forward argocd-server to https://localhost:8080
task dev:password  # print the admin bootstrap password
task dev:status    # list Applications
```

## What syncs

`clusters/skylab-dev.yaml` enables a minimal baseline (cert-manager, external-secrets, kyverno, kubevela). Everything else stays off until its external prereqs are stubbed:

| Component | Why it's off in dev |
| --- | --- |
| `argo-cd` (self-manage) | enable after other components settle |
| `step-ca` / `step-issuer` / `trust-manager` | need a dev provisioner KID |
| `crossplane` / `crossplane-providers` | need cloud credentials |
| `gitea` / `act-runner` | act-runner needs the manual registration token |
| `kube-prometheus-stack` | works on k3d but heavy; opt in |

Flip components on by setting `enabled: true` under `components.<name>` in `clusters/skylab-dev.yaml`, commit, push — Argo picks it up on the next refresh.

## Teardown

```sh
task dev:down
```

## Lint / template

```sh
task lint                        # helm-unittest across every chart
task template -- cert-manager    # render one wrapper
```
