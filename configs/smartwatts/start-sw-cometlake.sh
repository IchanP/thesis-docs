docker run -d \
-t \
--name=smartwatts \
--net=host \
-v $(pwd)/configs/smartwatts/smartwatts-config-cometlake.json:/config_file.json \
powerapi/smartwatts-formula --config-file /config_file.json