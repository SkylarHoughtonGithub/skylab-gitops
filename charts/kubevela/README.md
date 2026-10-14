# kubevela (wrapper)

Wave 3. Installs KubeVela (`vela-core`) plus a Namespace with Skylab labels. This is the Application API layer — a workload-owner writes a KubeVela `Application` referencing a ComponentDefinition + Traits, and KubeVela renders the underlying Kubernetes resources.

## What's intentionally not here yet

`charts/kubevela-defs` — the ComponentDefinitions (`go-service`, `ai-agent`, `postgres`, `bucket`) and TraitDefinitions (`observability`, `route`, `canary`, `autoscale`, `secrets`, `model-access`) — is deferred until the first concrete consumer exists. The plan is to co-land `kubevela-defs` with the first Backstage golden-path template (`skylab-backstage`), so the exact vocabulary is driven by a real workload rather than guessed up front. `postgres` and `bucket` specifically depend on XRDs from `skylab-crossplane`, which hasn't been built yet.

## Follow-ups

- Switch the admission webhook cert to a cert-manager Certificate issued via `StepClusterIssuer` once wave-0 wiring is turned on at the cluster level.
- Flip `vela-core.serviceMonitor.enabled: true` in wave 5 once kube-prometheus-stack is installed.

## Upstream

- Chart: `kubevela/vela-core`
- Pinned via `Chart.yaml` `dependencies`; refresh with `helm dependency update` locally and in CI before `ct lint`.
