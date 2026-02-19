#!/bin/bash

# Script to start Docker containers using specified config file
# Usage: ./start-otel.sh [config.yaml|config-dcgm-nim.yaml|config-dcgm.yaml]
# Default: config.yaml 

# Get config file from command line argument or use default
CONFIG_FILE=${1:-config.yaml}

# Validate config file argument
case "$CONFIG_FILE" in
    config.yaml|config-dcgm-nim.yaml|config-dcgm.yaml)
        echo "Using configuration: $CONFIG_FILE"
        ;;
    *)
        echo "❌ Error: Invalid configuration file: $CONFIG_FILE"
        echo "Valid options: config.yaml, config-dcgm-nim.yaml, config-dcgm.yaml"
        exit 1
        ;;
esac

# Function to start a container
start_container() {
    local container_name=otel-collector
    local config_file=$1
    
    # Check if container exists and is running
    if docker ps -q -f name="^${container_name}$" | grep -q .; then
        echo "✅ Container ${container_name} is already running"
        echo ""
        return
    fi
    
    # Check if container exists but is stopped
    if docker ps -aq -f name="^${container_name}$" | grep -q .; then
        echo "▶️  Starting existing container: ${container_name}"
        docker start "${container_name}"
        echo ""
        return
    fi
    
    # Container doesn't exist, create and start it based on config type
    echo "🔄 Starting dynatrace-otel-collector container with ${config_file}..."

    # We use docker create + docker cp + docker start instead of a bind mount (-v).
    # Bind mounts pass the path to the HOST Docker daemon, but $(pwd) resolves to
    # the container-internal path (e.g. /workspaces/...), which doesn't exist on the
    # host. Docker then silently creates a directory there and mounts it, causing:
    #   "read /etc/otelcol/config.yaml: is a directory"
    # docker cp copies from the current filesystem (where $(pwd) is valid), so it
    # works correctly under both DooD (Codespaces) and local (make start) scenarios.

    case "$config_file" in
        config.yaml)
            echo "Starting with config.yaml..."
            echo "DT_BASE_URL = $DT_BASE_URL"
            docker create \
            --name ${container_name} \
            -e DT_BASE_URL=$DT_BASE_URL \
            -e DT_API_TOKEN=$DT_API_TOKEN \
            -p 4317:4317 \
            -p 4318:4318 \
            dynatrace/dynatrace-otel-collector:latest
            ;;
        config-dcgm.yaml)
            echo "Starting with config-dcgm.yaml..."
            echo "DT_BASE_URL = $DT_BASE_URL"
            echo "DCGM_HOST = $DCGM_HOST"
            echo "DCGM_PORT = $DCGM_PORT"
            docker create \
            --name ${container_name} \
            -e DT_BASE_URL=$DT_BASE_URL \
            -e DT_API_TOKEN=$DT_API_TOKEN \
            -p 4317:4317 \
            -p 4318:4318 \
            -e DCGM_TARGET=dcgm-host:$DCGM_PORT   \
            --add-host "dcgm-host:$DCGM_HOST"   \
            dynatrace/dynatrace-otel-collector:latest
            ;;
        config-dcgm-nim.yaml)
            echo "Starting with config-dcgm-nim.yaml..."
            echo "DT_BASE_URL = $DT_BASE_URL"
            echo "DCGM_PORT = $DCGM_PORT"
            echo "NIM_HOST = $NIM_HOST"
            docker create \
            --name ${container_name} \
            -e DT_BASE_URL=$DT_BASE_URL \
            -e DT_API_TOKEN=$DT_API_TOKEN \
            -p 4317:4317 \
            -p 4318:4318 \
            -e DCGM_TARGET=dcgm-host:$DCGM_PORT   \
            -e NIM1_TARGET=nim-host:8001   \
            -e NIM2_TARGET=nim-host:8002   \
            -e NIM3_TARGET=nim-host:8003   \
            --add-host "dcgm-host:$DCGM_HOST"   \
            --add-host "nim-host:$NIM_HOST" \
            dynatrace/dynatrace-otel-collector:latest
            ;;
    esac

    echo "📋 Copying config into container..."
    # docker cp cannot create intermediate directories, so we stage the file in a
    # temp dir matching the target structure, then copy the directory into /etc/.
    # We explicitly set permissions to 755/644 so that the non-root user inside the
    # dynatrace-otel-collector container can always traverse the directory and read
    # the config file. Without this, mktemp creates the parent dir as 700 and the
    # umask/environment (e.g. Codespaces DooD) can leave the copied path with
    # overly restrictive permissions → "permission denied" at container startup.
    local tmp_dir
    tmp_dir=$(mktemp -d)
    mkdir -p "${tmp_dir}/otelcol"
    cp "$(pwd)/${config_file}" "${tmp_dir}/otelcol/config.yaml"
    chmod 755 "${tmp_dir}/otelcol"
    chmod 644 "${tmp_dir}/otelcol/config.yaml"
    docker cp "${tmp_dir}/otelcol" ${container_name}:/etc/
    rm -rf "${tmp_dir}"
    echo "▶️  Starting container..."
    docker start ${container_name}
    
    echo ""
}
    
# Main logic
echo "🔄 Starting otel container..."
start_container "$CONFIG_FILE"
echo "✅ otel containers processed"
echo ""
echo "✅ Showing list of containers"
echo ""
docker ps