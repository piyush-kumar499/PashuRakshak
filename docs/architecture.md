# Architecture

## Clients
Two Android apps share a Kotlin core module for models, networking and
local persistence. Both talk to the same REST API.

## Backend
`shared-backend` is a small Express service backed by SQLite. Photos are
stored in Backblaze B2; the API only keeps metadata and object keys.

## Sync model
The apps are local-first. Writes go to the local database first and are
queued for upload; the queue is drained when connectivity returns.
Conflicts resolve last-write-wins on `updated_at`.

## Auth
OTP over email, exchanged for a short lived session token. Roles are
`farmer`, `vet` and `gov`.
