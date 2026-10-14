# Skylab Platform Rework — skylab-gitops

Oct 12, 2026 · @Skylar

> One slice of a five-repo rework. See the **Cross-repo map** below for the siblings.

## North star

Skylab becomes four public platform repos on GitHub plus a tenant repo in Gitea, built in a fixed order, with one owner per layer. It runs as a homelab hub managing spoke clusters on AWS and GCP. The old argo-\*, backstage-\* and shoutsky-images repos are archived once their contents have a new home. There is no live infrastructure to migrate, so every repo is built clean.

Humans and agents only ever write to Git; Argo CD is the single path into the clusters, and AWS foundations come from Terraform CI.

### Layer ownership

| Layer | Tool | Owns | Never touches |
| --- | --- | --- | --- |
| Delivery | Argo CD | Applying Git state to clusters; deciding which cluster gets what | Resources rendered by KubeVela |
| Infrastructure API | Crossplane | Cloud resources: EKS, networking, buckets, databases | Helm releases and app workloads |
| Application API | KubeVela | App components, traits, delivery workflow, the resources it renders | Cluster placement |
| Front door | Backstage | Catalog, templates, MCP actions for AI clients | Direct writes to clusters |
| Investigation | HolmesGPT | Read-only root-cause analysis of alerts | Any change to the system |
| Remediation | tack-ai | Proposing fixes as pull requests, behind policy and approval | Direct cluster changes |

### Cross-repo map

| Repo | Host | Replaces | Purpose |
| --- | --- | --- | --- |
| **skylab-gitops** (this repo) | GitHub | skylab-argo-root, skylab-argo-bootstrap, skylab-argo-workloads | Everything Argo CD syncs: platform charts, cluster config, workloads |
| skylab-terraform | GitHub | proxmox-qdevice from shoutsky-images | AWS and GCP foundations: OIDC, workload identity, buckets, IAM, qdevice |
| skylab-backstage | GitHub | skylab-backstage-catalog, Backstage image from shoutsky-images | Backstage app, image, chart, templates, plugins |
| skylab-crossplane | GitHub | crossplane-xrd folder in skylab-argo-bootstrap | Cloud-agnostic XRDs with AWS and GCP compositions, as an OCI package |
| platform/tenants | Gitea | skylab-backstage-configs | Scaffolder output: KubeVela Applications and infra requests |
| tack-ai | GitHub (existing) | n/a | Governed remediation agent; integration work only |

### Build order

1. **skylab-gitops**, including Gitea, KubeVela and the observability stack. Everything else plugs into it.
2. **skylab-terraform**, moved up because Loki, Tempo and TechDocs need buckets and Roles Anywhere before they can store anything.
3. **skylab-backstage**, including the Gitea pull-request action and MCP actions.
4. **skylab-crossplane**, with EKS and GKE behind one cluster API, handing new clusters to Argo CD.
5. **Archive the old repos** once each piece has moved.
6. **Golden paths**: KubeVela definitions and the templates that use them.
7. **AI layer**: model gateway, HolmesGPT, tack-ai remediation, kagent.
8. **Portfolio finish**: profile README, pins, ADRs.

## Status (as of 2026-10-13)

Progress through the shared build order:

- [x] 1. **skylab-gitops** — bootstrap, skylab-apps renderer, CI pipeline, waves -2 → 1 landed. Next: close the deferred wave-0 wiring (now unblocked by terraform), then wave 2 pin or wave 3 KubeVela.
- [x] 2. **skylab-terraform** — substantively complete. Seven stacks (bootstrap, identity, storage, roles-anywhere, crossplane, qdevice, gcp-identity) and five modules (aws-github-oidc, aws-object-storage, aws-roles-anywhere, aws-ecs-service, gcp-workload-identity) with fmt/validate/tflint/trivy CI. Modules consistently cloud-prefixed. Follow-ups below.
- [ ] 3. **skylab-backstage** — not started.
- [ ] 4. **skylab-crossplane** — not started. The gitops wave 2 Application will pin an OCI package built from this repo.
- [ ] 5. Archive the old repos
- [ ] 6. Golden paths
- [ ] 7. AI layer (includes tack-ai)
- [ ] 8. Portfolio finish

