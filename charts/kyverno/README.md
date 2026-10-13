# kyverno (wrapper)

Wave 0. Installs Kyverno plus three base ClusterPolicies:

| Policy | What it checks |
| --- | --- |
| `disallow-latest-tag` | Images must have an explicit tag; `:latest` and tag-less are rejected |
| `disallow-privileged-containers` | `securityContext.privileged: true` is rejected |
| `require-owner-label` | Deployments/StatefulSets/DaemonSets must carry an `owner` label |

## Enforcement mode

Policies start in `Audit` mode (controlled by `policies.action` in `values.yaml`). Flip to `Enforce` once existing workloads are compliant.

## Exclusions

The policies skip `kube-system`, `kube-public`, `kube-node-lease`, `kyverno` (self-admission loop) and `argocd`. Add more namespaces via `excludedNamespaces` in values.

## Upstream

- Chart: `kyverno/kyverno`
- Pinned via `Chart.yaml` `dependencies`.
