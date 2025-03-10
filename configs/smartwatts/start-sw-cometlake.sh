docker run -t \
--name=smartwatts \
--net=host \
-v $(pwd)/smartwatts-config-cometlake.json:/config_file.json \
powerapi/smartwatts-formula --config-file /config_file.json