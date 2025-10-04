ARG OS_DISTRIBUTION=alpine
ARG OS_VERSION=latest


FROM ${OS_DISTRIBUTION}:${OS_VERSION}


ENV APP_NAME="prometheus"
ENV APP_VERSION="2.48.1"
ENV APP_DATA_DIR="/data"
ENV APP_LOGS_DIR="/logs"
ENV KUBERNETES_NAMESPACE="monitoring"
ENV RETENTION_TIME="7d"
ENV LOG_LEVEL="info"


LABEL MAINTAINER "Franck Levesque<franck.levesque@gmail.com>"
LABEL DOCKER_IMAGE_NAME ${APP_NAME}
LABEL DOCKER_IMAGE_VERSION ${APP_VERSION}
LABEL DOCKER_IMAGE_NAMESPACE ${KUBERNETES_NAMESPACE}

ENV LANG='en_US.UTF-8' LANGUAGE='en_US:en' LC_ALL='en_US.UTF-8'
RUN /sbin/apk --no-progress --clean-protected --no-cache upgrade \
 && /bin/echo -n "" > /etc/fstab \
 && /bin/sed -i 's/root:\/bin\/ash/root:\/sbin\/nologin/' /etc/passwd

ADD https://github.com/${APP_NAME}/${APP_NAME}/releases/download/v${APP_VERSION}/${APP_NAME}-${APP_VERSION}.linux-amd64.tar.gz /
WORKDIR /
RUN tar xzf ${APP_NAME}-${APP_VERSION}.linux-amd64.tar.gz \
  && rm ${APP_NAME}-${APP_VERSION}.linux-amd64.tar.gz \
  && ln -s ${APP_NAME}-${APP_VERSION}.linux-amd64 ${APP_NAME} \
  && mkdir -p ${APP_DATA_DIR} ${APP_LOGS_DIR} \
  && chown -R nobody:nogroup ${APP_DATA_DIR} ${APP_LOGS_DIR}

USER   nobody
EXPOSE 9090

VOLUME ["/data", "/logs", "/config"]

CMD ["sh","-c","/${APP_NAME}/${APP_NAME} --config.file=/config/${APP_NAME}.yml --storage.tsdb.retention.time=${RETENTION_TIME} --log.level=${LOG_LEVEL} --web.enable-lifecycle"]