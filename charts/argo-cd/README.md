# argo-cd (wrapper)

Wave -2. Argo CD self-manages through this wrapper after the one-time bootstrap install.

## Flow

1. `bootstrap/argocd-values.yaml` installs Argo CD once with `helm install`.
2. `bootstrap/root-applicationset.yaml` is applied; it renders `skylab-apps-<cluster>` Applications.
3. `skylab-apps` renders a child Application for this chart with sync-wave `-2`.
4. From then on, Argo CD syncs its own configuration from `charts/argo-cd/values.yaml`.

## Keep in sync

`charts/argo-cd/values.yaml` and `bootstrap/argocd-values.yaml` must be semantically identical, so the first self-sync is a no-op. Change one, change the other.

## Upstream

- Chart: `argoproj/argo-cd`
- Pinned via `Chart.yaml` `dependencies`; refresh with `helm dependency update` locally and in CI before `ct lint`.
