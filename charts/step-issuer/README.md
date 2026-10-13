# step-issuer (wrapper)

Wave 0. The cert-manager external issuer that talks to step-ca.

Installs the controller and its CRDs. The actual `StepClusterIssuer` resource lands in a follow-up PR once step-ca has a provisioner password available through ExternalSecret.

## Upstream

- Chart: `smallstep/step-issuer`
- Pinned via `Chart.yaml` `dependencies`.
