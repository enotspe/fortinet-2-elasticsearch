#!/bin/bash

# ==============================================================================
# Elasticsearch to VictoriaLogs Migration Script (Parallel, Resumable)
#
# Description:
# This script parallelizes the migration by splitting the total time range
# into smaller chunks. It then launches a dedicated, independent worker process
# for each time chunk. Each worker fetches and sends all data for its
# assigned time range. The script is resumable; if interrupted, it will
# pick up where it left off based on state files.
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

# Sort order for the documents. Can be "asc" (ascending) or "desc" (descending).
SORT_ORDER="asc"

# Pagination settings for each worker
PAGE_SIZE=1000

# --- PARALLELISM AND STATE CONFIGURATION ---
# Number of parallel workers to run, each processing a segment of the time range.
# Defaults to the number of available CPU cores.
if command -v nproc &> /dev/null; then
    MAX_WORKERS=$(nproc)
else
    MAX_WORKERS=4 # Fallback if nproc is not available
fi

# Directory to store state files for resumable operation.
STATE_DIR="./migration_state"


# VictoriaLogs Header Configuration
VL_STREAM_FIELDS="fgt.vd,fgt.type,fgt.subtype,network.direction"
VL_TIME_FIELD="${TIMESTAMP_FIELD}"
VL_MSG_FIELD="event.original"
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
    local state_file="${STATE_DIR}/worker_${worker_id}.state"

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
        "-H" "VL-Time-Field: ${VL_TIME_FIELD}"
    )
    if [ -n "$VL_STREAM_FIELDS" ]; then worker_vl_opts+=("-H" "VL-Stream-Fields: ${VL_STREAM_FIELDS}"); fi
    if [ -n "$VL_MSG_FIELD" ]; then worker_vl_opts+=("-H" "VL-Msg-Field: ${VL_MSG_FIELD}"); fi
    if [ -n "$VL_ACCOUNT_ID" ]; then worker_vl_opts+=("-H" "AccountID: ${VL_ACCOUNT_ID}"); fi
    if [ -n "$VL_PROJECT_ID" ]; then worker_vl_opts+=("-H" "ProjectID: ${VL_PROJECT_ID}"); fi
    if [ -n "$VL_EXTRA_FIELDS" ]; then worker_vl_opts+=("-H" "VL-Extra-Fields: ${VL_EXTRA_FIELDS}"); fi

    local search_after_value=""
    local total_processed_by_worker=0

    # Check for a state file to resume from a previous run
    if [ -f "$state_file" ]; then
        search_after_value=$(cat "$state_file")
        echo "[Worker ${worker_id}]: Found state file. Resuming from progress: ${search_after_value}"
    fi

    while true; do
        local base_query
        base_query=$(jq -n \
            --argjson size "$PAGE_SIZE" \
            --arg start_date "$worker_start_date" \
            --arg end_date "$worker_end_date" \
            --arg timestamp_field "$TIMESTAMP_FIELD" \
            --arg sort_order "$SORT_ORDER" \
            '{
                "size": $size,
                "query": { "range": { ($timestamp_field): { "gte": $start_date, "lte": $end_date, "format": "strict_date_optional_time" } } },
                "sort": [ {($timestamp_field): $sort_order}, {"_shard_doc": $sort_order} ]
            }')

        local query
        if [ -z "$search_after_value" ]; then
            query="$base_query"
        else
            query=$(echo "$base_query" | jq --argjson search_after "$search_after_value" '. + {"search_after": $search_after}')
        fi

        local es_start_time=$(date +%s%N)
        local es_response
        es_response=$(curl "${worker_es_opts[@]}" "${ES_HOST}/${ES_INDEX}/_search" -d "${query}")
        local es_end_time=$(date +%s%N)
        local es_duration_ms=$(((es_end_time - es_start_time) / 1000000))

        local hits
        hits=$(echo "${es_response}" | jq -c '.hits.hits')
        local hits_count
        hits_count=$(echo "${hits}" | jq 'length')

        echo "[Worker ${worker_id}]: Fetched ${hits_count} documents from ES in ${es_duration_ms}ms."

        if [ "${hits_count}" -eq 0 ]; then
            break # No more documents in this worker's time range
        fi

        # Always update search_after_value for the next iteration from the last document received.
        # We do this *before* sending to VictoriaLogs. If the send fails, the script will exit,
        # and the next run will resume from this batch, effectively retrying the send.
        search_after_value=$(echo "${es_response}" | jq -c '.hits.hits[-1].sort')
        # Atomically write the new state to the state file
        echo "${search_after_value}" > "${state_file}.tmp"
        mv "${state_file}.tmp" "${state_file}"

        local bulk_data
        bulk_data=$(echo "${hits}" | jq -c '.[] | {"create": {}}, ._source')

        # Only send data if the bulk payload was successfully created
        if [ -n "$bulk_data" ]; then
            local vl_start_time=$(date +%s%N)
            local vl_response
            vl_response=$(curl "${worker_vl_opts[@]}" "${VL_BULK_ENDPOINT}" --data-binary @- <<< "${bulk_data}")
            local vl_end_time=$(date +%s%N)
            local vl_duration_ms=$(((vl_end_time - vl_start_time) / 1000000))
            
            echo "[Worker ${worker_id}]: Sent ${hits_count} documents to VictoriaLogs in ${vl_duration_ms}ms."

            if echo "${vl_response}" | jq -e '.errors == true' > /dev/null; then
                echo "[Worker ${worker_id}]: Error: Ingesting data. Response:"
                echo "${vl_response}"
                exit 1
            fi
            total_processed_by_worker=$((total_processed_by_worker + hits_count))
        else
            echo "[Worker ${worker_id}]: Warning: Generated bulk data is empty for this batch. Skipping send."
        fi

        # Log the current progress timestamp for visibility
        local current_timestamp_ms
        current_timestamp_ms=$(echo "$search_after_value" | jq '.[0]')
        if [ -n "$current_timestamp_ms" ] && [ "$current_timestamp_ms" != "null" ]; then
            local current_timestamp_s=$((current_timestamp_ms / 1000))
            local human_readable_date
            human_readable_date=$(date -u -d "@${current_timestamp_s}" --iso-8601=seconds)
            echo "[Worker ${worker_id}]: Progress: [${worker_start_date} -> ${human_readable_date} -> ${worker_end_date}] (${search_after_value})"
        fi
    done

    echo "[Worker ${worker_id}]: Finished. Processed ${total_processed_by_worker} documents. Cleaning up state file."
    rm -f "$state_file"

    if [ "$DEBUG_MODE" = "true" ]; then
        set +x
    fi
}
export -f run_worker STATE_DIR ES_USER ES_PASS ES_HOST ES_INDEX PAGE_SIZE SORT_ORDER TIMESTAMP_FIELD VL_BULK_ENDPOINT VL_STREAM_FIELDS VL_TIME_FIELD VL_MSG_FIELD VL_EXTRA_FIELDS VL_ACCOUNT_ID VL_PROJECT_ID DEBUG_MODE

