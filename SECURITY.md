# Security

This is a home-lab / small-service toolkit, not a hardened enterprise product.
Use it at your own risk and test on a disposable VPS first.

## Reporting a vulnerability

If you find a security issue in these scripts, please do not open a public
issue with exploit details. Contact the maintainer privately through GitHub
(`@jefo`) and give a short reproduction.

## Secrets

- Do not commit `.env`, `credentials.toml`, `rules.toml`, client profiles, or
  generated configs.
- The repository's `.gitignore` excludes the common cases, but check
  `git status --ignored` before publishing.
- Rotate any credential that has ever been committed or shared in an archive.

## Scope

The scripts are intended for a single Ubuntu VPS with a small number of
clients. They do not provide multi-tenant isolation, billing, a control panel,
or an enterprise SLA.
