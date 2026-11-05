# 0007. One GitOps repo on GitHub; tenants live on Gitea

**Status:** Accepted
**Date:** 2026-11-05

## Context

GitOps makes Git the source of truth. That raises an immediate question: *which Git, and how many repos?*

Skylab has two kinds of state that could live in Git:

- **Platform state.** Wrapper charts, cluster config, bootstrap Applications, platform-owned workloads. Changed by maintainers through reviewed PRs. Low write frequency, high trust level, high audit value.
- **Tenant state.** Scaffolder output from Backstage golden paths — KubeVela Applications, `Postgres`/`Bucket` XR claims. Written by any user who runs a template. High write frequency, lower trust level, mostly generated.

Options on the table:

1. **One repo, everything.** Platform charts and tenant scaffolder output both land in `skylab-gitops` on GitHub.
2. **One repo per environment.** `skylab-prod`, `skylab-dev`, etc. — rejected under [ADR-0003](0003-cluster-as-data.md) (cluster-as-data obviates environment folders and by extension environment repos).
3. **One repo per tenant.** A new repo per app.
4. **Two sources.** Platform state on GitHub; tenant scaffolder output on a separate Git source (Gitea, in-cluster).

## Decision

**Two sources.** Platform state in **`skylab-gitops`** on GitHub, public. Tenant scaffolder output in **`platform/tenants`** on **Gitea** running in-cluster (wave 4).

Two ApplicationSets watch two sources:

- The root ApplicationSet (cluster generator) watches this repo and renders `skylab-apps` per cluster.
- A second ApplicationSet (git-files generator) watches `platform/tenants` on Gitea and renders tenant KubeVela Applications.

Backstage's scaffolder writes to Gitea via its PR action; a human (or policy) approves the PR; Argo CD on the hub picks up the merged file.

## Alternatives considered

**One repo for everything.** Rejected for three reasons:

- *Audit signal dilution.* Platform PRs (interesting, infrequent, high-impact) get buried under tenant PRs (routine, frequent, low-impact). A recruiter or new engineer reading `git log` sees noise.
- *Write-path friction.* Backstage writing to a public GitHub repo requires a token with real write permissions on a public surface — a secret management burden that gets heavier as more MCP actions are added.
- *Different ACLs.* Platform state wants public read (portfolio value). Tenant state is dev-only churn that doesn't need to be world-visible.

**One repo per tenant.** Rejected because it explodes operational surface — a repo per app, each with its own ApplicationSet rule or git-files generator pattern. Breaks the "add a tenant without platform changes" property that Backstage templates aim for.

**Platform on Gitea too.** Rejected because the platform is the portfolio artifact; it lives on GitHub for visibility. Gitea is the right home for scaffolder output precisely because that output is a byproduct, not a deliverable.

## Consequences

**Positive.** Platform `git log` stays signal-dense. Backstage's write path points at Gitea, so no GitHub tokens with write scope are needed inside the cluster. The two ACL models are explicit: GitHub (public read, maintainer write), Gitea (authenticated read, Backstage write). Promotion stories for platform and tenant diverge cleanly — platform promotes by OCI version ([ADR-0004](0004-oci-chart-promotion.md)), tenant promotes by moving a label ([ADR-0008](0008-label-placement-now-ocm-later.md)).

**Negative.** Two GitOps sources to debug. "Why did this Application appear?" requires knowing whether to look at `skylab-gitops` or `platform/tenants` — mitigated by naming: platform Applications are `skylab-apps-<cluster>-<component>`, tenant Applications are `<tenant>-<app>`. Gitea becomes a hard dependency for tenant onboarding; if Gitea is down, Backstage templates can't publish.

**Neutral.** The split is reversible in one direction. If Backstage gains the ability to write to GitHub safely, the two sources could collapse to one — ApplicationSet selectors would just change. The split is not reversible the other way without migrating public history into a private repo, which is unlikely to be a real need.
