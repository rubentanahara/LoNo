test:
    cargo nextest run

lint:
    cargo fmt --check
    cargo clippy --all-targets -- -D warnings

run:
    cargo run -p lono-app

setup:
    lefthook install
