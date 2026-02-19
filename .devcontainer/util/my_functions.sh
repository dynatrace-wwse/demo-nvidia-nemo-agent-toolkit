#!/bin/bash
# ======================================================================
#          ------- Custom Functions -------                            #
#  Space for adding custom functions so each repo can customize as.    # 
#  needed.                                                             #
# ======================================================================

APP_DIR="$REPO_PATH/app"


customFunction(){
  printInfoSection "This is a custom function that calculates 1 + 1"

  printInfo "1 + 1 = $(( 1 + 1 ))"

}

startApp(){
  printInfoSection "Starting application"
  printInfo "Launching Streamlit application..."

  if [ -x "$REPO_PATH/.venv/bin/python3" ]; then
    "$REPO_PATH/.venv/bin/python3" -m streamlit run "$APP_DIR/app.py"
  elif command -v python3 >/dev/null 2>&1; then
    python3 -m streamlit run "$APP_DIR/app.py"
  elif command -v streamlit >/dev/null 2>&1; then
    streamlit run "$APP_DIR/app.py"
  else
    printError "Could not find Python/Streamlit runtime. Run setUpPythonEnv first."
    return 1
  fi
}

setUpPythonEnv(){

  printInfoSection "Setting up Python Environment"
  
  printInfo "Downloading & installing Python project manager Astral UV..."
  curl -LsSf https://astral.sh/uv/install.sh | sh

  if [ -f "$HOME/.local/bin/env" ]; then
    source "$HOME/.local/bin/env"
  fi
  
  printInfo "Creating and activating Python virtual environment..."
  # On container overlay filesystems (Codespaces/Docker), .venv/lib64 is a symlink.
  # 'uv venv --clear' calls rmdir() on it → EOVERFLOW (os error 75).
  # 'rm -rf' may also fail if the symlink blocks traversal, so unlink it explicitly first.
  if [ -d .venv ]; then
    find .venv -maxdepth 3 -type l -exec unlink {} \; 2>/dev/null || true
    rm -rf .venv 2>/dev/null || true
  fi
  uv venv --python 3.13 .venv
  source .venv/bin/activate

  printInfo "Installing Python dependencies..."
  # Increase UV HTTP timeout to handle slower connections
  export UV_HTTP_TIMEOUT=300
  # Suppress UV hardlink warning for cross-filesystem operations
  export UV_LINK_MODE=copy
  if ! uv pip install -r "$APP_DIR/requirements.txt"; then
    printError "Failed to install Python dependencies. "
    printError "Please check app/requirements.txt and try again."
    return 1
  fi

  printInfo "Updating Python configuration files..."
  python "$APP_DIR/update_config.py" build
}

startOtelCollector(){

  printInfoSection "Starting OpenTelemetry Collector"

  if [ -z "$OTEL_OTLP_ENDPOINT" ] || [ "$OTEL_OTLP_ENDPOINT" = "null" ]; then
    export OTEL_OTLP_ENDPOINT="http://localhost:4318"
  fi
  printInfo "Setting OTEL_OTLP_ENDPOINT=$OTEL_OTLP_ENDPOINT"
  echo "export OTEL_OTLP_ENDPOINT=\"$OTEL_OTLP_ENDPOINT\"" >> ~/.bashrc

  ##############################################################################
  # Start Otel Collector
  ##############################################################################
  printInfo "Starting up Otel Collector..."
  cd /workspaces/demo-nvidia-nemo-agent-toolkit/otel
  ./start-otel.sh
  cd /workspaces/demo-nvidia-nemo-agent-toolkit
}

