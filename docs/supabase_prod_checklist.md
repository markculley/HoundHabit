# Production Checklist

## Supabase
* [Harden Data Api](https://supabase.com/docs/guides/api/hardening-data-api)
* [Row Level Security](https://supabase.com/docs/guides/database/postgres/row-level-security)
* [Production Checklist](https://supabase.com/docs/guides/deployment/going-into-prod)

Action Required: OpenAPI spec access via anon key deprecated March 11. The /rest/v1/  schema endpoint will only be accessible via service role or secret API keys after this date. Existing data API usage is unaffected.