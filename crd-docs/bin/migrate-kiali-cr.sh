#!/bin/bash

# migrate-kiali-cr.sh - Convert Kiali CR from old schema to new schema

set -e

# Default values
INPUT_FILE=""
OUTPUT_FILE=""
SHOW_DIFF=false
BACKUP_ORIGINAL=true

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

usage() {
    echo "Usage: $0 -i <input-file> [-o <output-file>] [-d <true|false>] [-n <true|false>]"
    echo ""
    echo "Convert Kiali CR from old schema to new schema"
    echo ""
    echo "Options:"
    echo "  -i, --input <file>     Input Kiali CR YAML file (required)"
    echo "  -o, --output <file>    Output file (default: <input>-migrated.yaml)"
    echo "  -d, --diff <bool>      Show diff between old and new (true|false, default: false)"
    echo "  -n, --no-backup <bool> Don't create backup of original file (true|false, default: false)"
    echo "  -h, --help             Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 -i my-kiali.yaml"
    echo "  $0 -i my-kiali.yaml -o new-kiali.yaml -d true"
    echo "  $0 -i my-kiali.yaml -n true -d false"
    exit 1
}

# Function to validate boolean values
validate_boolean() {
    local value="$1"
    local option="$2"
    if [[ "$value" != "true" && "$value" != "false" ]]; then
        echo -e "${RED}Error: $option must be 'true' or 'false', got '$value'${NC}"
        exit 1
    fi
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -i|--input)
            INPUT_FILE="$2"
            shift 2
            ;;
        -o|--output)
            OUTPUT_FILE="$2"
            shift 2
            ;;
        -d|--diff)
            validate_boolean "$2" "--diff"
            SHOW_DIFF="$2"
            shift 2
            ;;
        -n|--no-backup)
            validate_boolean "$2" "--no-backup"
            # Note: --no-backup true means don't backup (BACKUP_ORIGINAL=false)
            #       --no-backup false means do backup (BACKUP_ORIGINAL=true)
            if [[ "$2" == "true" ]]; then
                BACKUP_ORIGINAL=false
            else
                BACKUP_ORIGINAL=true
            fi
            shift 2
            ;;
        -h|--help)
            usage
            ;;
        *)
            echo "Unknown option: $1"
            usage
            ;;
    esac
done

# Validate required arguments
if [[ -z "$INPUT_FILE" ]]; then
    echo -e "${RED}Error: Input file is required${NC}"
    usage
fi

if [[ ! -f "$INPUT_FILE" ]]; then
    echo -e "${RED}Error: Input file '$INPUT_FILE' does not exist${NC}"
    exit 1
fi

# Set default output file if not specified
if [[ -z "$OUTPUT_FILE" ]]; then
    OUTPUT_FILE="${INPUT_FILE%.*}-migrated.yaml"
fi

# Check if yq is installed
if ! command -v yq &> /dev/null; then
    echo -e "${RED}Error: 'yq' is required but not installed.${NC}"
    echo "Please install yq: https://github.com/mikefarah/yq"
    exit 1
fi

echo -e "${BLUE}🔄 Migrating Kiali CR from old schema to new schema${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

# Create backup if requested
if [[ "$BACKUP_ORIGINAL" == true ]]; then
    BACKUP_FILE="${INPUT_FILE}.bak"
    echo -e "${YELLOW}📋 Creating backup: $BACKUP_FILE${NC}"
    cp "$INPUT_FILE" "$BACKUP_FILE"
fi

# Show original YAML
echo -e "\n${GREEN}📄 Original YAML:${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
cat "$INPUT_FILE"

# Start with the original content
cp "$INPUT_FILE" "$OUTPUT_FILE"

echo -e "\n${BLUE}🔧 Performing schema transformations...${NC}"

# 1. Image-related field migrations
echo "   → Moving image-related fields to spec.deployment.image.*"
if yq eval '.spec.deployment | has("image_name")' "$OUTPUT_FILE" | grep -q true; then
    yq eval '.spec.deployment.image.name = .spec.deployment.image_name | del(.spec.deployment.image_name)' -i "$OUTPUT_FILE"
fi

if yq eval '.spec.deployment | has("image_version")' "$OUTPUT_FILE" | grep -q true; then
    yq eval '.spec.deployment.image.version = .spec.deployment.image_version | del(.spec.deployment.image_version)' -i "$OUTPUT_FILE"
fi

if yq eval '.spec.deployment | has("image_digest")' "$OUTPUT_FILE" | grep -q true; then
    yq eval '.spec.deployment.image.digest = .spec.deployment.image_digest | del(.spec.deployment.image_digest)' -i "$OUTPUT_FILE"
fi

if yq eval '.spec.deployment | has("image_pull_policy")' "$OUTPUT_FILE" | grep -q true; then
    yq eval '.spec.deployment.image.pull_policy = .spec.deployment.image_pull_policy | del(.spec.deployment.image_pull_policy)' -i "$OUTPUT_FILE"
fi

if yq eval '.spec.deployment | has("image_pull_secrets")' "$OUTPUT_FILE" | grep -q true; then
    yq eval '.spec.deployment.image.pull_secrets = .spec.deployment.image_pull_secrets | del(.spec.deployment.image_pull_secrets)' -i "$OUTPUT_FILE"
