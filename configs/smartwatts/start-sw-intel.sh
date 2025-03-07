docker run -t \
--net=host \
-v $(pwd)/smartwatts-config-intel.json:/config_file.json \
powerapi/smartwatts-formula --config-file /config_file.json