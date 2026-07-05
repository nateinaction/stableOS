# Sign images with cosign and enforce on upgrade

- Status: accepted
- Date: 2026-07-04
- Deciders: nateinaction

## Context and Problem Statement

stableOS is distributed as an OCI image on a public registry
(`ghcr.io/nateinaction/stableos`) and consumed by machines via `bootc upgrade` /
`bootc switch`. Because the image *is* the operating system, a machine that pulls
a tampered or spoofed image would boot a compromised OS. Registry tags are
mutable, so "pull `:latest`" alone guarantees nothing about provenance. The
safety goal demands that a machine only boot images actually produced by this
project's pipeline.

How should image authenticity be established and enforced?

## Considered Options

- **cosign with a fixed key pair, enforced by containers-image policy** — sign
  the published manifest; bake a policy that requires a valid signature.
- **cosign keyless (OIDC/Fulcio/Rekor)** — sign via short-lived certificates tied
  to the CI identity.
- **No signing** — rely on registry access controls and TLS only.

## Decision Outcome

Chosen: **cosign signing with a fixed key pair, enforced on every machine**.

- CI signs the pushed manifest **by digest** after publishing (the private key is
  a CI secret, `SIGNING_SECRET`). :latest and :<sha> share one manifest digest,
  so a single signature covers both.
- The public key (`cosign.pub`) is **baked into the image** at
  `/etc/pki/containers/stableos.pub`, and a containers-image policy
  (`files/containers/policy.json` → `/etc/containers/policy.json`) **requires** a
  valid signature specifically for `ghcr.io/nateinaction/stableos`. The policy is
  otherwise left permissive so base-image, Flatpak, and other pulls keep working.
- Because the policy ships *inside* the image, every installed system enforces it:
  `bootc upgrade` refuses any unsigned or mis-signed stableOS image. The next
  image must be signed by the same key or the machine won't take it — a
  self-reinforcing chain of trust.

Keyless signing was not chosen: a fixed public key can be baked into the image
and checked entirely offline at `bootc upgrade` time, with no dependency on OIDC/
Fulcio/Rekor availability — a better fit for an OS that must verify updates on
machines in arbitrary network conditions.

### Consequences

- Good: machines only boot images signed by this project's key; a spoofed or
  tampered image is rejected at upgrade time.
- Good: enforcement is self-propagating — the policy travels inside the image, so
  every install enforces it without per-machine setup.
- Good: verification is offline and dependency-free (just the baked-in public
  key), robust to registry/OIDC outages.
- Good: users can independently verify with `cosign verify --key cosign.pub …`.
- Bad: key management burden — the private key is a long-lived CI secret; its
  compromise or loss is a serious event (rotation means re-baking the public key
  and getting every machine onto an image carrying the new key).
- Bad: a machine whose policy requires the signature can be "bricked" for updates
  if signing ever breaks in CI — unsigned images simply won't apply.
