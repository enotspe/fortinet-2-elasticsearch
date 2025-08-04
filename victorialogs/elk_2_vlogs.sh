#!/bin/bash

# ==============================================================================
# Elasticsearch to VictoriaLogs Migration Script (Parallel Time-Range)
#
# Description:
# This script parallelizes the migration by splitting the total time range
# into smaller chunks. It then launches a dedicated, independent worker process
# for each time chunk. Each worker fetches and sends all data for its
# assigned time range. This is highly effective if the bottleneck is fetching
# data from Elasticsearch.
#
# Dependencies:
# - curl: To make HTTP requests.
# - jq: A lightweight and flexible command-line JSON processor.
# - date (GNU version): For date calculations.
#
# Installation of dependencies (on Debian/Ubuntu):
# sudo apt-get update && sudo apt-get install -y curl jq coreutils
#
# Installation of dependencies (on CentOS/RHEL):
# sudo yum install -y curl jq coreutils
#
# Usage:
# 1. Configure the variables in the "CONFIGURATION" section below.
# 2. Make the script executable: chmod +x es_to_vl_script.sh
# 3. Run the script: ./es_to_vl_script.sh
# ==============================================================================

set -e
set -o pipefail

# --- CONFIGURATION ---

# Elasticsearch settings
ES_HOST="http://localhost:9200"
ES_INDEX="your-index-name"
# Optional: Add Elasticsearch credentials if required
# ES_USER="user"
# ES_PASS="password"

# VictoriaLogs settings
VL_HOST="http://localhost:9428"
# The endpoint for VictoriaLogs that mimics the Elasticsearch Bulk API
VL_BULK_ENDPOINT="${VL_HOST}/insert/elasticsearch/_bulk"

# Time range for the export (ISO 8601 format)
# IMPORTANT: Ensure your `date` command supports the `-d` option for parsing.
START_DATE="2024-01-01T00:00:00.000Z"
END_DATE="2024-01-31T23:59:59.999Z"

# The field in your Elasticsearch documents that contains the timestamp.
TIMESTAMP_FIELD="@timestamp"

# Pagination settings for each worker
PAGE_SIZE=1000

# --- PARALLELISM CONFIGURATION ---
# Number of parallel workers to run, each processing a segment of the time range.
# Defaults to the number of available CPU cores.
if command -v nproc &> /dev/null; then
    MAX_WORKERS=$(nproc)
else
    MAX_WORKERS=4 # Fallback if nproc is not available
fi


# VictoriaLogs Header Configuration
VL_STREAM_FIELDS="kubernetes.namespace_name,kubernetes.pod_name"
VL_TIME_FIELD="${TIMESTAMP_FIELD}"
VL_MSG_FIELD="log"
# VL-Extra-Fields: Comma-separated list of key=value pairs to add to each log entry.
# Example: "source=migration_script,env=production"
VL_EXTRA_FIELDS=""

# VictoriaLogs multi-tenancy headers (optional)
VL_ACCOUNT_ID=""
VL_PROJECT_ID=""

# --- DEBUGGING ---
# Set to "true" to enable verbose logging.
DEBUG_MODE="false"


# --- SCRIPT LOGIC ---

