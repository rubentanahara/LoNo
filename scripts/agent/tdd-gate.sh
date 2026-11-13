#!/bin/sh
# Called by .husky/commit-msg. Enforces: red commit (failing tests) first, then green commit (make check passes).
# Override per project in .tdd.conf (sh syntax): TEST_PATTERN, TEST_CONTENT_PATTERN, NON_SOURCE_PATTERN.

message_file=$1
subject=$(head -n1 "$message_file")

# shellcheck disable=SC1091
[ -f .tdd.conf ] && . ./.tdd.conf

TEST_CONTENT_PATTERN=${TEST_CONTENT_PATTERN:-'^\+.*(#\[test\]|#\[cfg\(test\)\]|@Test\b|\[(Fact|Test|TestMethod|Theory)\]|\b(describe|it|test)\(|def test_|func Test[A-Z]|\bassert)'}
TEST_PATTERN=${TEST_PATTERN:-'(^|/)(tests?|__tests__|spec)/|(^|/)test_|[._]test\.|[._]spec\.|_test\.|Tests?\.[a-z]+$'}
NON_SOURCE_PATTERN=${NON_SOURCE_PATTERN:-'\.(md|json|ya?ml|toml|lock|txt)$|^(Makefile|\.gitignore)$|^(\.husky|\.claude|\.codex|\.github|scripts|docs)/'}

refuse() {
  echo "TDD gate: $1" >&2
  exit 1
}

has_red_commit_on_branch() {
  { git log --format=%s main..HEAD 2> /dev/null || git log -n 50 --format=%s 2> /dev/null; } | grep -qE '^test\(red\)'
}

has_waiver() {
  sed '/^# -* >8 -*$/,$d' "$message_file" | grep -v '^#' | grep -qE '^No-Tests: .+'
}

case $subject in
  revert*|Merge*) exit 0 ;;
esac

staged=$(git diff --cached --name-only)
staged_tests=$(echo "$staged" | grep -E "$TEST_PATTERN")
staged_source=$(echo "$staged" | grep -vE "$TEST_PATTERN" | grep -vE "$NON_SOURCE_PATTERN")
if [ -z "$staged_tests" ] && git diff --cached -U0 | grep -qE "$TEST_CONTENT_PATTERN"; then
  staged_tests=content
fi

case $subject in
  test\(red\)*)
    [ -n "$staged_tests" ] || refuse "a red commit must stage a test file."
    if make test > /dev/null 2>&1; then
      refuse "red commit, but make test passes. Write a test that fails for the behavior you are about to add."
    fi
    exit 0
    ;;
esac

[ -n "$staged_source" ] || exit 0

if ! has_waiver && ! has_red_commit_on_branch; then
  refuse "source changed but this branch has no 'test(red): ...' commit. Commit the failing tests first, or add a line 'No-Tests: <reason>' to the message."
fi

make check > /dev/null 2>&1 || refuse "make check fails. A green commit needs passing build, lint and tests. Run make check."