### Deferred wiring in skylab-gitops (now unblocked)

Terraform's `stacks/roles-anywhere` is live, so these can land next:

- cert-manager ClusterIssuers (`StepClusterIssuer` + ACME Let's Encrypt)
- trust-manager Bundle distributing the step-ca root
- external-secrets ClusterSecretStores (AWS Secrets Manager, GCP Secret Manager)
- step-ca provisioner secrets via ExternalSecret

### Deferred follow-ups in skylab-terraform

- Tighten scaffold policies: ESO `SecretsManagerReadWrite`, `terraform-ci` role `AdministratorAccess`, GCP SAs on `roles/owner`/`roles/editor`.
- Port the actual qdevice container logic from `shoutsky-images/images/proxmox-qdevice`.
- qdevice image build+push CI.
- Retire `terraform/development/` legacy content once nothing references it.

### Deferred CI work in skylab-gitops

- OCI push to GHCR on main
- Rendered-diff PR comment on PRs

---

## This repo

One repo holds everything Argo CD syncs: per-component wrapper charts, a chart that renders Applications in sync waves, per-cluster config files and workload definitions. It replaces three argo-\* repos, their kustomizations and the eight environment-split ApplicationSets.

```
skylab-gitops/
├── bootstrap/          # Argo CD values + root Application, run once
├── clusters/           # one file per cluster: labels, enabled components, overrides
├── charts/
│   ├── skylab-apps/    # renders Applications, AppProjects, sync waves
│   ├── cert-manager/   # wrapper: upstream dep + issuers, bundles, ExternalSecrets
│   ├── external-secrets/
│   ├── gitea/
│   ├── kubevela/
│   ├── kubevela-defs/  # ComponentDefinitions and TraitDefinitions (CUE)
│   ├── crossplane/
│   ├── alloy/
│   ├── prometheus/
│   ├── loki/
│   ├── tempo/
│   ├── grafana/
│   └── ai/             # model gateway, HolmesGPT, kagent, MCP servers
├── workloads/          # platform-owned KubeVela Applications
└── docs/adr/
```

### Design decisions

- **One wrapper chart per component.** Each `Chart.yaml` depends on the upstream chart and adds its own templates (Namespace, ExternalSecrets, ClusterIssuers, Bundles). This replaces kustomize `helmCharts` and the `--enable-helm` flag. No single platform-wide umbrella chart, so each component keeps its own health, sync status and blast radius.
- **Sync waves instead of appset sprawl.** `skylab-apps` renders one Application per enabled component with a wave annotation. Add the `argoproj.io_Application` health check Lua to `argocd-cm`, because Argo CD stopped assessing child Application health in 1.8 and waves will not wait without it.
- **Cluster-as-data instead of path-based environments.** One ApplicationSet with a cluster generator renders `skylab-apps` per cluster from the labels on its Argo cluster Secret. Values layer as `values.yaml`, then `values-<env>.yaml`, then `clusters/<name>.yaml`, with `ignoreMissingValueFiles: true`.
- **OCI and promotion by version.** CI runs `ct lint` (enforcing version bumps), kubeconform and helm-unittest, then pushes changed charts to GHCR as OCI. Dev tracks chart paths on `main`; prod pins OCI versions, so promotion is a one-line PR. A PR job comments the rendered manifest diff.
- **A second source for tenants.** A git-generator ApplicationSet watches the Gitea `platform/tenants` repo. Platform state stays public on GitHub; scaffolder output stays in-cluster.

### Sync waves

| Wave | Components |
| --- | --- |
| -2 | Argo CD (self-managed) |
| -1 | cert-manager, External Secrets Operator |
| 0 | step-ca, step-issuer, trust-manager, ClusterSecretStores, Kyverno and its policies |
| 1 | Crossplane and providers (AWS, GCP, Kubernetes) |
| 2 | skylab-crossplane Configuration package |
| 3 | KubeVela, kubevela-defs |
| 4 | Gitea (Postgres on a PVC), act\_runner |
| 5 | Alloy, Prometheus, Loki, Tempo, Grafana, SLO rules |
| 6 | Backstage, Headlamp, SonarQube |
| 7 | Model gateway, HolmesGPT, kagent, MCP servers, tack-ai |
| 10 | Workloads |

### Observability stack

- **Collection:** Grafana Alloy as a DaemonSet for logs, metrics, traces and Kubernetes events. It replaces Promtail, which reached end of life on March 2, 2026.
- **Backends:** kube-prometheus-stack on every cluster for local alerting, remote-writing to Mimir on the hub; Loki (simple scalable mode) and Tempo on the hub. All three use cloud object storage and every signal carries cluster and cloud labels. MinIO is dropped.
- **Credentials:** IAM Roles Anywhere with step-ca as the trust anchor, so Loki and Tempo get short-lived AWS credentials and no static keys. _See skylab-terraform for the trust anchor + profiles._
- **Correlation:** exemplars and datasource links from metrics to traces to logs.
- **SLOs and alerts:** Pyrra or Sloth generate burn-rate rules; Alertmanager routes to ntfy or Discord and to HolmesGPT.
- **Platform signals:** Argo CD metrics and Notifications, Crossplane metrics, KubeVela workflow status, and the GenAI telemetry already built into HolmesGPT and tack-ai.
- **Later:** Pyroscope for profiling and Beyla eBPF instrumentation for uninstrumented services.

### Hardening

- AppProjects per tier (platform, tenants, workloads) with restricted destinations and source repos.
- Pinned `targetRevision` values everywhere; no `HEAD`.
- Argo CD installed from a values file, then managing itself; no `--set` flags or insecure mode.
- Renovate for chart, image and action bumps.
- Kyverno policies: no `latest` tags, no privileged pods, required owner labels.

### Done when

- [ ] One bootstrap command brings a cluster from empty to every wave healthy
- [ ] Waves visibly wait on health in the Argo UI
- [ ] CI is green: lint, kubeconform, unittest, OCI push, rendered diff comment
- [ ] README has the architecture diagram and the wave table

---

## Fleet topology (lives here because ApplicationSets own placement)

GCP joins AWS as a second cloud, and the platform treats both as interchangeable targets behind one set of APIs. A developer asks for a cluster, a database or a bucket; which cloud, which cluster and which credentials are platform decisions.

- **Hub:** the homelab cluster runs the management plane: Argo CD, Crossplane, Backstage, Gitea, the observability backends and the AI layer.
- **Spokes:** EKS and GKE clusters created on demand through templates, plus an optional second homelab cluster. Each runs workloads and a small spoke profile: Alloy, External Secrets Operator, cert-manager, KubeVela and Kyverno.
- **Clusters are data:** every spoke is an Argo CD cluster Secret labeled with `cloud`, `region`, `env` and `role`. `skylab-apps` reads those labels to pick the hub or spoke component set and the right cloud integrations.

### Placement

1. **Labels first.** Each tenant app carries a placement file (for example `env: prod`, `cloud: any`). The tenants ApplicationSet is a matrix of a git files generator over those files and a cluster generator whose selector uses their values.
2. **Open Cluster Management later.** OCM's Placement API selects and scores clusters, and Argo CD's cluster decision resource generator consumes the result. This adds real multi-cluster scheduling without changing the apps.

### Fleet-wide concerns

- **Secrets:** one ClusterSecretStore per cloud (AWS Secrets Manager, GCP Secret Manager), selected by cluster label.
- **DNS and certificates:** external-dns on each cloud writing into delegated zones; step-ca for internal certificates, ACME for public ones.
- **Connectivity:** the hub reaches spoke API servers through the Tailscale operator or authorized public endpoints. Cross-cluster service traffic (Istio ambient multicluster or Cilium Cluster Mesh) is a stretch goal.
- **Observability:** Alloy on every spoke ships to the hub with `cluster` and `cloud` labels. Metrics move to Mimir on the hub so one Grafana shows the fleet, with health and SLOs per cluster and per cloud.
- **Policy:** the same Kyverno policies land on every cluster through `skylab-apps`.
- **Backstage:** the Kubernetes plugin uses the catalog cluster locator, and each template-created cluster is a Resource entity, so new clusters appear without config changes.
- **Cost:** spokes are ephemeral by default. Templates set a TTL, and an expired cluster gets a deletion PR from tack-ai that policy auto-approves for dev. EKS bills every control plane hourly; GKE's free tier covers one cluster's management fee.

### End-to-end demos the fleet should prove

- [ ] One KubeVela Application runs on EKS and GKE by changing placement labels only
- [ ] A Postgres dependency resolves to RDS on AWS and Cloud SQL on GCP with no app change
- [ ] A new GKE cluster from a template is adopted by Argo CD, gets the spoke profile and appears in Grafana and Backstage with no manual step
- [ ] Deleting a spoke removes its Argo registration, catalog entity and cloud resources

### Fleet-level decisions

| Decision | Options | Lean |
| --- | --- | --- |
| Placement | Labels only, Open Cluster Management | Labels first, OCM once three or more spokes exist |
| Fleet metrics | Mimir, Thanos | Mimir, matching Loki and Tempo |
| Hub-to-spoke connectivity | Tailscale operator, authorized public endpoints | Tailscale, which avoids exposing API servers |

_GKE mode, composition selection and the cloud-agnostic API shape live in `skylab-crossplane/plan.md`. Identity decisions live in `skylab-terraform/plan.md`._

---

## Golden paths — KubeVela definitions

The templates themselves live in `skylab-backstage/plan.md`. The definitions they instantiate are in-repo at `charts/kubevela-defs`.

- **Components:** `go-service` (built on `webservice`), `ai-agent`, `postgres` and `bucket`. The last two render Crossplane XRs.
- **Traits:** `observability` (ServiceMonitor, starter dashboard, Pyrra SLO), `route` (Gateway API HTTPRoute with a step-ca certificate), `canary` (progressive delivery), `autoscale` (event-driven scaling), `secrets` (ExternalSecret), `model-access` (routes through the model gateway).
- **Design rule:** a new app's Application spec fits on one screen: a component type, an image, a few traits, a list of dependencies.
- **CI:** `vela def vet` on every definition, plus a render test per component.

---

## AI layer — wave-7 components

HolmesGPT investigates and tack-ai writes the fix as a pull request; neither touches the cluster directly. Both already emit telemetry, so the work here is wiring, governance and packaging.

Policy decides each fix: low-risk changes merge on their own, risky ones wait for a human, and denied ones are only logged.

### Components (wave 7, under `charts/ai/`)

- **Model gateway:** LiteLLM to start, or agentgateway if you want MCP routing too. It holds provider keys, enforces per-agent budgets and rate limits, and exports token metrics to Prometheus. Every AI workload calls the gateway, never a provider.
- **HolmesGPT:** read-only toolsets for Prometheus, Loki, Tempo, Kubernetes and Argo CD, driven by Alertmanager webhooks. Its RBAC is read-only.
- **tack-ai:** consumes Holmes findings and proposes fixes as code. Cedar and OPA decide allow, require approval or deny; approvals arrive through ntfy or Backstage; every decision becomes an audit record. _Integration work lives in `tack-ai/plan-skylab-integration.md`._
- **kagent:** runs agents as CRDs. tack-ai is exposed over A2A and registered there, so it is managed like any other platform agent.
- **MCP servers:** Grafana, Kubernetes and Argo CD, plus Backstage's MCP actions, available to both agents.

### Done when

- [ ] A synthetic alert (for example, a crash-looping deployment) produces a Holmes summary, a tack-ai PR and a policy decision
- [ ] A dev fix merges automatically; a prod fix waits for approval
- [ ] Every step appears in Grafana and the audit log
- [ ] The README shows the run as a short recording or screenshot sequence

---

## Retire the old repos (coordination index)

Every old repo is archived with a README pointing to where its contents went. Nothing is deleted, except the weather app.

| Old repo or folder | Destination |
| --- | --- |
| skylab-argo-root | skylab-gitops (`charts/skylab-apps`, `bootstrap/`) |
| skylab-argo-bootstrap | skylab-gitops wrapper charts; crossplane-xrd folder to skylab-crossplane |
| skylab-argo-workloads | skylab-gitops `workloads/`; demo apps rebuilt through golden paths |
| skylab-backstage-catalog | skylab-backstage `templates/` and `catalog/` |
| skylab-backstage-configs | Gitea `platform/tenants` |
| shoutsky-images/images/backstage | skylab-backstage `app/` |
| shoutsky-images/images/proxmox-qdevice | skylab-terraform `stacks/qdevice/` |
| shoutsky-images/images/weather-app-csharp | Deleted |
| shoutsky-images/docker-compose | Archived as pre-Kubernetes history |

Also drop the in-cluster ECR token-refresh job once public images live on GHCR, and replace tetris-react, which runs a third-party `latest` image, with an app of your own built from a golden path.

---

## Portfolio finish

The profile should tell one story in under a minute: Skylab is a homelab internal developer platform, and each pinned repo is one layer of it.

- **Profile README:** two lines on what you do, the architecture diagram from this plan, and one line per repo with its link.
- **Pins:** skylab-gitops, skylab-backstage, skylab-crossplane, skylab-terraform, tack-ai, plus the Go service built from the golden path.
- **Each repo:** a description, topics (kubernetes, argocd, gitops, backstage, crossplane, kubevela, platform-engineering), a green CI badge, a license, and a README linking back to the others.
- **Demo assets:** screenshots of Backstage entity pages, the Argo wave rollout, a Grafana SLO dashboard, and the AI remediation run.

### ADRs to write

- [ ] One repo for GitOps state; platform on GitHub, tenants on Gitea
- [ ] Wrapper charts per component instead of kustomize or one umbrella
- [ ] Sync waves with the Application health check
- [ ] Cluster-as-data instead of path-based environments
- [ ] Promotion by OCI chart version
- [ ] Layer ownership: Argo CD, Crossplane, KubeVela
- [ ] Crossplane hands clusters to Argo CD instead of deploying Helm releases
- [ ] Roles Anywhere with step-ca instead of static keys
- [ ] Discovery and a generated Location instead of manual registration
- [ ] HolmesGPT adopted for investigation; tack-ai built for governed remediation
- [ ] Hub and spoke fleet with cloud-agnostic Crossplane APIs
- [ ] One step-ca root federated into AWS and GCP identity
- [ ] Label placement now, Open Cluster Management later
- [ ] Replacing Ingress for traffic management
- [ ] Workload identity for services and agents

---

## CNCF landscape coverage

Skylab is strong on automation, application definition, observability and AI agents; the biggest gaps are networking, traffic, storage and messaging. This is a coverage map by landscape area, not a tool selection: implementations get chosen when each area comes up, and the map should grow as new gaps surface.

### Provisioning

| Category | Status | Covered by the plan | Not yet covered |
| --- | --- | --- | --- |
| Automation and configuration | Strong | Terraform, Crossplane, Helm wrapper charts, Argo CD | Nothing major |
| Container registry | Partial | GHCR, Gitea package registry | Scan-on-push, retention, replication across clouds |
| Security and compliance | Partial | Kyverno, Trivy, cosign signing, SBOMs | Runtime threat detection, signature verification at admission, compliance benchmarks |
| Key management and identity | Partial | step-ca, External Secrets Operator, keyless AWS and GCP federation | A workload identity standard for services and agents |

### Runtime

| Category | Status | Covered by the plan | Not yet covered |
| --- | --- | --- | --- |
| Cloud native storage | Gap | Nothing | Persistent storage for homelab clusters, backup and restore, disaster recovery tests |
| Cloud native network | Gap | Nothing | CNI choice, network policy, flow visibility, multi-cluster networking |
| Container runtime | Not yet in scope | Distribution defaults | Sandboxed runtimes for untrusted or AI-generated code |

### Orchestration and management

| Category | Status | Covered by the plan | Not yet covered |
| --- | --- | --- | --- |
| Scheduling and orchestration | Partial | Multi-cluster fleet, placement, cluster API through Crossplane | Workload and node autoscaling |
| Coordination and service discovery | Strong | CoreDNS, external-dns per cloud | Cross-cluster service discovery |
| Service proxy and API gateway | Gap | Nothing; workloads still use Ingress | Replacing Ingress (Ingress NGINX was retired in March 2026), north-south traffic policy, rate limiting |
| Service mesh | Gap | Nothing | Service-to-service mTLS, east-west traffic policy, cross-cluster traffic |
| Remote procedure call | Not yet in scope | Nothing | gRPC conventions in the golden path |

### App definition and development

| Category | Status | Covered by the plan | Not yet covered |
| --- | --- | --- | --- |
| Application definition and image build | Strong | KubeVela, Helm, Backstage templates | Image builds without hand-written Dockerfiles |
| Continuous integration and delivery | Partial | GitHub and Gitea Actions, Argo CD, OCI promotion | Progressive delivery: canaries and analysis-gated rollouts |
| Database | Partial | Cloud Postgres through Crossplane | In-cluster database operations for the homelab |
| Streaming and messaging | Gap | Nothing | An event backbone for apps and for platform events such as alerts, sync results and agent triggers |

### Observability and analysis

| Category | Status | Covered by the plan | Not yet covered |
| --- | --- | --- | --- |
| Observability | Strong | OpenTelemetry, Alloy, Prometheus, Mimir, Loki, Tempo, Grafana, SLOs | Continuous profiling |
| Chaos engineering | Gap | Nothing | Fault injection to prove SLOs and exercise the remediation pipeline |
| Continuous optimization | Gap | Nothing | Cost allocation across clouds, rightsizing |
| Feature flagging | Gap | Nothing | Separating deploy from release in the golden path |

### Platform

| Category | Status | Covered by the plan | Not yet covered |
| --- | --- | --- | --- |
| Distributions and installers | Partial | EKS and GKE through Crossplane | Homelab cluster provisioning in code |

### Cloud native AI

| Category | Status | Covered by the plan | Not yet covered |
| --- | --- | --- | --- |
| Agents and AI operations | Strong | kagent, HolmesGPT, tack-ai, model gateway, Backstage MCP | Nothing major |
| Model serving and inference | Gap | Hosted model APIs through the gateway | Self-hosted serving; KServe is the reference CNCF project |
| AI scheduling and data | Gap | Nothing | GPU-aware scheduling, training and data pipelines; depends on having a GPU |

---

## Open decisions

None of these block the first repo; each can be settled when its section starts.

| Decision | Options | Lean | Decide by |
| --- | --- | --- | --- |
| Object storage provider | S3, Cloudflare R2 | R2 if Loki query egress matters; S3 for one-provider simplicity | Start of skylab-terraform |
| Model gateway | LiteLLM, agentgateway, Envoy AI Gateway | LiteLLM first; agentgateway if MCP routing is wanted | Start of the AI layer |
| SLO generator | Pyrra, Sloth | Pyrra, for its UI | Observability wave |
| Crossplane version | v1 with claims, v2 | v2, since there is nothing to migrate | Start of skylab-crossplane |
| Prod cluster | Second homelab cluster, EKS from the template | EKS from the template, to prove the handoff | After skylab-crossplane |
| Model hosting | Hosted APIs only, local vLLM or Ollama | Hosted APIs unless a GPU is available | Start of the AI layer |
