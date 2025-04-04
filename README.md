# PowerAPI setup

This is docs for helping to setup PowerAPI. It provides steps and links to follow for successful setup.

There are several ways of getting everything up and running, either through the [run all script](./run-all.sh), starting [power-api](./configs/docker/powerapi/) through docker compose and then [cAdvisor](./configs/docker/cadvisor/) manually or simply starting all of the containers one by one.

## Using the run-all.sh script with pre-configured values

You can use the run-all.sh script to start all of the containers. The script starts the containers defined in [docker-compose.yaml](./configs//docker/docker-compose.yaml) file as well as [cAdvisor](./configs/docker/cadvisor/docker-compose-cometlake.yaml) and then starts the hwpc, smartwatts containers.

To use the script you need to pass in a run flag like so:

```sh
./run-all.sh zen4
```

This tells the script to use the [start-sw-zen4.sh](./configs/smartwatts/start-sw-zen4.sh) and [start-hwpc-zen4.sh](./configs/hwpc/start-hwpc-zen4.sh) scripts. Passing cometlake results in the cometlake files being used.

# Configuration and starting things manually

## Pulling Docker Images

Start by pulling down Docker images

- `docker pull ghcr.io/powerapi-ng/hwpc-sensor`
- `docker pull mongo`
- `docker pull ghcr.io/powerapi-ng/smartwatts-formula`
- `docker pull influxdb:2`

## Iniitalizing influxdb

InfluxDB requires first time setup.

As we are using docker we will initialize using the initial setup options provided [here](https://docs.influxdata.com/influxdb/v2/install/?t=Docker#install-and-setup-influxdb-in-a-container).

Below are some suggested values for the initial setup. Feel free to change them as you feel.

```sh
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
```

- Navigate to `localhost:8086`, or the port you specified during initialization.
- Find the `API Tokens` page under the left sidebar.
- Click the `+ GENERATE API TOKEN` on the right side.
- Select all access token and name it appropriately
- Copy the token and save it, you won't be able to see it again.

While we are here we should set the retention policy of our bucket.

- Selected Load Data on the left panel
- Go to settings on the bucket
- Set the `OLDER THAN` field to `forever`

## Configuring the HWPC sensor

There are two configurations available in the [./configs/hwpc](/configs/hwpc) folder. One for the Zen architecture and one for Intel. Select the one that matches your CPU.

### Configuring the cgroup

This section assumes you are using systemd as the cgroup driver.

To make the cgroup persistent between reboots we need to create a cgroup specification file.

Begin by opening up a file under the system folder. The file name should match the name of the group-parent flag we will use when we create the container later: `--group-parent=power.slice`.

```sh
sudo nano /etc/systemd/system/power.slice
```

The configuration file should look like this.

```sh
[Unit]
Description=Power cgroup slice
Documentation=man:systemd.special(7)
DefaultDependencies=no
Before=slices.target

[Slice]
CPUAccounting=true
MemoryAccounting=true

[Install]
WantedBy=multi-user.target
```

Restart the systemd configuration.

```sh
sudo systemctl daemon-reload
```

Enable the slice.

```sh
sudo systemctl enable power.slice
```

Start the slice.

```sh
sudo systemctl start power.slice
```

Verify that the slice is active.

```sh
sudo systemctl status power.slice
```

The cgroup should now persist between system reboots and we can use it to gather data.

## Starting MongoDB

**NOTE MongoDB is included in the docker-compose files.**

We need to setup a destination for the data to be recorded in. We use mongodb.

```sh
docker run -d --name mongo_destination -p 27017:27017 mongo
```

## Starting the HWPC sensor

Replace the `<config-file-path>` with the path to your config file.

**NOTE** The $(pwd) command will make docker look at the current directory you are in, make sure that the config file is in the current directory, or add your own path.

```sh
docker run --rm  \
--net=host \
--privileged \
--pid=host \
-v /sys:/sys \
-v /var/lib/docker/containers:/var/lib/docker/containers:ro \
-v /tmp/powerapi-sensor-reporting:/reporting \
-v $(pwd):/srv \
-v $(pwd)/<name of config file>.json:/config_file.json \
powerapi/hwpc-sensor --config-file config_file.json
```

## Configuring SmartWatts

The SmartWatts formula requires some configuration that is dependant on the hardware that it's running on. To find the `cpu-base-freq` field run `lscpu` and grab the value from the `CPU MHz` field.

For the other fields or if `lscpu` does not display the field correctly, Google your CPU and find the specifications from there.

The configurations found under [./configs/smartwatts](./configs/smartwatts/) is configured for the devices on which our study was conducted.

Once the hardware specific fields are filled in run this command while replacing the `<name of config file>`.

```sh
docker run -t \
--net=host \
-v $(pwd)/<name of config file>.json:/config_file.json \
powerapi/smartwatts-formula --config-file /config_file.json
```

## Docker network set up

Before setting up Grafana, we need to establish a docker network so the containers can communicate with each other.
Stop your InfluxDB container using `docker stop` and instead
Navigate to the `/docker` directory and run `docker compose up -d`
This will run a new InfluxDB container as well as a Grafana instance on the same docker network.

## Grafana setup

After the launch, Grafana will be available at <http://localhost:3000>.
Username and Password is `admin`

### Connect Grafana to InfluxDB

Connections -> Data sources -> Add data source
Select "InfluxDB".

Enter:

- A data source Name, i.e `influxdb`,
- A Query Language, select `FLUX`
- An URL (<http://influxdb:8086>) **NOTE**: Grafana can now reach InfluxDB using the service name as the hostname within the docker network.
- Organization, `graphql-experiment`
- Token, your influxDB token.
- Default Bucket, `graphql-power`

Then click on the "Save & test" button.

### Visualize the data

In Grafana:
Dashboard -> Create dashboard -> Add visualisation -> your-influxDB-datasource

Example: Query the power estimations from the last 10 minutes from the InfluxDB instance:

```sql
from(bucket: "graphql-power")
  |> range(start: -10m) 
  |> filter(fn: (r) => r["formula"] == "RAPL_ENERGY_PKG")
```

**NOTE**: If you ran new containers using docker compose, you may need to restart the sensor and formula for the data to be measured again correctly.

## cAdvisor + prometheus setup

The docker compose file in the `cadvisor` folder contains everything needed to run cAdvisor on your machine in a docker container. cAdvisor monitors the whole machine (all running containers) so you can through the web UI easily select the container on `http://localhost:8080/docker` you want to inspect in real-time.

**NOTE**: cAdvisor's web ui is accessible on `http://localhost:8080/`
**NOTE**: Prometheus's web ui is accessible on `http://localhost:9090/`

Make sure that the cAdvisor service is visible in the target health and service descovery menus in Prometheus.
You can test querying cAdvisor metrics:

All cpu usage from the last 5 mins (all containers):
`rate(container_cpu_usage_seconds_total[5m])`

All cpu usage from the last 5 mins for a specific container:
`rate(container_cpu_usage_seconds_total{container="my-container-name"}[1m])` (by container name)
`rate(container_cpu_usage_seconds_total{id="123456789abc"}[1m])` (by container id)

Get the CPU usage as percentage over the last 10 minutes:
`100 * rate(container_cpu_usage_seconds_total{container_label_com_docker_compose_service="smartwatts"}[10m])`

## Update 2025-03-13 Daniel's config

Start everything together
`cd ~/src/thesis-docs/configs/docker/powerapi`
`docker compose -f docker-compose-cometlake.yaml -d`

Restart
`docker compose -f docker-compose-cometlake.yaml restart`

Have needed to do this multiple times for some reason
`sudo mkdir -p /sys/fs/cgroup/power.slice`