# This function is the worker. It processes a single, dedicated time range.
run_worker() {
    local worker_id=$1
    local worker_start_date=$2
    local worker_end_date=$3

    if [ "$DEBUG_MODE" = "true" ]; then
        set -x
    fi

    echo "[Worker ${worker_id}]: Starting. Range: ${worker_start_date} to ${worker_end_date}"

    # Initialize curl options for this worker
    local worker_es_opts=("-s" "-X" "GET" "-H" "Content-Type: application/json")
    if [ -n "$ES_USER" ] && [ -n "$ES_PASS" ]; then
        worker_es_opts+=("-u" "${ES_USER}:${ES_PASS}")
    fi

    local worker_vl_opts=(
        "-s" "-X" "POST"
        "-H" "Content-Type: application/x-ndjson"
        "-H" "VL-Stream-Fields: ${VL_STREAM_FIELDS}"
        "-H" "VL-Time-Field: ${VL_TIME_FIELD}"
        "-H" "VL-Msg-Field: ${VL_MSG_FIELD}"
    )
    if [ -n "$VL_ACCOUNT_ID" ]; then worker_vl_opts+=("-H" "AccountID: ${VL_ACCOUNT_ID}"); fi
    if [ -n "$VL_PROJECT_ID" ]; then worker_vl_opts+=("-H" "ProjectID: ${VL_PROJECT_ID}"); fi
    if [ -n "$VL_EXTRA_FIELDS" ]; then worker_vl_opts+=("-H" "VL-Extra-Fields: ${VL_EXTRA_FIELDS}"); fi

    local search_after_value=""
    local total_processed_by_worker=0

    while true; do
        local base_query
        base_query=$(jq -n \
            --argjson size "$PAGE_SIZE" \
            --arg start_date "$worker_start_date" \
            --arg end_date "$worker_end_date" \
            --arg timestamp_field "$TIMESTAMP_FIELD" \
            '{
                "size": $size,
                "query": { "range": { ($timestamp_field): { "gte": $start_date, "lte": $end_date, "format": "strict_date_optional_time" } } },
                "sort": [ {($timestamp_field): "asc"}, {"_shard_doc": "asc"} ]
            }')

        local query
        if [ -z "$search_after_value" ]; then
            query="$base_query"
        else
            query=$(echo "$base_query" | jq --argjson search_after "$search_after_value" '. + {"search_after": $search_after}')
        fi

        local es_response
        es_response=$(curl "${worker_es_opts[@]}" "${ES_HOST}/${ES_INDEX}/_search" -d "${query}")

        local hits
        hits=$(echo "${es_response}" | jq -c '.hits.hits')
        local hits_count
        hits_count=$(echo "${hits}" | jq 'length')

        if [ "${hits_count}" -eq 0 ]; then
            break # No more documents in this worker's time range
        fi

        local bulk_data
        bulk_data=$(echo "${hits}" | jq -c '.[] | {"create": {}}, ._source')

        if [ -z "$bulk_data" ]; then
            search_after_value=$(echo "${es_response}" | jq -c '.hits.hits[-1].sort')
            continue
        fi

        echo "[Worker ${worker_id}]: Sending ${hits_count} documents to VictoriaLogs..."
        local vl_response
        vl_response=$(curl "${worker_vl_opts[@]}" "${VL_BULK_ENDPOINT}" --data-binary @- <<< "${bulk_data}")

        if echo "${vl_response}" | jq -e '.errors == true' > /dev/null; then
            echo "Error [Worker ${worker_id}]: Ingesting data. Response:"
            echo "${vl_response}"
            exit 1
        fi

        total_processed_by_worker=$((total_processed_by_worker + hits_count))
        search_after_value=$(echo "${es_response}" | jq -c '.hits.hits[-1].sort')
    done

    echo "[Worker ${worker_id}]: Finished. Processed ${total_processed_by_worker} documents."
    if [ "$DEBUG_MODE" = "true" ]; then
        set +x
    fi
}
export -f run_worker

# --- Main Script Execution ---

# Check for dependencies
if ! command -v curl &> /dev/null || ! command -v jq &> /dev/null || ! command -v date &> /dev/null; then
    echo "Error: curl, jq, or date is not installed. Please install them to continue."
    exit 1
fi

echo "Starting migration from Elasticsearch to VictoriaLogs..."
echo "Total Time range: ${START_DATE} to ${END_DATE}"
echo "Max parallel workers: ${MAX_WORKERS}"

# Calculate total time duration and chunk size for each worker
# This requires GNU date. On macOS, you might need to install `coreutils` and use `gdate`.
start_epoch=$(date -d "$START_DATE" +%s)
end_epoch=$(date -d "$END_DATE" +%s)
total_duration=$((end_epoch - start_epoch))
chunk_duration=$((total_duration / MAX_WORKERS))

if [ "$chunk_duration" -lt 1 ]; then
    echo "Error: Time range is too short to be split among workers. Reduce MAX_WORKERS or increase the time range."
    exit 1
fi

# Launch all workers in the background
for i in $(seq 1 "$MAX_WORKERS"); do
    chunk_start_epoch=$((start_epoch + (i - 1) * chunk_duration))

    # For the last worker, ensure it goes all the way to the end date
    if [ "$i" -eq "$MAX_WORKERS" ]; then
        chunk_end_epoch=$end_epoch
    else
        chunk_end_epoch=$((chunk_start_epoch + chunk_duration - 1))
    fi

    # Convert epoch times back to ISO 8601 format for the worker
    worker_start_date=$(date -u -d "@${chunk_start_epoch}" --iso-8601=seconds)
    worker_end_date=$(date -u -d "@${chunk_end_epoch}" --iso-8601=seconds)

    # Launch the worker process in the background
    run_worker "$i" "$worker_start_date" "$worker_end_date" &
done

echo "All workers have been launched. Waiting for them to complete..."
wait # Wait for all background jobs to finish
echo "All workers have finished."

echo "----------------------------------------"
echo "Migration finished!"
echo "----------------------------------------"
