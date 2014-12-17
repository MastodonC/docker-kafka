#!/bin/bash

LOG_CONFIG_FILE=/kafka/config/log4j.properties
SERVER_CONFIG_FILE=/kafka/config/server.properties

LOGS_DIR="/logs/kafka/${HOSTNAME}/${KAFKA_BROKER_ID}"

DATA_DIR_TAIL="kafka/${HOSTNAME}/${KAFKA_BROKER_ID}"

function join { local IFS="$1"; shift; echo "$*"; }

if [ -z "${DATA01_DIR}" ] ; then
    DATA_DIR="/data/${DATA_DIR_TAIL}"
    mkdir -p ${DATA_DIR}
else
    ddirs=()
    for i in $(seq 255); do
	ddir_name=$(printf "DATA%02d_DIR" ${i})
	the_dir="${!ddir_name}"
	if [ -n "${the_dir}" ]; then
	    ddirs+=("${the_dir}/${DATA_DIR_TAIL}")
	    mkdir -p ${the_dir}
	fi
    done
    DATA_DIR=$(join , ${ddirs[@]})
fi

echo "log.dirs/DATA_DIR is ${DATA_DIR}"

mkdir -p "${LOGS_DIR}"

sed -i \
    -e "s@#advertised.host\.name=.*@advertised.host.name=${KAFKA_ADVERTISED_HOSTNAME:-$(hostname -I)}@" \
    -e "s@broker\.id=0@broker.id=${KAFKA_BROKER_ID:-0}@" \
    -e "s@log\.dirs=/tmp/kafka-logs@log.dirs=${DATA_DIR}@" \
    ${SERVER_CONFIG_FILE}

sed -i \
    -e "s@#advertised\.port=.*@advertised.port=${KAFKA_ADVERTISED_PORT:-9092}@" \
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

    [ ! -z "${!zk_addr_name}" ] && hosts+=("${!zk_addr_name}:${!zk_port_name}")
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
