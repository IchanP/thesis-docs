if [ -z "$1" ]; then
  echo "Usage: $0 <run_flag>"
  echo "Example: $0 zen4"
  exit 1
fi

RUN_FLAG=$1

#!/bin/bash
echo "STEP 1: Entering Docker powerapi directory"
cd ./configs/docker/powerapi
echo "STEP 2: Starting Docker containers"
docker-compose -f docker-compose-$RUN_FLAG.yaml up -d

# Get the list of service names from docker-compose.yml
services=$(docker-compose -f docker-compose-$RUN_FLAG.yaml config --services)


echo "STEP 3: Returning to original directory"
cd ../../../

echo "FINAL STEP: Script completed"