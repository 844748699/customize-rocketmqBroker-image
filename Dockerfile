FROM openjdk:8-alpine


RUN export https_proxy=http://192.168.1.100:7890 && \
export http_proxy=http://192.168.1.100:7890 && \
export all_proxy=socks5://192.168.1.100:7891 && apk add --no-cache bash gettext nmap-ncat openssl busybox-extras

ARG user=rocketmq
ARG group=rocketmq
ARG uid=3000
ARG gid=3000

# RocketMQ is run with user `rocketmq`, uid = 1001
# If you bind mount a volume from the host or a data container,
# ensure you use the same uid
RUN addgroup --gid ${gid} ${group} \
    && adduser --uid ${uid} -G ${group} ${user} -s /bin/bash -D

ARG version

# Rocketmq version
ENV ROCKETMQ_VERSION ${version}

# Rocketmq home
ENV ROCKETMQ_HOME  /home/rocketmq/rocketmq-${ROCKETMQ_VERSION}

WORKDIR  ${ROCKETMQ_HOME}

# Install
RUN set -eux; \
    export https_proxy=http://192.168.1.100:7890 && \
    export http_proxy=http://192.168.1.100:7890 && \
    apk add --virtual .build-deps curl gnupg unzip; \
    unset https_proxy && unset http_proxy; \
    wget  -O rocketmq.zip  https://dist.apache.org/repos/dist/release/rocketmq/${ROCKETMQ_VERSION}/rocketmq-all-${ROCKETMQ_VERSION}-bin-release.zip ; \
    wget https://dist.apache.org/repos/dist/release/rocketmq/${ROCKETMQ_VERSION}/rocketmq-all-${ROCKETMQ_VERSION}-bin-release.zip.asc -O rocketmq.zip.asc; \
    #https://www.apache.org/dist/rocketmq/KEYS
	wget https://www.apache.org/dist/rocketmq/KEYS -O KEYS; \
	\
	gpg --import KEYS; \
    gpg --batch --verify rocketmq.zip.asc rocketmq.zip; \
    unzip rocketmq.zip; \
	mv rocketmq-all*/* . ; \
	rmdir rocketmq-all* ; \
	rm rocketmq.zip rocketmq.zip.asc KEYS; \
	apk del .build-deps ; \
    rm -rf /var/cache/apk/* ; \
    rm -rf /tmp/*

# Copy customized scripts
COPY runbroker-customize.sh ${ROCKETMQ_HOME}/bin/

RUN chown -R ${uid}:${gid} ${ROCKETMQ_HOME}

# Expose broker ports
EXPOSE 10909 10911 10912

# Override customized scripts for broker
RUN mv ${ROCKETMQ_HOME}/bin/runbroker-customize.sh ${ROCKETMQ_HOME}/bin/runbroker.sh \
 && chmod a+x ${ROCKETMQ_HOME}/bin/runbroker.sh \
 && chmod a+x ${ROCKETMQ_HOME}/bin/mqbroker

# Export Java options
RUN export JAVA_OPT=" -Duser.home=/opt -Xmx800m -Xmn600m"

# Add ${JAVA_HOME}/lib/ext as java.ext.dirs
RUN sed -i 's/${JAVA_HOME}\/jre\/lib\/ext/${JAVA_HOME}\/jre\/lib\/ext:${JAVA_HOME}\/lib\/ext/' ${ROCKETMQ_HOME}/bin/tools.sh

COPY brokerGenConfig.sh brokerStart.sh ${ROCKETMQ_HOME}/bin/

RUN chmod a+x ${ROCKETMQ_HOME}/bin/brokerGenConfig.sh \
 && chmod a+x ${ROCKETMQ_HOME}/bin/brokerStart.sh

USER ${user}

WORKDIR ${ROCKETMQ_HOME}/bin

CMD ["/bin/bash", "./brokerStart.sh"]
