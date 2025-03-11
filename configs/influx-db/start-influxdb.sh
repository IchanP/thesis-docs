docker run \
 --name influxdb2 \
 --publish 8086:8086 \
 --mount type=volume,source=influxdb2-data,target=/var/lib/influxdb2 \
 --mount type=volume,source=influxdb2-config,target=/etc/influxdb2 \
 --env DOCKER_INFLUXDB_INIT_MODE=setup \
 --env DOCKER_INFLUXDB_INIT_USERNAME=admin \
 --env DOCKER_INFLUXDB_INIT_PASSWORD=password \
 --env DOCKER_INFLUXDB_INIT_ORG=graphql-experiment \
 --env DOCKER_INFLUXDB_INIT_BUCKET=graphql-power \
 --detach \
 influxdb:2