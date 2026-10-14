# act-runner (wrapper)

Wave 4. Runs Gitea Actions workflows for repos hosted on the hub Gitea. Deploys alongside Gitea in the `gitea` namespace.

## Required out-of-band state

The runner joins Gitea with a registration token obtained from the Gitea admin UI (`Site Administration → Actions → Runners → Create new Runner`). Until the ESO ClusterSecretStore is flipped on and the token lives in AWS SM / GCP SM, create the Secret manually:

```sh
kubectl -n gitea create secret generic gitea-runner-token \
  --from-literal=token=<token from Gitea admin UI>
```

The Pod will CrashLoop until this Secret exists. That's a known healthy-soon state on a fresh install, not a bug.

## Follow-ups

- `ExternalSecret` producing `gitea-runner-token` from the ESO AWS SM / GCP SM store.
- Separate pool of runners labelled for GPU workloads once GPUs are added to the hub.

## Upstream

- Chart: `gitea/act_runner`
- Pinned via `Chart.yaml` `dependencies`; refresh with `helm dependency update` locally and in CI before `ct lint`.
