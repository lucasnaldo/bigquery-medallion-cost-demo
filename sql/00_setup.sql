-- Layers live in separate datasets so access can be granted per layer
-- (e.g. analysts and LLM agents read gold only). Public source data is in US.
CREATE SCHEMA IF NOT EXISTS bronze OPTIONS (location = 'US', description = 'Raw copies of source tables. No business logic. Audit columns only.');
CREATE SCHEMA IF NOT EXISTS silver OPTIONS (location = 'US', description = 'Clean, typed, deduplicated, partitioned and clustered tables. Calculated fields are defined here once.');
CREATE SCHEMA IF NOT EXISTS gold   OPTIONS (location = 'US', description = 'Business-ready models per use case. The only layer dashboards and AI agents should query.');
CREATE SCHEMA IF NOT EXISTS ops    OPTIONS (location = 'US', description = 'Data quality results and cost monitoring.');
