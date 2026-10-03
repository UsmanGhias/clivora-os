# Security Policy

Security and user trust are release requirements for CLIVORA.

## Report a vulnerability privately

Do not open a public issue for a security problem.

Use GitHub's **Report a vulnerability** button on the Security tab of this repository. If that is not possible, email **contact@clivora.io** with the subject `[SECURITY] CLIVORA` and include:

- the affected component (`apps/web`, `apps/mobile`, `supabase/`) and version or commit;
- steps to reproduce, and the impact you observed;
- any proof-of-concept, kept to the minimum needed to demonstrate the issue.

We aim to acknowledge reports within 3 business days and to agree a disclosure timeline with you.

## Scope

In scope: code in this repository, including row-level security policies and database functions in `supabase/migrations`, edge functions, the web app and the Android app.

Out of scope: self-hosted deployments operated by third parties (report those to the operator), denial-of-service volume testing, and social engineering.

## Testing rules

- Test only against your own local or self-hosted deployment, never against clivora.io or another operator's instance.
- Do not access, modify or retain other people's data.
- Do not attempt to access payment, email, hosting or app-store accounts.

## Secrets

This repository must never contain credentials. Every key, password and project URL is supplied through environment variables, Supabase secrets or Vault. CI runs a secret scan on every push and pull request; if you find a credential in the history, report it privately as above.
