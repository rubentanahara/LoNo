# LoNo

Local-first notes app. See [PRD.md](PRD.md).

## Develop

Requires [rustup](https://rustup.rs), [just](https://github.com/casey/just) and [cargo-nextest](https://nexte.st).

- `just test` runs the tests with nextest.
- `just lint` runs `cargo fmt --check` and `cargo clippy -D warnings`.
- `just run` starts the app.
