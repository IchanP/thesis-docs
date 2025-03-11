docker run -d \
-t \
--net=host \
-v $(pwd)/configs/smartwatts/smartwatts-config-zen4.json:/config_file.json \
powerapi/smartwatts-formula --config-file /config_file.json