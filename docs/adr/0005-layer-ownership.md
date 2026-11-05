# 0005. Layer ownership: Argo CD, Crossplane, KubeVela

**Status:** Accepted
**Date:** 2026-11-05

## Context

Skylab uses three systems with overlapping capabilities:

- **Argo CD** can sync any Kubernetes resource — a Helm release, a raw manifest, a Crossplane XR, a KubeVela Application.
- **Crossplane** can provision cloud resources, but also — via `provider-helm` and `provider-kubernetes` — Helm releases and arbitrary Kubernetes objects.
- **KubeVela** emits Kubernetes resources from an Application spec: Deployments, Services, Certificates, ServiceMonitors, even Crossplane XRs.

Without strict boundaries, the systems overlap and fight. Argo CD will try to reconcile anything it sees in Git, including resources rendered downstream by KubeVela — leading to permanent drift. Crossplane can be used to deliver app workloads, blurring the line between infrastructure and application. KubeVela can emit resources that Argo CD thinks it owns, triggering sync/reconcile races.

## Decision

**Each layer owns one thing and never touches what another layer owns:**

| Layer | Owns | Never touches |
| --- | --- | --- |
| Argo CD | Applying Git state to clusters; deciding which cluster gets what | Resources rendered by KubeVela |
| Crossplane | Cloud resources: clusters, networks, buckets, databases | Helm releases and app workloads |
| KubeVela | App components, traits, delivery workflow, the resources it renders | Cluster placement |

Concretely:

- **Argo CD** syncs wrapper-chart Applications (platform components) and KubeVela Application CRs (workloads). It does **not** sync the Deployments/Services/Certificates that KubeVela renders — those are downstream artifacts.
- **Crossplane** composes XRs into cloud API calls (and sometimes into Kubernetes Secrets holding connection details) via AWS, GCP, and Kubernetes providers. It does **not** install Helm charts or workload Deployments, even though `provider-helm` would allow it.
- **KubeVela** renders workload shape from a component definition. It does **not** decide which cluster the workload lands on — that's a label-match problem for the tenants ApplicationSet ([ADR-0008](0008-label-placement-now-ocm-later.md)).

## Alternatives considered

**One system does it all.** Rejected because none of the three is a complete fit: Argo CD has no cloud API story, Crossplane has no application model, KubeVela has no cluster scheduling. Forcing one to do everything means stretching it past its strengths — most commonly Crossplane driving Helm releases, which replaces Argo CD's audit trail with an opaque composition.

**No boundaries, let teams choose.** Rejected because overlapping ownership creates drift detection conflicts. If both Argo CD and KubeVela think they own a Deployment, one will constantly "fix" what the other just did. The platform's reliability depends on exactly one reconciler per resource.

## Consequences

**Positive.** Argo CD's sync status is accurate because it only reconciles what it owns. KubeVela's workflow completes without Argo CD fighting it. Crossplane's composition drift (if any) stays visible on the XR, not scattered across the fleet. The mental model for "where did this resource come from" has a single answer per resource type.

**Negative.** Discipline-based: no mechanical enforcement stops a wrapper chart from emitting a Crossplane XR that properly belongs in `skylab-crossplane`. AppProject `destinations` and `clusterResourceWhitelist` act as a soft fence — a Kyverno policy enforcing per-controller ownership labels would make this stronger (deferred).

**Neutral.** The `workloads/mechatracker-db` Application is an edge case: an Argo-synced KubeVela Application whose `postgres` ComponentDefinition emits a Crossplane XR. The Argo CD AppProject widened to allow `""/Namespace` so Argo can create the workload namespace, but the XR and the Postgres instance it eventually composes are not Argo's concern — they're Crossplane's. The split is intentional: Argo owns the handoff point (the XR), Crossplane owns the fulfillment.
