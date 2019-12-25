#!/bin/bash

# create a .m2 directory
mkdir -p /tmp/concord/.m2/repository
chmod a+rw /tmp/concord/.m2/repository

BASE_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

if [[ -z ${VERSION} ]]; then
    VERSION="latest"
fi
echo "VERSION: ${VERSION}"

if [[ -z ${DOCKER_PREFIX} ]]; then
    DOCKER_PREFIX="walmartlabs"
fi
echo "DOCKER_PREFIX: ${DOCKER_PREFIX}"

if [[ -z ${CONCORD_CFG_FILE} ]]; then
    CONCORD_CFG_FILE=${BASE_DIR}/server.conf
fi
echo "CONCORD_CFG_FILE: ${CONCORD_CFG_FILE}"

echo "Removing old containers..."
docker rm -f db dind agent server > /dev/null

docker run -d \
--name db \
-e 'POSTGRES_PASSWORD=q1' \
-e 'PGDATA=/var/lib/postgresql/data/pgdata' \
--mount source=concordDB,target=/var/lib/postgresql/data \
-p 5432:5432 \
"library/postgres:10.4-alpine"

docker run -d \
--link db \
--name server \
-p 8001:8001 \
-v "/tmp:/tmp" \
-v "${CONCORD_CFG_FILE}:${CONCORD_CFG_FILE}:ro" \
-e "CONCORD_CFG_FILE=${CONCORD_CFG_FILE}" \
-e 'DB_URL=jdbc:postgresql://db:5432/postgres' \
"${DOCKER_PREFIX}/concord-server:${VERSION}"

# wait for the server to start
echo -n "Waiting for the server to start"
until $(curl --output /dev/null --silent --head --fail "http://localhost:8001/api/v1/server/ping"); do
    printf '.'
    sleep 1
done
echo "done!"

docker run -d \
--name dind \
--privileged \
-v "/tmp:/tmp" \
docker:stable-dind \
dockerd -H tcp://0.0.0.0:6666 --bip=10.11.13.1/24

docker run -d \
--name agent \
--link server \
--link dind \
-v "/tmp:/tmp" \
-v "${HOME}/.m2/repository:/home/concord/.m2/repository" \
-v "${BASE_DIR}/mvn.json:/opt/concord/conf/mvn.json:ro" \
-v "${BASE_DIR}/agent.conf:/opt/concord/conf/agent.conf:ro" \
-e 'CONCORD_CFG_FILE=/opt/concord/conf/agent.conf' \
-e 'CONCORD_MAVEN_CFG=/opt/concord/conf/mvn.json' \
-e 'CONCORD_DOCKER_LOCAL_MODE=false' \
-e 'SERVER_API_BASE_URL=http://server:8001' \
-e 'SERVER_WEBSOCKET_URL=ws://server:8001/websocket' \
-e 'DOCKER_HOST=tcp://dind:6666' \
"${DOCKER_PREFIX}/concord-agent:${VERSION}"
