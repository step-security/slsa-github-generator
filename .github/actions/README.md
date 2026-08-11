# Internal Action Development

## External Actions

The following Actions:

- detect-workflow
- privacy-check
- rng
- secure-builder-checkout
- generate-builder

are considered "external" even though they are hosted on the same repository: they are not called via:

`././github/actions/name`

but instead via their "fully-qualified" name:

`step-security/slsa-github-generator/.github/actions/name@vX.Y.Z`.

We do this because the Actions are part of the builder, whereas the workflow runs in the "context" of the calling repository.

These Action _MUST_ be pinned with the release tag for consistency.

## Internal Actions

Other Actions are called via:

`././github/actions/name`

and always require a checkout of the builder repository before being called.
The `secure-builder-checkout` is always used to checkout the builder repository
at `__BUILDER_CHECKOUT_DIR__` location. The `secure-project-checkout-*` checkout
the project to build at the location `__PROJECT_CHECKOUT_DIR__`.

These Actions are _composite actions_. They invoke scripts and also call other Actions.

```

```
