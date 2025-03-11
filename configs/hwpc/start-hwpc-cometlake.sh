docker run -d \
--rm  \
--cap-add=SYS_ADMIN \
--net=host \
--privileged \
--pid=host \
-v /sys:/sys \
-v /var/lib/docker/containers:/var/lib/docker/containers:ro \
-v /tmp/powerapi-sensor-reporting:/reporting \
-v $(pwd):/srv \
-v $(pwd)/configs/hwpc/hwpc-config-cometlake.json:/config_file.json \
powerapi/hwpc-sensor --config-file config_file.json