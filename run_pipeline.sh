
set -e

# --- Colors for Output ---
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # No Color


# --- Argument and Prerequisite Checks ---
if [ -z "$1" ]; then
  echo -e "${RED}Error: No pipeline directory provided.${NC}"
  echo "Usage: $0 /path/to/your/pipeline/directory"
  exit 1
fi

PIPELINE_DIR="$1"

if [ ! -d "$PIPELINE_DIR" ]; then
  echo -e "${RED}Error: Directory '$PIPELINE_DIR' not found.${NC}"
  exit 1
fi

if ! command -v kubectl &> /dev/null; then
    echo -e "${YELLOW}WARNING: kubectl could not be found. Please install it and ensure it's in your PATH.${NC}"
    exit 1
fi
if ! command -v tkn &> /dev/null; then
    echo -e "${YELLOW}WARNING: The Tekton CLI (tkn) could not be found. It's required for streaming logs easily.${NC}"
    echo "Please install it from here: https://tekton.dev/docs/cli/install/"
    exit 1
fi


# --- Configuration ---
NAMESPACE="tekton-pipelines"


# --- Script Body ---
echo -e "${BLUE}STEP 1: Checking for existing Tekton installation...${NC}"
if kubectl get namespace tekton-pipelines &> /dev/null; then
    echo "Tekton appears to be already installed. Skipping installation."
else
    echo -e "${BLUE}STEP 1: Installing Tekton Pipelines...${NC}"
    kubectl apply --filename https://storage.googleapis.com/tekton-releases/pipeline/latest/release.yaml

    echo "Waiting for Tekton controller to become available..."
    kubectl wait \
      --for=condition=available \
      --timeout=300s \
      deployment/tekton-pipelines-controller \
      -n tekton-pipelines
    echo -e "${GREEN}Tekton Pipelines installed successfully.${NC}"
fi


echo -e "\n${BLUE}STEP 2: Applying prerequisites (RBAC, Tasks, Pipeline)...${NC}"
# Find the PipelineRun file to exclude it from the first apply
PIPELINERUN_FILE=$(awk '/kind: PipelineRun/{print FILENAME; exit}' "$PIPELINE_DIR"/*.yaml 2>/dev/null)

if [ -z "$PIPELINERUN_FILE" ]; then
  echo -e "${RED}Fatal: Could not find a file with 'kind: PipelineRun' in '$PIPELINE_DIR'.${NC}"
  exit 1
fi

# Apply everything EXCEPT the PipelineRun file
find "$PIPELINE_DIR" -maxdepth 1 -name "*.yaml" -not -name "$(basename "$PIPELINERUN_FILE")" -print0 | xargs -0 -I {} kubectl apply -f {} -n "$NAMESPACE"
find "$PIPELINE_DIR" -maxdepth 1 -name "*.yml" -not -name "$(basename "$PIPELINERUN_FILE")" -print0 | xargs -0 -I {} kubectl apply -f {} -n "$NAMESPACE"


echo -e "\n${BLUE}STEP 3: Applying the PipelineRun to start execution...${NC}"
# Wait a moment for the RBAC rules to propagate before running the pipeline
echo "(Waiting 5 seconds for permissions to apply...)"
sleep 5

# Delete the pipelinerun if it exists, to ensure a fresh run
PIPELINERUN_NAME=$(awk '/kind: PipelineRun/{f=1} f && /name:/{print $2; exit}' "$PIPELINERUN_FILE" 2>/dev/null)
echo "Deleting previous run of '$PIPELINERUN_NAME' to ensure a fresh start..."
kubectl delete pipelinerun "$PIPELINERUN_NAME" -n "$NAMESPACE" --ignore-not-found=true

# Now, apply only the PipelineRun file
kubectl apply -f "$PIPELINERUN_FILE" -n "$NAMESPACE"
echo "Found and started PipelineRun: ${GREEN}$PIPELINERUN_NAME${NC}"


echo -e "\n${BLUE}STEP 4: Streaming logs... (Press Ctrl+C to exit)${NC}"
# Use tkn to follow the logs of the PipelineRun.
tkn pipelinerun logs -f "$PIPELINERUN_NAME" -n "$NAMESPACE"

# After the logs are done streaming, get the final status
echo -e "\n${BLUE}STEP 5: Fetching final status of the PipelineRun...${NC}"
tkn pipelinerun describe "$PIPELINERUN_NAME" -n "$NAMESPACE"