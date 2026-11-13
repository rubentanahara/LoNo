# Security

## Secrets
- Never commit secrets, tokens, or `.env` files. `.husky/pre-commit` runs gitleaks.
- Secrets come from: None used yet. Planned: encryption keys in the macOS Keychain (`keyring`), AWS credentials via Cognito and IAM, never in the repo.

## Trust Boundaries
- Untrusted input enters at: Markdown import, embedded web content, and (planned) sync payloads from the server.
- Validation happens at: `core` constructors and parsers (`Note`, `NoteId`); sync and import checks are planned with those phases.
- Note content is sensitive: never log it or send it to Sentry or metrics. The server stores ciphertext only (planned E2E: XChaCha20-Poly1305, Argon2id).

## Agent Permissions
- Allowed without asking: see `permissions.allow` in `.claude/settings.json`
- Requires human approval: new dependencies, schema or public API changes, destructive commands
- Forbidden: push to `main`, force-push, reading `.env`

## Dependencies
- Check current docs and maintenance status before adding one.

## Reporting
- Report a vulnerability to: the repo owner (@rubentanahara) through GitHub private vulnerability reporting at https://github.com/rubentanahara/LoNo/security/advisories/new. Do not open a public issue.
