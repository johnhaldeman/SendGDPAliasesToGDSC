#!/bin/bash

# Script to retrieve IP aliases from Guardium and save to JSON file
# Usage: ./get_guardium_aliases.sh <guardium_url> <client_id> <client_secret> <username> <password>

set -e  # Exit on error

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
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

# Check if required arguments are provided
if [ "$#" -ne 5 ]; then
    print_error "Invalid number of arguments"
    echo "Usage: $0 <guardium_url> <client_id> <client_secret> <username> <password>"
    echo ""
    echo "Example:"
    echo "  $0 https://sith-gdp-20250915.dev.fyre.ibm.com:8443 aliases 6c1b5f0c-1800-2145-86cb-6cf6cba9a1aa admin 'GuardiumRocks!1'"
    exit 1
fi

# Assign arguments to variables
GUARDIUM_URL="$1"
CLIENT_ID="$2"
CLIENT_SECRET="$3"
USERNAME="$4"
PASSWORD="$5"
OUTPUT_FILE="retrieved_aliases.json"

# Remove trailing slash from URL if present
GUARDIUM_URL="${GUARDIUM_URL%/}"

print_info "Starting Guardium IP aliases retrieval..."
print_info "Guardium URL: $GUARDIUM_URL"
print_info "Client ID: $CLIENT_ID"
print_info "Username: $USERNAME"

# Step 1: Get OAuth token
print_info "Step 1: Requesting OAuth token..."

TOKEN_RESPONSE=$(curl -k -s -X POST \
    -d "client_id=${CLIENT_ID}&client_secret=${CLIENT_SECRET}&grant_type=password&username=${USERNAME}&password=${PASSWORD}" \
    "${GUARDIUM_URL}/oauth/token")

# Check if token request was successful
if [ -z "$TOKEN_RESPONSE" ]; then
    print_error "Failed to get token response from Guardium"
    exit 1
fi

# Extract access token using grep and sed (more portable than jq)
ACCESS_TOKEN=$(echo "$TOKEN_RESPONSE" | grep -o '"access_token":"[^"]*"' | sed 's/"access_token":"\(.*\)"/\1/')

if [ -z "$ACCESS_TOKEN" ]; then
    print_error "Failed to extract access token from response"
    echo "Response received: $TOKEN_RESPONSE"
    exit 1
fi

print_success "OAuth token obtained successfully"
print_info "Token: ${ACCESS_TOKEN:0:10}..." # Show only first 10 chars for security

# Step 2: Get IP aliases
print_info "Step 2: Retrieving IP aliases..."

ALIASES_RESPONSE=$(curl -k -s \
    --header "Authorization:Bearer ${ACCESS_TOKEN}" \
    -H "Content-Type:application/json" \
    -X GET \
    "${GUARDIUM_URL}/restAPI/alias?groupTypeDescLike=Client+IP")

# Check if aliases request was successful
if [ -z "$ALIASES_RESPONSE" ]; then
    print_error "Failed to get aliases response from Guardium"
    exit 1
fi

# Check if response contains an error
if echo "$ALIASES_RESPONSE" | grep -q '"error"'; then
    print_error "API returned an error"
    echo "Response: $ALIASES_RESPONSE"
    exit 1
fi

# Step 3: Save to file
print_info "Step 3: Saving aliases to $OUTPUT_FILE..."

echo "$ALIASES_RESPONSE" > "$OUTPUT_FILE"

# Verify file was created and has content
if [ ! -s "$OUTPUT_FILE" ]; then
    print_error "Failed to create output file or file is empty"
    exit 1
fi

print_success "IP aliases successfully retrieved and saved to $OUTPUT_FILE"

# Display file size and preview
FILE_SIZE=$(wc -c < "$OUTPUT_FILE")
print_info "File size: $FILE_SIZE bytes"


print_success "Script completed successfully!"

# Made with Bob
