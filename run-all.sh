if [ -z "$1" ]; then
  echo "Usage: $0 <run_flag>"
  echo "Example: $0 zen4"
  exit 1
fi

RUN_FLAG=$1

#!/bin/bash
echo "STEP 1: Entering Docker config directory"
cd ./configs/docker
echo "STEP 2: Starting Docker containers"
docker-compose up -d

# Get the list of service names from docker-compose.yml
services=$(docker-compose config --services)

# Function to check if all specified containers are running
all_containers_running() {
  for service in $services; do
    container_id=$(docker-compose ps -q "$service")
    if [ -z "$container_id" ]; then
      return 1
    fi
    status=$(docker inspect -f '{{.State.Running}}' "$container_id")
    if [ "$status" != "true" ]; then
      return 1
    fi
  done
  return 0
}

# Wait until all specified containers are running
while ! all_containers_running; do
  echo "Waiting for containers to be ready..."
  sleep 5
done

echo "STEP 3: Returning to original directory"
cd ../../

echo "STEP 4: Starting HWPC script for $RUN_FLAG"
source ./configs/hwpc/start-hwpc-$RUN_FLAG.sh

echo "STEP 5: Starting SmartWatts script for $RUN_FLAG"
source ./configs/smartwatts/start-sw-$RUN_FLAG.sh

echo "FINAL STEP: Script completed"