FROM mastodonc/basejava

RUN curl -sL http://www.mirrorservice.org/sites/ftp.apache.org/kafka/0.8.1.1/kafka_2.10-0.8.1.1.tgz | \
    tar -xzf - -C / --transform 's@\([a-z-]*\)[-_][0-9\.-]*@\1@'

RUN cd /kafka/libs && \
    curl -sOL http://search.maven.org/remotecontent?filepath=org/slf4j/slf4j-log4j12/1.7.9/slf4j-log4j12-1.7.9.jar

RUN rm -f /kafka/config/log4j.properties

RUN mkdir -p /data/kafka

ADD start-kafka.sh /start-kafka
ADD log4j.properties /kafka/config/log4j.properties

CMD ["/bin/bash","/start-kafka"]

EXPOSE 9092
