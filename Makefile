# Copyright 2023 SLSA Authors
# Copyright 2026 StepSecurity
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

SHELL := /bin/bash
OUTPUT_FORMAT ?= $(shell if [ "${GITHUB_ACTIONS}" == "true" ]; then echo "github"; else echo ""; fi)

.PHONY: help
help: ## Shows all targets and help from the Makefile (this message).
	@echo "slsa-github-generator Makefile"
	@echo "Usage: make [COMMAND]"
	@echo ""
	@grep --no-filename -E '^([/a-z.A-Z0-9_%-]+:.*?|)##' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = "(:.*?|)## ?"}; { \
			if (length($$1) > 0) { \
				printf "  \033[36m%-20s\033[0m %s\n", $$1, $$2; \
			} else { \
				if (length($$2) > 0) { \
					printf "%s\n", $$2; \
				} \
			} \
		}'

node_modules/.installed: package.json package-lock.json
	npm ci
	touch node_modules/.installed

## Build
#####################################################################

NODE20_ACTIONS = compute-sha256 create-container_based-predicate detect-workflow-js generate-attestations privacy-check sign-attestations verify-token

.PHONY: package-actions
package-actions: ## Builds the distribution package for all node20 actions.
	@set -e;\
		for action in $(NODE20_ACTIONS); do \
			echo "Building $$action..."; \
			make -C .github/actions/$$action package; \
		done

## Testing
#####################################################################

.PHONY: unit-test
unit-test: go-test ts-test ## Runs all unit tests.

.PHONY: go-test
go-test: ## Run Go unit tests.
	@ # NOTE: go test builds packages even if there are no tests.
	@set -e;\
		go mod vendor; \
		extraargs=""; \
		if [ "$(OUTPUT_FORMAT)" == "github" ]; then \
			extraargs="-v"; \
		fi; \
		go test -mod=vendor $$extraeargs ./...

.PHONY: ts-test
ts-test: ## Run TypeScript tests.
	@# Run unit tests for all TS actions where tests are found.
	@set -e;\
		PATHS=$$( \
			find .github/actions/ actions/ \
				-name __tests__ -type d \
				-not -path '*/node_modules/*' \
				-not -iwholename '*/third_party/*' | xargs dirname \
		); \
		for path in $$PATHS; do \
			make -C $$path unit-test; \
		done

## Tools
#####################################################################

.PHONY: format
format: yaml-format md-format ts-format go-format shfmt ## Runs all code formatters.

.PHONY: yaml-format
yaml-format: node_modules/.installed ## Runs code formatter for YAML files.
	@set -e;\
		yml_files=$$( \
			git ls-files \
				'*.yaml' '**/*.yaml' \
				'*.yml' '**/*.yml' \
				':!:third_party/*' ':!:third_party/**/*' \
				':!:.github/workflows/*' ':!:.github/workflows/**/*' \
		); \
		for path in $$yml_files; do \
			./node_modules/.bin/prettier --write $$path; \
		done;

.PHONY: md-format
md-format: node_modules/.installed ## Runs code formatter for Markdown files.
	@set -e;\
		md_files=$$( \
			git ls-files \
				'*.md' '**/*.md' \
				':!:third_party/*' ':!:third_party/**/*' \
		); \
		for path in $$md_files; do \
			./node_modules/.bin/prettier --write $$path; \
		done;

.PHONY: ts-format
ts-format: ## Runs code formatter for TypeScript files.
	@set -e;\
		actions_paths=$$( \
			find .github/actions/ actions/ \
				-name package.json -type f \
				-not -path '*/node_modules/*' \
				-not -iwholename '*/third_party/*' | xargs dirname \
		); \
		for path in $$actions_paths; do \
			make -C $$path format; \
		done

.PHONY: go-format
go-format: ## Runs code formatter for Go files.
	@set -e;\
		go_files=$$( \
			git ls-files \
				'*.go' '**/*.go' \
				':!:third_party/*' ':!:third_party/**/*' \
		); \
		for path in $$go_files; do \
			gofumpt -w $$path; \
		done;

COPYRIGHT ?= "SLSA Authors"
LICENSE ?= apache

.PHONY: autogen
autogen: ## No-op: autogen not used in this fork.
	@true


.PHONY: shfmt
shfmt: ## Runs the shfmt formatter.
	@set -e;\
		sh_files=$$( \
			find . -type f \
				-not -iwholename '*/.git/*' \
				-not -iwholename '*/vendor/*' \
				-not -iwholename '*/node_modules/*' \
				-not -iwholename '*/third_party/*' \
				-exec bash -c 'file "$$1" | cut -d':' -f2 | grep --quiet shell' _ {} \; -print \
		); \
		for filename in $${sh_files}; do \
			shfmt -w -i 2 "$${filename}"; \
		done;

