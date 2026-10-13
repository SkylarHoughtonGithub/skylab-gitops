# skylab-apps

Renders Argo CD AppProjects and one Application per enabled component. Installed per cluster by the root ApplicationSet in `bootstrap/`.

## Values layering

Each `skylab-apps` instance for a cluster is rendered with:

1. `values.yaml` — defaults, including the component list
2. `values-<env>.yaml` — env-level overlay (e.g. `values-dev.yaml`, `values-prod.yaml`)
3. `clusters/<cluster>.yaml` — per-cluster overlay (relative path from this chart)

`ignoreMissingValueFiles: true` so overlays are optional.

## Enabling a component on a cluster

Edit `clusters/<cluster>.yaml`:

```yaml
components:
  cert-manager:
    enabled: true
```

The component's Application gets a sync-wave annotation from `components.<name>.wave`.

## AppProjects

- `platform` — platform-owned components, broad whitelist
- `tenants` — scaffolder output from Gitea; namespaced to `core.oam.dev` (KubeVela)
- `workloads` — platform-owned KubeVela Applications in this repo
