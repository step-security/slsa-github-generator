// Copyright 2023 SLSA Authors
// Copyright 2026 StepSecurity
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import * as core from "@actions/core";
import { attest, InternalError } from "sigstore";
import * as path from "path";
import * as tscommon from "tscommon";
import * as fs from "fs";
import axios, { isAxiosError } from "axios";

async function validateSubscription(): Promise<void> {
  const eventPath = process.env.GITHUB_EVENT_PATH;
  let repoPrivate: boolean | undefined;

  if (eventPath && fs.existsSync(eventPath)) {
    const eventData = JSON.parse(fs.readFileSync(eventPath, "utf8"));
    repoPrivate = eventData?.repository?.private;
  }

  const upstream = "slsa-framework/slsa-github-generator";
  const action = process.env.GITHUB_ACTION_REPOSITORY;
  const docsUrl =
    "https://docs.stepsecurity.io/actions/stepsecurity-maintained-actions";

  core.info("");
  core.info("\u001b[1;36mStepSecurity Maintained Action\u001b[0m");
  core.info(`Secure drop-in replacement for ${upstream}`);
  if (repoPrivate === false)
    core.info("\u001b[32m✓ Free for public repositories\u001b[0m");
  core.info(`\u001b[36mLearn more:\u001b[0m ${docsUrl}`);
  core.info("");

  if (repoPrivate === false) return;

  const serverUrl = process.env.GITHUB_SERVER_URL || "https://github.com";
  const body: Record<string, string> = { action: action || "" };
  if (serverUrl !== "https://github.com") body.ghes_server = serverUrl;
  try {
    await axios.post(
      `https://agent.api.stepsecurity.io/v1/github/${process.env.GITHUB_REPOSITORY}/actions/maintained-actions-subscription`,
      body,
      { timeout: 3000 },
    );
  } catch (error) {
    if (isAxiosError(error) && error.response?.status === 403) {
      core.error(
        `\u001b[1;31mThis action requires a StepSecurity subscription for private repositories.\u001b[0m`,
      );
      core.error(
        `\u001b[31mLearn how to enable a subscription: ${docsUrl}\u001b[0m`,
      );
      process.exit(1);
    }
    core.info("Timeout or API not reachable. Continuing to next step.");
  }
}

async function run(): Promise<void> {
  try {
    /* Test locally:
        $ env INPUT_ATTESTATIONS="testdata/attestations" \
        INPUT_OUTPUT-FOLDER="outputs" \
        GITHUB_WORKSPACE="$(pwd)" \
        nodejs ./dist/index.js
    */

    // Attestations
    const attestationFolder = core.getInput("attestations");
    const payloadType = core.getInput("payload-type");

    // Output folder
    const outputFolder = core.getInput("output-folder");
    tscommon.safeMkdirSync(outputFolder, { recursive: true });

    const files = await tscommon.safePromises_readdir(attestationFolder);
    for (const file of files) {
      const fpath = path.join(attestationFolder, file);
      const stat = await tscommon.safePromises_stat(fpath);
      if (stat.isFile()) {
        core.debug(`Signing ${fpath}...`);
        const buffer = tscommon.safeReadFileSync(fpath);
        const bundle = await attest(buffer, payloadType);
        const bundleStr = JSON.stringify(bundle);
        const outputPath = path.join(
          outputFolder,
          `${path.basename(fpath)}.build.slsa`,
        );
        // We detect path traversal for outputPath in safeWriteFileSync.
        tscommon.safeWriteFileSync(outputPath, bundleStr);
        core.debug(`Wrote signed attestation to '${outputPath}.`);
      }
    }
  } catch (error) {
    if (error instanceof InternalError) {
      core.setFailed(`${error}: ${error.cause}`);
    } else {
      core.setFailed(`Unexpected error: ${error}`);
    }
  }
}

(async () => {
  try {
    await validateSubscription();
    run();
  } catch (err) {
    core.setFailed(String(err));
  }
})();
