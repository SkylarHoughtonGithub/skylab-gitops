# trust-manager (wrapper)

Wave 0. Installs jetstack/trust-manager into the cert-manager namespace and (when enabled) distributes the step-ca root as a Bundle.

## Bundles

### `stepCA`

Sources `step-ca-certs` / `root_ca.crt` from the `step-ca` namespace and renders a ConfigMap into every namespace labelled `skylab.io/trust=enabled`. Default off — turn on per cluster once step-ca has published its root.

```yaml
bundles:
  stepCA:
    enabled: true
```

The resource carries `argocd.argoproj.io/sync-wave: "1"` so Argo waits for the step-ca Application before applying it.

## Upstream

- Chart: `jetstack/trust-manager`
- Pinned via `Chart.yaml` `dependencies`.
