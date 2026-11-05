# 0004. Promotion by OCI chart version

**Status:** Accepted
**Date:** 2026-11-05

## Context

Skylab deploys to multiple clusters ([ADR-0003](0003-cluster-as-data.md)) with different change cadences: dev should see fleet-wide changes immediately; prod should move only after an explicit human decision, and that decision should be reviewable and auditable. Each wrapper chart ([ADR-0001](0001-wrapper-charts-per-component.md)) is independently versioned, so the promotion unit is a single chart's version — not a release-wide tag.

Common Argo CD promotion models:

1. **Branch-per-environment.** `main` deploys to dev; a `prod` branch (or an `env/prod` branch) deploys to prod. Promotion is a merge from `main` into `prod`.
2. **Commit-SHA tracking.** Prod tracks a specific commit SHA on `main`; promotion is bumping the SHA pin.
3. **OCI chart versioning.** CI publishes each changed wrapper chart to GHCR as an OCI artifact. Dev tracks chart paths on `main`; prod pins specific OCI chart versions.

## Decision

**Adopt OCI chart versioning.** On every merge to `main`, CI runs `ct lint` (which enforces a `Chart.yaml` version bump for any file touched in a chart directory), then pushes the new version to GHCR as an OCI artifact:

```
oci://ghcr.io/skylarhoughtongithub/charts/cert-manager:1.3.2
```

Per-cluster `clusters/<name>.yaml` chooses the deployment mode for each component independently:

- **Dev** sets `source: path` (or omits `source`), so `skylab-apps` renders the Application pointing at `charts/<name>/` on `main`. PRs land in dev immediately after merge.
- **Prod** sets `source: oci` and `version: "1.3.2"`, so `skylab-apps` renders the Application pointing at a pinned OCI version. Promotion from dev to prod is a one-line PR that bumps that version.

## Alternatives considered

**Branch-per-environment.** Rejected because:

- Parallel histories drift; a `git log` on `prod` doesn't match `main`, so the mental model of "what's where" is split across two trees.
- Merge conflicts are a real risk every time a cherry-pick skips commits.
- Rollback is a revert on a separate branch, which may conflict with the main branch's current state.
- The branch itself has no version semantics — "what's deployed to prod right now" is "whatever HEAD of the prod branch happens to be," which is harder to audit than a pinned version.

**Commit-SHA tracking.** Rejected because:

- Argo CD `targetRevision: <sha>` is a working primitive, but the SHA is not a semantic version — two SHAs that differ by an unrelated typo in `plan.md` are indistinguishable from two SHAs that change a chart template.
- Promotion diffs include unrelated changes to other charts in the same commit. Chart-level change isolation is lost.
- Rollback to a known-good version requires finding a specific SHA, not picking a version number.

**Helm repo + `index.yaml`.** Rejected because:

- GHCR is already a hard dependency for container images across every repo; adding a second artifact host (ChartMuseum, GH Pages, S3) doubles the operational surface.
- Helm OCI support has been stable since Helm 3.8 (2022) and is the direction Helm itself is going.
- OCI gets us signing + SBOMs + provenance for free via cosign, which an `index.yaml`-based repo would require bolting on separately.

## Consequences

**Positive.** Promotion is a code change, reviewable like any other PR. "What's in prod" is a grep for `version:` in `clusters/prod.yaml`. Rollback is a version bump backwards, not a destructive revert. Dev stays fast because chart-path tracking means PRs land immediately; prod stays stable because nothing moves without a version pin bump. OCI gives us a clean handoff point to add cosign signatures and SBOM attestations at publish time ([skylab-crossplane](https://github.com/SkylarHoughtonGithub/skylab-crossplane) is the model: cosign-signed packages, SBOM attested).

**Negative.** Two deployment modes to understand: path-tracking for dev, version-pinned for prod. A contributor touching a chart must know which clusters consume it on `path` (change lands immediately) and which consume it on `oci` (change waits for an explicit promotion PR). The `ct lint` version-bump enforcement means even values-only changes require a `Chart.yaml` version bump — more mechanical ceremony per PR.

**Neutral.** Dev could pin OCI versions too (making the model uniform at the cost of slower dev feedback). The path/OCI split is a per-cluster policy choice, not a platform-wide constraint. `clusters/skylab-dev.yaml` and `clusters/homelab.yaml` can both pin OCI the day it matters; today it doesn't.

## Status of implementation

OCI push to GHCR on `main` is **deferred CI work** as of 2026-11-05 ([`plan.md#deferred-ci-work-in-skylab-gitops`](../../plan.md)). The decision is Accepted; the workflow that enacts it has not landed yet. Dev currently runs on `path` tracking; no cluster uses the `oci` source mode yet. When the workflow lands, the first version bumps will set the starting point for each chart's OCI series.
