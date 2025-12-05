#!/bin/bash

# Script to upload IP aliases from retrieved_aliases.json to GDSC (Guardium Data Security Center)
# Usage: ./upload_aliases_to_gdsc.sh <gdsc_url> <api_token> [dataset_name] [input_file]

set -e  # Exit on error

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored messages
print_error() {
    echo -e "${RED}ERROR: $1${NC}" >&2
}

print_success() {
    echo -e "${GREEN}SUCCESS: $1${NC}"
}

print_info() {
    echo -e "${YELLOW}INFO: $1${NC}"
}

print_step() {
    echo -e "${BLUE}STEP $1: $2${NC}"
}

# Function to display usage
show_usage() {
    echo "Usage: $0 <gdsc_url> <api_token> [dataset_name] [input_file]"
    echo ""
    echo "Arguments:"
    echo "  gdsc_url       - GDSC server URL (e.g., https://dev03.dev.guardium.security.ibm.com)"
    echo "  api_token      - GDSC API authorization token (Basic auth format)"
    echo "  dataset_name   - Optional: Name of the dataset (default: GDP_IP_ALIASES)"
    echo "  input_file     - Optional: JSON file with aliases (default: retrieved_aliases.json)"
    echo ""
    echo "Example:"
    echo "  $0 https://dev03.dev.guardium.security.ibm.com 'Basic OTNjZjM0MmUtZjU3ZC00OWJkLTg3ZDUtMmRiNjVmZDY1MDkxOmIwY2M5YzU1LTM0NmEtNDQ2My05MGUzLTcwMjExYWVjMTJlMw=='"
    echo "  $0 https://dev03.dev.guardium.security.ibm.com 'Basic OTNjZjM0MmUtZjU3ZC00OWJkLTg3ZDUtMmRiNjVmZDY1MDkxOmIwY2M5YzU1LTM0NmEtNDQ2My05MGUzLTcwMjExYWVjMTJlMw==' MY_DATASET"
    echo "  $0 https://dev03.dev.guardium.security.ibm.com 'Basic OTNjZjM0MmUtZjU3ZC00OWJkLTg3ZDUtMmRiNjVmZDY1MDkxOmIwY2M5YzU1LTM0NmEtNDQ2My05MGUzLTcwMjExYWVjMTJlMw==' MY_DATASET custom_aliases.json"
    echo ""
    echo "Note: This script requires 'jq' to be installed for JSON processing."
}

# Check if jq is installed
if ! command -v jq &> /dev/null; then
    print_error "jq is not installed. This script requires jq for JSON processing."
    echo ""
    echo "To install jq:"
    echo "  - Ubuntu/Debian: sudo apt-get install jq"
    echo "  - RHEL/CentOS:   sudo yum install jq"
    echo "  - macOS:         brew install jq"
    echo "  - Or visit:      https://stedolan.github.io/jq/download/"
    exit 1
fi

# Check if required arguments are provided
if [ "$#" -lt 2 ]; then
    print_error "Invalid number of arguments"
    echo ""
    show_usage
    exit 1
fi

# Assign arguments to variables
GDSC_URL="$1"
API_TOKEN="$2"
DATASET_NAME="${3:-GDP_IP_ALIASES}"
INPUT_FILE="${4:-retrieved_aliases.json}"
BATCH_SIZE=250

# Remove trailing slash from URL if present
GDSC_URL="${GDSC_URL%/}"

# Check if input file exists
if [ ! -f "$INPUT_FILE" ]; then
    print_error "Input file '$INPUT_FILE' not found"
    exit 1
fi

# Validate JSON file
if ! jq empty "$INPUT_FILE" 2>/dev/null; then
    print_error "Input file '$INPUT_FILE' is not valid JSON"
    exit 1
fi

print_info "Starting GDSC dataset upload process..."
print_info "GDSC URL: $GDSC_URL"
print_info "Dataset Name: $DATASET_NAME"
print_info "Input File: $INPUT_FILE"
print_info "Batch Size: $BATCH_SIZE"
echo ""

# Step 1: Check if dataset exists
print_step "1" "Checking if dataset '$DATASET_NAME' exists..."

