# Backend environment

| Variable | Purpose |
|---|---|
| `PORT` | HTTP port, defaults to 8080 |
| `DB_PATH` | SQLite file location |
| `B2_KEY_ID` / `B2_APP_KEY` | Backblaze B2 credentials |
| `B2_BUCKET_ID` | Target bucket |
| `MAIL_MODE` | `log`, `smtp` or `api` |
| `SMTP_HOST` / `SMTP_USER` / `SMTP_PASS` | SMTP delivery |
| `GROQ_API_KEY` | AI advisory features |

Secrets are never committed; use `.env.render` on the host.
