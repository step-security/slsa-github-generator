[![StepSecurity Maintained Action](https://raw.githubusercontent.com/step-security/maintained-actions-assets/main/assets/maintained-action-banner.png)](https://docs.stepsecurity.io/actions/stepsecurity-maintained-actions)

# SLSA GitHub Generator

[![OpenSSF Scorecard](https://api.securityscorecards.dev/projects/github.com/step-security/slsa-github-generator/badge)](https://api.securityscorecards.dev/projects/github.com/step-security/slsa-github-generator)

Secure drop-in replacement for [slsa-framework/slsa-github-generator](https://github.com/slsa-framework/slsa-github-generator), maintained by [StepSecurity](https://docs.stepsecurity.io/actions/stepsecurity-maintained-actions).

## Actions

| Action                                                                               | Description                                                        |
| :----------------------------------------------------------------------------------- | :----------------------------------------------------------------- |
| [compute-sha256](.github/actions/compute-sha256)                                     | Computes the SHA256 digest of a file                               |
| [create-container_based-predicate](.github/actions/create-container_based-predicate) | Creates a container-based SLSA predicate                           |
| [detect-workflow-js](.github/actions/detect-workflow-js)                             | Detects the calling workflow using OIDC or context                 |
| [generate-attestations](.github/actions/generate-attestations)                       | Generates and uploads SLSA attestations                            |
| [generate-builder](.github/actions/generate-builder)                                 | Builds or fetches the builder binary                               |
| [privacy-check](.github/actions/privacy-check)                                       | Checks repository visibility before publishing to transparency log |
| [rng](.github/actions/rng)                                                           | Generates a random value                                           |
| [secure-builder-checkout](.github/actions/secure-builder-checkout)                   | Checks out the builder repository at a pinned ref                  |
| [secure-download-artifact](.github/actions/secure-download-artifact)                 | Downloads and verifies an artifact by SHA256                       |
| [secure-download-folder](.github/actions/secure-download-folder)                     | Downloads and verifies a folder artifact by SHA256                 |
| [secure-project-checkout](.github/actions/secure-project-checkout)                   | Checks out the user project at a verified ref                      |
| [secure-project-checkout-go](.github/actions/secure-project-checkout-go)             | Checks out and sets up a Go project                                |
| [secure-project-checkout-node](.github/actions/secure-project-checkout-node)         | Checks out and sets up a Node.js project                           |
| [secure-upload-artifact](.github/actions/secure-upload-artifact)                     | Uploads an artifact and outputs its SHA256                         |
| [secure-upload-folder](.github/actions/secure-upload-folder)                         | Uploads a folder as a tarball and outputs its SHA256               |
| [sign-attestations](.github/actions/sign-attestations)                               | Signs SLSA attestations using Sigstore                             |
| [tscommon](.github/actions/tscommon)                                                 | Shared TypeScript library used by the Node.js actions              |
| [verify-token](.github/actions/verify-token)                                         | Verifies the SLSA token passed from the reusable workflow          |
