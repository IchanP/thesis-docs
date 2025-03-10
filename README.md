# PowerAPI setup

This is docs for helping to setup PowerAPI. It provides steps and links to follow for successful setup.

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

**NOTE** If your system uses systemd as the cgroup drive the .slice at the end is required.

- Begin by finding the cgroup location on your linx installation. Normally it's in `/sys/fs/cgroup`.
- Create a new directory in the cgroup location: `sudo mkdir power.slice`. When we start the container(s) later we will add `--group-parent=power.slice` as a run flag.

Example run command:

```sh
docker run --cgroup-parent=power.slice -d --name my_container your_image
```

To verify that the docker container was correctly added to the cgroup you can run the following commands:

```sh
# Grab the PID
CONTAINER_PID=$(docker inspect -f '{{.State.Pid}}' my-container)
# Find the cgroup path
cat /proc/$CONTAINER_ID/cgroup
# Cat the current processes in the path
cat /sys/fs/cgroup/power.slice/docker-<the docker id>.scope/cgroup.procs
# You can then compare the PID displayed with the container pid
echo $CONTAINER_ID
```

### Run command for HWPC Sensor

First we need to start MongoDB where all the data will be recorded:

## Starting MongoDB

We need to setup a destination for the data to be recorded in. We use mongodb.

```sh
docker run -d --name mongo_destination -p 27017:27017 mongo
```

Then we can start the sensor.

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

After the launch, Grafana will be available at http://localhost:3000.
Username and Password is `admin`

### Connect Grafana to InfluxDB

Connections -> Data sources -> Add data source
Select "InfluxDB". 

Enter:

- A data source Name, i.e `influxdb`,
- A Query Language, select `FLUX`
- An URL (http://influxdb:8086) **NOTE**: Grafana can now reach InfluxDB using the service name as the hostname within the docker network.
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