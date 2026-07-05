# Rechunk images into deterministic layers before publishing

- Status: accepted
- Date: 2026-07-04
- Deciders: nateinaction

## Context and Problem Statement

Machines running stableOS pull image updates frequently via `bootc upgrade`, which
downloads only the layers that changed. But a naively built image works against
that: `podman build` produces layers along `Containerfile` instruction
boundaries, and their content/order is not stable across builds. Small source
changes — or even a rebuild with no change — can reshuffle layers, so machines
re-download large amounts of unchanged data on every upgrade. For an OS updated
this often, fat, unstable update deltas are a real cost.

How should published images be structured so upgrade downloads stay small?

## Considered Options

- **Rechunk the built image into deterministic, package-aligned layers before
  publishing** (`hhd-dev/rechunk`).
- **Publish the image as `podman build` produces it** — no post-processing.
- **Hand-tune `Containerfile` layer ordering** to keep churn low manually.

## Decision Outcome

Chosen: **rechunk the image before publishing**, as a step in the CI pipeline
(`.github/workflows/build.yml`), on `main` only. After the image is built and
passes its structure tests, `hhd-dev/rechunk` repartitions it into deterministic,
**package-boundary-aligned** layers. It is passed the last published image as
`prev-ref`, so chunks whose contents did not change stay **byte-stable** across
builds — which is what keeps `bootc` upgrade deltas small.

Because rechunk rewrites the image and strips its config, two things are
re-applied afterward: the `Containerfile` LABELs (title/description/source) and a
`YYMMDD` version stamp. The rechunked image — not the original `podman build`
output — is what gets pushed to GHCR and then signed
([ADR 0006](0006-cosign-image-signing.md)).

Publishing the raw build was rejected because it produces the unstable, oversized
deltas described above; hand-tuning layer order was rejected as fragile busywork
that rechunk automates deterministically.

### Consequences

- Good: `bootc upgrade` downloads stay small — unchanged package chunks are
  byte-identical to the previous image, so they aren't re-fetched.
- Good: deterministic layering makes rebuilds reproducible at the layer level,
  independent of `Containerfile` instruction churn.
- Good: fully automated in CI; no manual layer curation.
- Bad: adds build time and an external action dependency (`hhd-dev/rechunk`) on
  the release path.
- Bad: rechunk strips the image config, so LABELs/version must be re-applied — an
  easy-to-forget step that lives in the workflow.
- Bad: the `prev-ref` optimization couples each build to the previously published
  image; a first build, or a deleted GHCR package, means no delta baseline for
  that run.