DATASET_CHECK_RESPONSE=$(curl -s -w "\n%{http_code}" -X GET \
    "${GDSC_URL}/api/v3/integrations/datasets/${DATASET_NAME}/details" \
    -H 'accept: application/json' \
    -H "authorization: ${API_TOKEN}")

HTTP_CODE=$(echo "$DATASET_CHECK_RESPONSE" | tail -n1)
RESPONSE_BODY=$(echo "$DATASET_CHECK_RESPONSE" | sed '$d')

if [ "$HTTP_CODE" -eq 200 ]; then
    # Check if response is empty JSON object
    if [ "$RESPONSE_BODY" = "{}" ]; then
        DATASET_EXISTS=false
        print_info "Dataset does not exist. Will create it."
    else
        DATASET_EXISTS=true
        print_success "Dataset exists"
    fi
elif [ "$HTTP_CODE" -eq 404 ]; then
    DATASET_EXISTS=false
    print_info "Dataset does not exist. Will create it."
else
    print_error "Failed to check dataset existence (HTTP $HTTP_CODE)"
    echo "Response: $RESPONSE_BODY"
    exit 1
fi

echo ""

# Step 2: Create dataset if it doesn't exist
if [ "$DATASET_EXISTS" = false ]; then
    print_step "2" "Creating dataset '$DATASET_NAME'..."
    
    CREATE_PAYLOAD=$(cat <<EOF
{
  "detail": {
    "columns": [
      {
        "allow_null": true,
        "column_id": 0,
        "column_name": "IP_ADDRESS",
        "column_size": "15",
        "column_type": "TEXT",
        "unique": true
      },
      {
        "allow_null": true,
        "column_id": 0,
        "column_name": "ALIAS_HOSTNAME",
        "column_size": "256",
        "column_type": "TEXT",
        "unique": false
      }
    ],
    "dataset_name": "$DATASET_NAME",
    "description": "IP aliases imported from GDP",
    "editable": true
  },
  "is_new": true
}
EOF
)
    
    CREATE_RESPONSE=$(curl -s -w "\n%{http_code}" -X POST \
        "${GDSC_URL}/api/v3/integrations/datasets" \
        -H 'accept: application/json' \
        -H "authorization: ${API_TOKEN}" \
        -H 'Content-Type: application/json' \
        -d "$CREATE_PAYLOAD")
    
    HTTP_CODE=$(echo "$CREATE_RESPONSE" | tail -n1)
    RESPONSE_BODY=$(echo "$CREATE_RESPONSE" | sed '$d')
    
    if [ "$HTTP_CODE" -eq 200 ]; then
        if echo "$RESPONSE_BODY" | jq -e '.status.message == "Success"' > /dev/null 2>&1; then
            print_success "Dataset created successfully"
        else
            print_error "Dataset creation returned unexpected response"
            echo "Response: $RESPONSE_BODY"
            exit 1
        fi
    else
        print_error "Failed to create dataset (HTTP $HTTP_CODE)"
        echo "Response: $RESPONSE_BODY"
        exit 1
    fi
else
    print_step "2" "Dataset already exists, skipping creation"
fi

echo ""

# Step 3: Purge existing data from dataset
print_step "3" "Purging existing data from dataset '$DATASET_NAME'..."

PURGE_RESPONSE=$(curl -s -w "\n%{http_code}" -X DELETE \
    "${GDSC_URL}/api/v3/integrations/datasets/data?dataset_names=${DATASET_NAME}" \
    -H 'accept: application/json' \
    -H "authorization: ${API_TOKEN}")

HTTP_CODE=$(echo "$PURGE_RESPONSE" | tail -n1)
RESPONSE_BODY=$(echo "$PURGE_RESPONSE" | sed '$d')

if [ "$HTTP_CODE" -eq 200 ]; then
    if echo "$RESPONSE_BODY" | jq -e '.status.message == "Success"' > /dev/null 2>&1; then
        print_success "Dataset purged successfully"
    else
        print_error "Dataset purge returned unexpected response"
        echo "Response: $RESPONSE_BODY"
        exit 1
    fi
