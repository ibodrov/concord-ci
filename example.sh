#!/bin/bash

curl -ik \
-H 'Authorization: auBy4eDWrKWsyhiDp3AQiw' \
-F concord.yml=@concord.yml \
-F settings.xml=@settings.xml \
http://localhost:8001/api/v1/process
