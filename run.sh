#!/usr/bin/env bash
# Builds bronze -> silver -> gold, runs data quality checks and prints the cost comparison.
# Works in the free BigQuery sandbox (no billing account). Requires: gcloud SDK (bq), a project id.
#   ./run.sh my-sandbox-project
set -euo pipefail
PROJECT="${1:?usage: ./run.sh <gcp-project-id>}"
BQ="bq --project_id=$PROJECT query --use_legacy_sql=false --location=US --quiet"
cd "$(dirname "$0")"

for f in sql/00_setup.sql sql/10_bronze.sql sql/20_silver.sql sql/30_gold.sql sql/40_quality.sql; do
  echo ">> $f"
  $BQ < "$f"
done

echo
echo "== Cost comparison: same question, four ways (dry run, nothing is billed) =="
printf "%-4s %-55s %12s\n" "" "approach" "MiB scanned"
for q in A B C D; do
  sql=$(sed -n "/^-- $q\$/,/^-- END $q\$/p" sql/50_cost_demo.sql)
  label=$(echo "$sql" | sed -n '2p' | sed 's/^-- //' | cut -c1-55)
  bytes=$(bq --project_id="$PROJECT" query --use_legacy_sql=false --location=US --dry_run --format=json <<< "$sql" \
          | python3 -c 'import sys,json; print(json.load(sys.stdin)["statistics"]["totalBytesProcessed"])')
  printf "%-4s %-55s %12.1f\n" "$q" "$label" "$(awk -v b="$bytes" 'BEGIN{print b/1048576}')"
done
echo
echo "Cost report of your own recent queries: sql/60_jobs_cost_report.sql"
