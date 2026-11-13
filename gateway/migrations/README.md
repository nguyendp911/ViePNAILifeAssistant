# Database schema

Initial PostgreSQL tables are created by `initPostgres()` at Gateway startup:
`viepn_users`, `viepn_sessions`, and `viepn_state`.

For production, replace this startup initializer with a controlled, versioned migration pipeline
and provision a database role with only the minimum runtime permissions.