verifyEnvironmentVars(){
  printInfoSection "Verifying Environment Variables"

  # Adjust to build, brev or local
  if [ -z "$APP_MODE" ] || [ "$APP_MODE" = "null" ]; then
    export APP_MODE=build
  fi

  # Validate APP_MODE is one of the allowed values
  if [ "$APP_MODE" != "local" ] && [ "$APP_MODE" != "brev" ] && [ "$APP_MODE" != "build" ]; then
    printError "APP_MODE must be 'local', 'brev', or 'build'."
    printError "Current value: $APP_MODE"
    return 1
  fi
  printInfo "APP_MODE is set to: $APP_MODE"

##############################################################################
# Setup Environment Variables
##############################################################################

# Adjust as required for using server to workshop environment variables.  
# Leave blank if not running a workshop
WORKSHOP_URL=
if [ "$WORKSHOP_URL" ] ; then
  printInfoSection "Getting workshop environment settings"

  # Verify that environment variables were retrieved successfully
  if [ -z "$WORKSHOP_PASSWORD" ] || [ "$WORKSHOP_PASSWORD" = "null" ]; then
    printError "WORKSHOP_PASSWORD is not set or is null."
    printError "Please check your WORKSHOP_PASSWORD and try again."
    return 1
  fi
  printInfo "WORKSHOP_PASSWORD detected."

  export DT_BASE_URL=$(curl -s -X POST $WORKSHOP_URL/dynatrace-url \
    -H "Content-Type: application/json" \
    -d "{\"password\": \"$WORKSHOP_PASSWORD\"}" | jq -r '.dynatrace_url')

  export DT_API_TOKEN=$(curl -s -X POST $WORKSHOP_URL/dynatrace-token \
    -H "Content-Type: application/json" \
    -d "{\"password\": \"$WORKSHOP_PASSWORD\"}" | jq -r '.dynatrace_api_token')

  export NVIDIA_API_KEY=$(curl -s -X POST $WORKSHOP_URL/nvidia-key \
    -H "Content-Type: application/json" \
    -d "{\"password\": \"$WORKSHOP_PASSWORD\"}" | jq -r '.nvidia_api_key')

  export TAVILY_API_KEY=$(curl -s -X POST $WORKSHOP_URL/tavily-key \
    -H "Content-Type: application/json" \
    -d "{\"password\": \"$WORKSHOP_PASSWORD\"}" | jq -r '.tavily_api_key')

  export OTEL_OTLP_ENDPOINT=$(curl -s -X POST $WORKSHOP_URL/otel-endpoint \
    -H "Content-Type: application/json" \
    -d "{\"password\": \"$WORKSHOP_PASSWORD\"}" | jq -r '.otel_otlp_endpoint')

  export NVIDIA_MODEL_ENDPOINT_8001=$(curl -s -X POST $WORKSHOP_URL/nvidia-model-endpoint-8001 \
    -H "Content-Type: application/json" \
    -d "{\"password\": \"$WORKSHOP_PASSWORD\"}" | jq -r '.nvidia_model_endpoint_8001')

  export NVIDIA_MODEL_ENDPOINT_8002=$(curl -s -X POST $WORKSHOP_URL/nvidia-model-endpoint-8002 \
    -H "Content-Type: application/json" \
    -d "{\"password\": \"$WORKSHOP_PASSWORD\"}" | jq -r '.nvidia_model_endpoint_8002')

  export NVIDIA_MODEL_ENDPOINT_8003=$(curl -s -X POST $WORKSHOP_URL/nvidia-model-endpoint-8003 \
    -H "Content-Type: application/json" \
    -d "{\"password\": \"$WORKSHOP_PASSWORD\"}" | jq -r '.nvidia_model_endpoint_8003')

  export NVIDIA_MODEL_ENDPOINT_8004=$(curl -s -X POST $WORKSHOP_URL/nvidia-model-endpoint-8004 \
    -H "Content-Type: application/json" \
    -d "{\"password\": \"$WORKSHOP_PASSWORD\"}" | jq -r '.nvidia_model_endpoint_8004')
fi

# get the NVIDIA model endpoints if in brev or local mode
if [ "$APP_MODE" = "brev" ] || [ "$APP_MODE" = "local" ]  ; then
  printInfoSection "Setting NVIDIA model endpoints for $APP_MODE mode"

  if [ -z "$NVIDIA_MODEL_ENDPOINT_8001" ] || [ "$NVIDIA_MODEL_ENDPOINT_8001" = "null" ]; then
    printError "Failed to retrieve NVIDIA_MODEL_ENDPOINT_8001."
    return 1
  fi
  printInfo "NVIDIA_MODEL_ENDPOINT_8001=$NVIDIA_MODEL_ENDPOINT_8001"
  printInfo "NVIDIA_MODEL_ENDPOINT_8002=$NVIDIA_MODEL_ENDPOINT_8002"
  printInfo "NVIDIA_MODEL_ENDPOINT_8003=$NVIDIA_MODEL_ENDPOINT_8003"
  printInfo "NVIDIA_MODEL_ENDPOINT_8004=$NVIDIA_MODEL_ENDPOINT_8004"
  echo "export NVIDIA_MODEL_ENDPOINT_8001=\"$NVIDIA_MODEL_ENDPOINT_8001\"" >> ~/.bashrc
  echo "export NVIDIA_MODEL_ENDPOINT_8002=\"$NVIDIA_MODEL_ENDPOINT_8002\"" >> ~/.bashrc
  echo "export NVIDIA_MODEL_ENDPOINT_8003=\"$NVIDIA_MODEL_ENDPOINT_8003\"" >> ~/.bashrc
  echo "export NVIDIA_MODEL_ENDPOINT_8004=\"$NVIDIA_MODEL_ENDPOINT_8004\"" >> ~/.bashrc
fi

##TODO: why adding the vars to .bashrc? for new terminals? we use zsh in the framework.
# get using the NVIDIA Build APIs, then get the API key
if [ "$APP_MODE" = "build" ] ; then
  printInfoSection "Setting NVIDIA API key"
  if [ -z "$NVIDIA_API_KEY" ] || [ "$NVIDIA_API_KEY" = "null" ]; then
    printError "Failed to retrieve NVIDIA_API_KEY."
    return 1
  fi
  echo "export NVIDIA_API_KEY=\"$NVIDIA_API_KEY\"" >> ~/.bashrc
fi

printInfoSection "Setting Dynatrace configuration"
printInfo "Setting Dynatrace DT_BASE_URL=$DT_BASE_URL"
if [ -z "$DT_BASE_URL" ] || [ "$DT_BASE_URL" = "null" ]; then
  printError "Failed to retrieve DT_BASE_URL."
  return 1
fi
if [ -z "$DT_API_TOKEN" ] || [ "$DT_API_TOKEN" = "null" ]; then
  printError "Failed to retrieve DT_API_TOKEN."
  return 1
fi
echo "export DT_BASE_URL=\"$DT_BASE_URL\"" >> ~/.bashrc
echo "export DT_API_TOKEN=\"$DT_API_TOKEN\"" >> ~/.bashrc

printInfoSection "Setting Tavily API key"
if [ -z "$TAVILY_API_KEY" ] || [ "$TAVILY_API_KEY" = "null" ]; then
  printError "Failed to retrieve TAVILY_API_KEY."
  return 1
fi
echo "export TAVILY_API_KEY=\"$TAVILY_API_KEY\"" >> ~/.bashrc



}