else
    print_error "Failed to purge dataset (HTTP $HTTP_CODE)"
    echo "Response: $RESPONSE_BODY"
    exit 1
fi

echo ""

# Step 4: Read aliases and upload in batches
print_step "4" "Reading aliases from '$INPUT_FILE' and uploading to GDSC..."

# Count total aliases
TOTAL_ALIASES=$(jq 'length' "$INPUT_FILE")
print_info "Total aliases to upload: $TOTAL_ALIASES"

if [ "$TOTAL_ALIASES" -eq 0 ]; then
    print_error "No aliases found in input file"
    exit 1
fi

# Calculate number of batches
TOTAL_BATCHES=$(( (TOTAL_ALIASES + BATCH_SIZE - 1) / BATCH_SIZE ))
print_info "Will upload in $TOTAL_BATCHES batch(es) of up to $BATCH_SIZE entries each"
echo ""

UPLOADED_COUNT=0
FAILED_COUNT=0

# Process in batches
for ((batch=0; batch<TOTAL_BATCHES; batch++)); do
    START_INDEX=$((batch * BATCH_SIZE))
    END_INDEX=$((START_INDEX + BATCH_SIZE))
    
    if [ $END_INDEX -gt $TOTAL_ALIASES ]; then
        END_INDEX=$TOTAL_ALIASES
    fi
    
    BATCH_NUM=$((batch + 1))
    BATCH_COUNT=$((END_INDEX - START_INDEX))
    
    print_info "Uploading batch $BATCH_NUM/$TOTAL_BATCHES (entries $((START_INDEX + 1))-$END_INDEX)..."
    
    # Build batch payload
    BATCH_PAYLOAD=$(jq -n \
        --arg dataset_name "$DATASET_NAME" \
        --argjson aliases "$(jq "[.[$START_INDEX:$END_INDEX] | .[] | {entry: {IP_ADDRESS: .DbValue, ALIAS_HOSTNAME: .AliasValue}}]" "$INPUT_FILE")" \
        '{dataset_name: $dataset_name, entries: $aliases}')
    
    # Upload batch
    UPLOAD_RESPONSE=$(curl -s -w "\n%{http_code}" -X POST \
        "${GDSC_URL}/api/v3/integrations/datasets/${DATASET_NAME}" \
        -H 'accept: application/json' \
        -H "authorization: ${API_TOKEN}" \
        -H 'Content-Type: application/json' \
        -d "$BATCH_PAYLOAD")
    
    HTTP_CODE=$(echo "$UPLOAD_RESPONSE" | tail -n1)
    RESPONSE_BODY=$(echo "$UPLOAD_RESPONSE" | sed '$d')
    
    if [ "$HTTP_CODE" -eq 200 ]; then
        if echo "$RESPONSE_BODY" | jq -e '.status.message == "Success"' > /dev/null 2>&1; then
            print_success "Batch $BATCH_NUM uploaded successfully ($BATCH_COUNT entries)"
            UPLOADED_COUNT=$((UPLOADED_COUNT + BATCH_COUNT))
        else
            print_error "Batch $BATCH_NUM returned unexpected response"
            echo "Response: $RESPONSE_BODY"
            FAILED_COUNT=$((FAILED_COUNT + BATCH_COUNT))
        fi
    else
        print_error "Failed to upload batch $BATCH_NUM (HTTP $HTTP_CODE)"
        echo "Response: $RESPONSE_BODY"
        FAILED_COUNT=$((FAILED_COUNT + BATCH_COUNT))
    fi
done

echo ""
print_info "Upload Summary:"
print_info "  Total aliases: $TOTAL_ALIASES"
print_info "  Successfully uploaded: $UPLOADED_COUNT"
print_info "  Failed: $FAILED_COUNT"

if [ $FAILED_COUNT -eq 0 ]; then
    echo ""
    print_success "All aliases uploaded successfully to GDSC dataset '$DATASET_NAME'!"
    exit 0
else
    echo ""
    print_error "Some aliases failed to upload. Please check the errors above."
    exit 1
fi

# Made with Bob