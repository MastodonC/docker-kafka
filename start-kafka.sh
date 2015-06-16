#!/bin/bash

source /etc/mastodonc/docker-functions

# empty array if nothing found globbing.
shopt -s failglob

LOG_CONFIG_FILE=/kafka/config/log4j.properties
SERVER_CONFIG_FILE=/kafka/config/server.properties

BROKER_ID=${KAFKA_BROKER_ID:-0}
ADVERTISED_HOSTNAME=${KAFKA_ADVERTISED_HOSTNAME:-$(hostname -I)}
ADVERTISED_PORT=${KAFKA_ADVERTISED_PORT:-9092}
MAX_MESSAGE_SIZE=${KAFKA_MAX_MESSAGE_SIZE:-1000000}

DIR_TAIL="kafka/${HOSTNAME}/${BROKER_ID}"
LOGS_DIR="/logs/${DIR_TAIL}"
ZK_CHROOT=${ZK_CHROOT:-/}

function join { local IFS="$1"; shift; echo "$*"; }

if [ -z "${DATA_DIR_PATTERN}" ] ; then
    DATA_DIRS="/data/${DIR_TAIL}"
    mkdir -p ${DATA_DIRS}
else
    ddirs=()
    candidates=(${DATA_DIR_PATTERN})
    for dir in ${candidates[@]}
    do
	thedir="$(pwd)${dir}/${DIR_TAIL}"
	mkdir -p ${thedir}
	ddirs+=("${thedir}")
    done
    DATA_DIRS=$(join , ${ddirs[@]})
fi

echo "ADVERTISED_HOSTNAME is ${ADVERTISED_HOSTNAME}"
echo "ADVERTISED_PORT is ${ADVERTISED_PORT}"
echo "DATA_DIRS is ${DATA_DIRS}"
echo "BROKER_ID is ${BROKER_ID}"
echo "ZK_CHROOT is ${ZK_CHROOT}"
echo "MAX_MESSAGE_SIZE is ${MAX_MESSAGE_SIZE}"

mkdir -p "${LOGS_DIR}"

sed -i \
    -e "s@#advertised.host\.name=.*@advertised.host.name=${ADVERTISED_HOSTNAME}@" \
    -e "s@broker\.id=0@broker.id=${BROKER_ID}@" \
    -e "s@log\.dirs=/tmp/kafka-logs@log.dirs=${DATA_DIRS}@" \
    ${SERVER_CONFIG_FILE}

sed -i \
    -e "s@#advertised\.port=.*@advertised.port=${ADVERTISED_PORT}@" \
    ${SERVER_CONFIG_FILE}

echo "replica.fetch.max.bytes=${MAX_MESSAGE_SIZE}" >> ${SERVER_CONFIG_FILE}
echo "message.max.bytes=${MAX_MESSAGE_SIZE}" >> ${SERVER_CONFIG_FILE}

#Add entries for zookeeper peers.
hosts=()
for i in $(seq 255)
do
    zk_name=$(printf "ZK%02d" ${i})
    zk_addr_name="${zk_name}_PORT_2181_TCP_ADDR"
    zk_port_name="${zk_name}_PORT_2181_TCP_PORT"

    [ ! -z "${!zk_addr_name}" ] && hosts+=("${!zk_addr_name}:${!zk_port_name}")
done

ZK_CONNECT="$(join , ${hosts[@]})${ZK_CHROOT}"
echo "Zookeeper connect string is ${ZK_CONNECT}"

sed -i \
     -e "s@zookeeper\.connect=.*@zookeeper.connect=${ZK_CONNECT}@" \
     ${SERVER_CONFIG_FILE}

export LOGS_DIR

ensure_rsyslog_running && \
    /kafka/bin/kafka-server-start.sh /kafka/config/server.properties
