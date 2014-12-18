#!/bin/bash

# empty array if nothing found globbing.
shopt -s failglob

LOG_CONFIG_FILE=/kafka/config/log4j.properties
SERVER_CONFIG_FILE=/kafka/config/server.properties

BROKER_ID=${KAFKA_BROKER_ID:-0}
ADVERTISED_HOSTNAME=${KAFKA_ADVERTISED_HOSTNAME:-$(hostname -I)}
ADVERTISED_PORT=${KAFKA_ADVERTISED_PORT:-9092}

DIR_TAIL="kafka/${HOSTNAME}/${BROKER_ID}"
LOGS_DIR="/logs/${DIR_TAIL}"

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

mkdir -p "${LOGS_DIR}"

sed -i \
    -e "s@#advertised.host\.name=.*@advertised.host.name=${ADVERTISED_HOSTNAME}@" \
    -e "s@broker\.id=0@broker.id=${BROKER_ID}@" \
    -e "s@log\.dirs=/tmp/kafka-logs@log.dirs=${DATA_DIRS}@" \
    ${SERVER_CONFIG_FILE}

sed -i \
    -e "s@#advertised\.port=.*@advertised.port=${ADVERTISED_PORT}@" \
    ${SERVER_CONFIG_FILE}

sed -i \
    -e "s@kafka.logs.dir=.*@kafka.logs.dir=${LOGS_DIR}/@" \
    -e "/log4j.logger.kafka=INFO, kafkaAppender/d" \
    ${LOG_CONFIG_FILE}

#Add entries for zookeeper peers.
hosts=()
for i in $(seq 255)
do
    zk_name=$(printf "ZK%02d" ${i})
    zk_addr_name="${zk_name}_PORT_2181_TCP_ADDR"
    zk_port_name="${zk_name}_PORT_2181_TCP_PORT"

    [ ! -z "${!zk_addr_name}" ] && hosts+=("${!zk_addr_name}:${!zk_port_name}/kafka")
done

ZK_CONNECT=$(join , ${hosts[@]})
echo "Zookeeper connect string is ${ZK_CONNECT}"

sed -i \
     -e "s@zookeeper\.connect=.*@zookeeper.connect=${ZK_CONNECT}@" \
     ${SERVER_CONFIG_FILE}


cat <<EOF >> ${LOG_CONFIG_FILE}

# Add Logstash Appender
log4j.appender.logstashAppender=org.apache.log4j.net.SocketAppender
log4j.appender.logstashAppender.Port=${LOGSTASH_PORT_4561_TCP_PORT}
log4j.appender.logstashAppender.RemoteHost=${LOGSTASH_PORT_4561_TCP_ADDR}
log4j.appender.logstashAppender.ReconnectionDelay=30000

log4j.logger.kafka=INFO, kafkaAppender, logstashAppender
EOF

/kafka/bin/kafka-server-start.sh /kafka/config/server.properties
