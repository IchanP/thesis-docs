docker run -t \
--net=host \
-v $(pwd)/smartwatts-config-zen4.json:/config_file.json \
powerapi/smartwatts-formula --config-file /config_file.json