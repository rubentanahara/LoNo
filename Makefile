LOGS := .agent

INSTALL_CMD := cargo fetch
BUILD_CMD := cargo build --all-targets
LINT_CMD := cargo clippy --all-targets -- -D warnings
FORMAT_CMD := cargo fmt
TEST_CMD := cargo test
TEST_STORY_CMD := cargo test "$$FILTER"
RUN_CMD := cargo run

.PHONY: check setup build lint test test-story format run hooks clean

check: hooks build lint test
	@echo "CHECK PASSED: hooks, build, lint, tests"

setup:
	git config core.hooksPath .husky
	$(INSTALL_CMD)
	@command -v gitleaks >/dev/null || echo "WARNING: gitleaks is not installed; the pre-commit hook needs it."
	@command -v jq >/dev/null || echo "WARNING: jq is not installed; make check and the scripts in scripts/agent need it."
	@echo "OK   setup. Run make check next."

build:
	@mkdir -p $(LOGS)
	@$(BUILD_CMD) > $(LOGS)/build.log 2>&1 || { \
		tail -20 $(LOGS)/build.log; \
		echo "CHECK FAILED at build. Full log in $(LOGS)/build.log. Fix the errors, then run make check."; \
		exit 1; }
	@echo "OK   build"

lint:
	@mkdir -p $(LOGS)
	@$(LINT_CMD) > $(LOGS)/lint.log 2>&1 || { \
		tail -20 $(LOGS)/lint.log; \
		echo "CHECK FAILED at lint. Run make format to fix it automatically, then run make check."; \
		exit 1; }
	@echo "OK   lint"

test: build
	@$(TEST_CMD) > $(LOGS)/test.log 2>&1 || { \
		tail -40 $(LOGS)/test.log; \
		echo "CHECK FAILED at tests. Full log in $(LOGS)/test.log. Fix the code, not the test, unless the test is wrong."; \
		exit 1; }
	@echo "OK   tests"

test-story: build
	@test -n "$(FILTER)" || { echo "Pass a filter: make test-story FILTER=<filter>"; exit 1; }
	@FILTER="$(FILTER)" $(TEST_STORY_CMD)

hooks:
	@jq -n -e --slurpfile claude .claude/settings.json --slurpfile codex .codex/hooks.json '$$claude[0].hooks != null and $$claude[0].hooks == $$codex[0].hooks' > /dev/null || { \
		echo "CHECK FAILED at hooks. .codex/hooks.json differs from the hooks in .claude/settings.json. Edit .claude/settings.json, then run: jq '{hooks}' .claude/settings.json > .codex/hooks.json"; \
		exit 1; }
	@echo "OK   hooks"

format:
	$(FORMAT_CMD)
	@echo "OK   format"

run:
	$(RUN_CMD)

clean:
	rm -rf $(LOGS)
	@echo "OK   clean"