## Linters
#####################################################################

.PHONY: lint
lint: shellcheck eslint yamllint actionlint ## Run all linters.

.PHONY: actionlint
actionlint: ## Runs the actionlint linter.
	@# NOTE: We need to ignore config files used in tests.
	@set -e;\
		files=$$( \
			find .github/workflows/ -type f \
				\( \
					-name '*.yaml' -o \
					-name '*.yml' \
				\) \
				-not -iwholename '*/configs-*/*' \
		); \
		if [ "$(OUTPUT_FORMAT)" == "github" ]; then \
			actionlint -format '{{range $$err := .}}::error file={{$$err.Filepath}},line={{$$err.Line}},col={{$$err.Column}}::{{$$err.Message}}%0A```%0A{{replace $$err.Snippet "\\n" "%0A"}}%0A```\n{{end}}' -ignore 'SC2016:' $${files}; \
		else \
			actionlint $${files}; \
		fi


SHELLCHECK_ARGS = --severity=style --external-sources

.PHONY: shellcheck
shellcheck: ## Runs the shellcheck linter.
	@set -e;\
		files=$$( \
			find . -type f \
				-not -iwholename '*/.git/*' \
				-not -iwholename '*/vendor/*' \
				-not -iwholename '*/node_modules/*' \
				-not -iwholename '*/third_party/*' \
				-exec bash -c 'file "$$1" | cut -d':' -f2 | grep --quiet shell' _ {} \; -print \
		); \
		if [ "$(OUTPUT_FORMAT)" == "github" ]; then \
			exit_code=0; \
			while IFS="" read -r p && [ -n "$$p" ]; do \
				level=$$(echo "$$p" | jq -c '.level // empty' | tr -d '"'); \
				file=$$(echo "$$p" | jq -c '.file // empty' | tr -d '"'); \
				line=$$(echo "$$p" | jq -c '.line // empty' | tr -d '"'); \
				endline=$$(echo "$$p" | jq -c '.endLine // empty' | tr -d '"'); \
				col=$$(echo "$$p" | jq -c '.column // empty' | tr -d '"'); \
				endcol=$$(echo "$$p" | jq -c '.endColumn // empty' | tr -d '"'); \
				message=$$(echo "$$p" | jq -c '.message // empty' | tr -d '"'); \
				exit_code=1; \
				case $$level in \
				"info") \
					echo "::notice file=$${file},line=$${line},endLine=$${endline},col=$${col},endColumn=$${endcol}::$${message}"; \
					;; \
				"warning") \
					echo "::warning file=$${file},line=$${line},endLine=$${endline},col=$${col},endColumn=$${endcol}::$${message}"; \
					;; \
				"error") \
					echo "::error file=$${file},line=$${line},endLine=$${endline},col=$${col},endColumn=$${endcol}::$${message}"; \
					;; \
				esac; \
			done <<< "$$(echo -n "$$files" | xargs shellcheck -f json $(SHELLCHECK_ARGS) | jq -c '.[]')"; \
			exit "$${exit_code}"; \
		else \
			echo -n "$$files" | xargs shellcheck $(SHELLCHECK_ARGS); \
		fi

.PHONY: eslint
eslint: ## Runs the eslint linter.
	@set -e;\
		PATHS=$$( \
			find .github/actions/ actions/ \
				-name package.json -type f \
				-not -path '*/node_modules/*' \
				-not -path '*/third_party/*' | xargs dirname); \
		for path in $$PATHS; do \
			make -C $$path lint; \
		done

.PHONY: yamllint
yamllint: ## Runs the yamllint linter.
	@set -e;\
		extraargs=""; \
		if [ "$(OUTPUT_FORMAT)" == "github" ]; then \
			extraargs="-f github"; \
		fi; \
		yamllint --strict -c .yamllint.yaml . $$extraargs


## Maintenance
#####################################################################

.PHONY: npm-install
npm-install: ## Runs npm install in all action directories simultaneously.
	@set -e;\
		pids=();\
		for action in $(NODE20_ACTIONS) tscommon; do \
			(cd .github/actions/$$action && npm install) & \
			pids+=($$!);\
		done;\
		for pid in "$${pids[@]}"; do \
			wait $$pid || exit 1;\
		done

.PHONY: clean
clean: ## Delete temporary files.
	rm -rf node_modules