fi

# 2. Pod-related field migrations
echo "   → Moving pod-related fields to spec.deployment.pod.*"
POD_FIELDS=("affinity" "tolerations" "resources" "node_selector" "security_context" "custom_secrets" "topology_spread_constraints" "dns" "host_aliases" "custom_envs")

for field in "${POD_FIELDS[@]}"; do
    if yq eval ".spec.deployment | has(\"$field\")" "$OUTPUT_FILE" | grep -q true; then
        yq eval ".spec.deployment.pod.$field = .spec.deployment.$field | del(.spec.deployment.$field)" -i "$OUTPUT_FILE"
    fi
done

# Handle pod_annotations -> pod.annotations
if yq eval '.spec.deployment | has("pod_annotations")' "$OUTPUT_FILE" | grep -q true; then
    yq eval '.spec.deployment.pod.annotations = .spec.deployment.pod_annotations | del(.spec.deployment.pod_annotations)' -i "$OUTPUT_FILE"
fi

# Handle pod_labels -> pod.labels
if yq eval '.spec.deployment | has("pod_labels")' "$OUTPUT_FILE" | grep -q true; then
    yq eval '.spec.deployment.pod.labels = .spec.deployment.pod_labels | del(.spec.deployment.pod_labels)' -i "$OUTPUT_FILE"
fi

# 3. Service-related field migrations
echo "   → Moving service-related fields to spec.deployment.service.*"
if yq eval '.spec.deployment | has("service_type")' "$OUTPUT_FILE" | grep -q true; then
    yq eval '.spec.deployment.service.type = .spec.deployment.service_type | del(.spec.deployment.service_type)' -i "$OUTPUT_FILE"
fi

if yq eval '.spec.deployment | has("service_annotations")' "$OUTPUT_FILE" | grep -q true; then
    yq eval '.spec.deployment.service.annotations = .spec.deployment.service_annotations | del(.spec.deployment.service_annotations)' -i "$OUTPUT_FILE"
fi

if yq eval '.spec.deployment | has("additional_service_yaml")' "$OUTPUT_FILE" | grep -q true; then
    yq eval '.spec.deployment.service.additional_yaml = .spec.deployment.additional_service_yaml | del(.spec.deployment.additional_service_yaml)' -i "$OUTPUT_FILE"
fi

# 4. Workload-related field migrations
echo "   → Moving workload-related fields to spec.deployment.workload.*"
if yq eval '.spec.deployment | has("replicas")' "$OUTPUT_FILE" | grep -q true; then
    yq eval '.spec.deployment.workload.replicas = .spec.deployment.replicas | del(.spec.deployment.replicas)' -i "$OUTPUT_FILE"
fi

if yq eval '.spec.deployment | has("hpa")' "$OUTPUT_FILE" | grep -q true; then
    yq eval '.spec.deployment.workload.hpa = .spec.deployment.hpa | del(.spec.deployment.hpa)' -i "$OUTPUT_FILE"
fi

# 5. ConfigMap-related field migrations
echo "   → Moving configmap-related fields to spec.deployment.configmap.*"
if yq eval '.spec.deployment | has("configmap_annotations")' "$OUTPUT_FILE" | grep -q true; then
    yq eval '.spec.deployment.configmap.annotations = .spec.deployment.configmap_annotations | del(.spec.deployment.configmap_annotations)' -i "$OUTPUT_FILE"
fi

# 6. Logger migration from deployment to server.observability
echo "   → Moving logger from spec.deployment.logger to spec.server.observability.logger"
if yq eval '.spec.deployment | has("logger")' "$OUTPUT_FILE" | grep -q true; then
    yq eval '.spec.server.observability.logger = .spec.deployment.logger | del(.spec.deployment.logger)' -i "$OUTPUT_FILE"
fi

# 7. Profiler migration from server to server.observability
echo "   → Moving profiler from spec.server.profiler to spec.server.observability.profiler"
if yq eval '.spec.server | has("profiler")' "$OUTPUT_FILE" | grep -q true; then
    yq eval '.spec.server.observability.profiler = .spec.server.profiler | del(.spec.server.profiler)' -i "$OUTPUT_FILE"
fi

echo -e "\n${GREEN}✅ Migration completed successfully!${NC}"

# Show migrated YAML
echo -e "\n${GREEN}📄 Migrated YAML:${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
cat "$OUTPUT_FILE"

# Show diff if requested
if [[ "$SHOW_DIFF" == "true" ]]; then
    echo -e "\n${YELLOW}📊 Differences (old vs new):${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    if command -v diff &> /dev/null; then
        diff -u "$INPUT_FILE" "$OUTPUT_FILE" || true
    else
        echo "diff command not available, skipping diff display"
    fi
fi

echo -e "\n${GREEN}🎉 Migration Summary:${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  📂 Input file:     $INPUT_FILE"
echo "  📂 Output file:    $OUTPUT_FILE"
if [[ "$BACKUP_ORIGINAL" == true ]]; then
    echo "  📂 Backup file:    ${INPUT_FILE}.bak"
fi
echo ""
echo -e "${GREEN}✅ Your Kiali CR has been successfully migrated to the new schema!${NC}"