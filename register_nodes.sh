#!/bin/bash

# Configuration
BASE_PORT=33334
CONTAINER_APP_PORT=8080
IMAGE_NAME="power-logger:latest"
NODE_COUNT=10
CONFIG_FILE="config.yaml"

# Detect OS for sed compatibility
if [[ "$OSTYPE" == "darwin"* ]]; then
  SED_INPLACE="sed -i ''"
else
  SED_INPLACE="sed -i"
fi

# Check if config file exists
if [ ! -f "$CONFIG_FILE" ]; then
  echo "Error: Configuration file $CONFIG_FILE not found!"
  exit 1
fi

# Create nodes directory
mkdir -p nodes

# Function to handle node setup
setup_node() {
  local node_num=$1
  local port=$((BASE_PORT + node_num))
  local node_dir="nodes/node${node_num}"
  local container_name="power-node-${node_num}"
  local node_name="PowerNode${node_num}"

  echo -e "\n🚀 Starting interactive container for ${node_name} on port ${port}"

  # Setup directory structure
  mkdir -p "${node_dir}"/{data,logs}
  cp "$CONFIG_FILE" "${node_dir}/config.yaml"

  # Verify the config file was copied
  if [ ! -f "${node_dir}/config.yaml" ]; then
    echo "Error: Failed to create config file in ${node_dir}"
    return 1
  fi

  # Run the container interactively
  if ! docker run -it --rm \
    --name "${container_name}" \
    -e IC_URL="https://ic0.app" \
    -e NODE_ID="${node_num}" \
    -e NODE_NAME="${node_name}" \
    -e RUST_LOG="info" \
    -v "$(pwd)/${node_dir}/config.yaml:/app/config.yaml:ro" \
    -v "$(pwd)/${node_dir}/data:/app/data" \
    -v "$(pwd)/${node_dir}/logs:/app/logs" \
    -v "$(pwd)/${node_dir}/node_private_key.bin:/app/node_private_key.bin:ro" \
    -v "$(pwd)/${node_dir}/node_principal.txt:/app/node_principal.txt:ro" \
    -v "$(pwd)/${node_dir}/devices.yaml:/app/devices.yaml:ro" \
    -p "${port}:${CONTAINER_APP_PORT}" \
    "${IMAGE_NAME}"; then
    echo "Error: Failed to start container ${container_name}"
    return 1
  fi

  # Copy generated files from container to host
  copy_generated_files "${container_name}" "${node_dir}"

  echo "✅ Finished registering ${node_name}. Press Enter to continue..."
  read -r
}

# Function to copy generated files from container
copy_generated_files() {
  local container=$1
  local node_dir=$2

  declare -a files=(
    "node_private_key.bin"
    "node_principal.txt"
    "devices.yaml"
  )

  for file in "${files[@]}"; do
    if docker cp "${container}:/app/${file}" "${node_dir}/${file}" 2>/dev/null; then
      echo "  - Copied ${file} to ${node_dir}"
    else
      echo "  - Warning: Failed to copy ${file} from container (container may have exited)"
    fi
  done
}

# Main execution loop
for i in $(seq 1 "${NODE_COUNT}"); do
  if ! setup_node "$i"; then
    echo "Error setting up node $i. Continuing to next node..."
    # Print commands to manually copy files if needed
    echo "To manually copy files, run:"
    docker cp power-node-$i:/app/node_private_key.bin nodes/node$i/node_private_key.bin
    docker cp power-node-$i:/app/node_principal.txt nodes/node$i/node_principal.txt
    docker cp power-node-$i:/app/devices.yaml nodes/node$i/devices.yaml
    continue
  fi
done

echo -e "\nAll nodes have been processed. Exiting."