# --- Main Script Execution ---

# Check for dependencies
if ! command -v curl &> /dev/null || ! command -v jq &> /dev/null || ! command -v date &> /dev/null; then
    echo "Error: curl, jq, or date is not installed. Please install them to continue."
    exit 1
fi

echo "Starting migration from Elasticsearch to VictoriaLogs..."
echo "Total Time range: ${START_DATE} to ${END_DATE}"
echo "Max parallel workers: ${MAX_WORKERS}"
echo "State directory: ${STATE_DIR}"

# Create the state directory if it doesn't exist
mkdir -p "$STATE_DIR"

# Calculate total time duration and chunk size for each worker using millisecond precision.
# This requires GNU date. On macOS, you might need to install `coreutils` and use `gdate`.
start_epoch_ms=$(($(date -d "$START_DATE" +%s%N) / 1000000))
end_epoch_ms=$(($(date -d "$END_DATE" +%s%N) / 1000000))
total_duration_ms=$((end_epoch_ms - start_epoch_ms))
chunk_duration_ms=$((total_duration_ms / MAX_WORKERS))

if [ "$chunk_duration_ms" -lt 1 ]; then
    echo "Error: Time range is too short to be split among workers. Reduce MAX_WORKERS or increase the time range."
    exit 1
fi

# Launch all workers in the background
for i in $(seq 1 "$MAX_WORKERS"); do
    chunk_start_ms=$((start_epoch_ms + (i - 1) * chunk_duration_ms))
    
    # For the last worker, ensure it goes all the way to the end date
    if [ "$i" -eq "$MAX_WORKERS" ]; then
        chunk_end_ms=$end_epoch_ms
    else
        # The end of the chunk is the start of the next chunk minus 1 millisecond
        chunk_end_ms=$((chunk_start_ms + chunk_duration_ms - 1))
    fi

    # Convert epoch milliseconds back to ISO 8601 format with milliseconds for the worker
    # Example: 2024-01-01T00:00:00.123Z
    worker_start_date=$(date -u -d "@$((${chunk_start_ms} / 1000))" +"%Y-%m-%dT%H:%M:%S").$(printf "%03d" $((${chunk_start_ms} % 1000)))Z
    worker_end_date=$(date -u -d "@$((${chunk_end_ms} / 1000))" +"%Y-%m-%dT%H:%M:%S").$(printf "%03d" $((${chunk_end_ms} % 1000)))Z
    
    # Launch the worker process in the background
    run_worker "$i" "$worker_start_date" "$worker_end_date" &
done

# Give the last worker a moment to start and print its status message.
# This fixes the race condition where the "All workers launched" message
# appears before the last worker's "Starting" message.
sleep 0.5

echo "All workers have been launched. Waiting for them to complete..."
wait # Wait for all background jobs to finish
echo "All workers have finished."

echo "----------------------------------------"
echo "Migration finished!"
echo "----------------------------------------"

