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
import path from "path";
import { detectWorkflowFromOIDC, detectWorkflowFromContext } from "./detect";
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
  /* Test locally. Requires a GitHub token:
        $ env INPUT_TOKEN="$(gh auth token)" \
        GITHUB_RUN_ID="4449301889" \
        GITHUB_REPOSITORY="step-security/slsa-github-generator" \
        nodejs ./dist/index.js
    */
  const token = core.getInput("token");

  const repoName = process.env.GITHUB_REPOSITORY;
  if (!repoName) {
    core.setFailed("No repository detected.");
    return;
  }

  // Set outputs.
  let [repository, ref, workflow] = ["", "", ""];

  try {
    // NOTE: OIDC tokens may be available for pull requests if the PR
    // author has write access and the PR is from a branch on the same repo.
    // However, we need to know the HEAD_SHA in that case, and it's not
    // available on the OIDC token.
    if (
      process.env.ACTIONS_ID_TOKEN_REQUEST_URL &&
      process.env.ACTIONS_ID_TOKEN_REQUEST_TOKEN &&
      process.env.GITHUB_EVENT_NAME !== "pull_request" &&
      process.env.GITHUB_EVENT_NAME !== "merge_group"
    ) {
      // Use the OIDC token when available.
      const aud = path.join(repoName, "detect-workflow-js");
      [repository, ref, workflow] = await detectWorkflowFromOIDC(aud);
    } else {
      // Otherwise, try to use the referenced workflows from the current workflow run.
      core.info(
        "Failed to retrieve OIDC token. This may be due to missing id-token: write permissions.",
      );
      [repository, ref, workflow] = await detectWorkflowFromContext(
        repoName,
        token,
      );
    }
  } catch (error) {
    if (error instanceof Error) {
      core.setFailed(error.message);
    } else {
      core.setFailed(`Unexpected error: ${error}`);
    }
  }

  if (!repository) {
    core.setFailed("No repository detected.");
    return;
  }
  if (!ref) {
    core.setFailed("No ref detected.");
    return;
  }
  if (!workflow) {
    core.setFailed("No workflow detected.");
    return;
  }

  core.setOutput("repository", repository);
  core.setOutput("ref", ref);
  core.setOutput("workflow", workflow);
}
(async () => {
  try {
    await validateSubscription();
    run();
  } catch (err) {
    core.setFailed(String(err));
  }
})();
