# trust-manager (wrapper)

Wave 0. Installs jetstack/trust-manager into the cert-manager namespace.

Not yet included (follow-up): a `Bundle` resource that fetches the step-ca root and distributes it to every namespace labelled `skylab.io/trust=enabled`. Shipping that requires step-ca to have published its root publicly first.

## Upstream

- Chart: `jetstack/trust-manager`
- Pinned via `Chart.yaml` `dependencies`.
