# Credential setup

## Microsoft Graph

This repository uses app-only OAuth 2.0 client credentials.

1. Open Microsoft Entra admin center.
2. Select **Identity > Applications > App registrations > New registration**.
3. Name it `outlook-priority-alerts`, choose a single-tenant registration, then register.
4. From **Overview**, copy **Directory (tenant) ID** and **Application (client) ID**.
5. Open **API permissions > Add a permission > Microsoft Graph > Application permissions**.
6. Add **Mail.Read** and have a tenant administrator grant admin consent.
7. Open **Certificates & secrets > Client secrets > New client secret**.
8. Copy the secret **Value** immediately. The Secret ID is not the credential.
9. Use the mailbox user principal name as `<MAILBOX_UPN>`.

Application permissions always require administrator consent. In a corporate tenant, request mailbox-level restriction from the Microsoft 365 administrator. Prefer certificates or managed workload identity for production when feasible.

## Twilio

1. Sign in to Twilio Console.
2. In **Account Info**, copy the **Account SID** beginning `AC`.
3. Reveal and copy the **Auth Token**. Treat it as a password.
4. Under **Phone Numbers > Manage > Active numbers**, select an SMS-capable sender.
5. Copy sender and destination numbers in E.164 format, such as `+91XXXXXXXXXX`.
6. On a trial account, verify the destination number before testing.

Snowflake stores the Account SID as the username and the Auth Token as the password in `TWILIO_SECRET`.

## Snowflake

You need a warehouse, Cortex AI access, and rights to create the database, schema, secrets, network rule, external access integration, procedures, tables and task.

External access uses:

1. `TRIAGE_EGRESS`, allowing only Microsoft login, Graph and Twilio hosts.
2. `GRAPH_SECRET` and `TWILIO_SECRET`.
3. `TRIAGE_EAI`, which binds allowed hosts and secrets.
4. Procedure-level `EXTERNAL_ACCESS_INTEGRATIONS` and `SECRETS` clauses.

## Secret hygiene

Never commit Microsoft client secrets, Twilio Auth Tokens, Snowflake passwords/private keys, or production phone numbers. Before pushing:

```powershell
git diff --cached
git status --ignored
```

Rotate any real secret that has appeared in Git history or screenshots shared outside the trusted team.
