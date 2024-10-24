#docker build . -t quay.io/semoss/docker:debian11

ARG BASE_REGISTRY=quay.io
ARG BASE_IMAGE=semoss/docker-tomcat
ARG BASE_TAG=debian11-1

ARG BUILDER_BASE_REGISTRY=quay.io
ARG BUILDER_BASE_IMAGE=semoss/docker-tomcat
ARG BUILDER_BASE_TAG=debian11-1

ARG JAVA_HOME=/usr/lib/jvm/zulu8
ARG TOMCAT_HOME=/opt/apache-tomcat-9.0.88
ARG R_HOME=/usr/lib/R
ARG R_LIBS_SITE=/usr/local/lib/R/site-library
ARG RSTUDIO_PANDOC=/usr/lib/R/pandoc-2.17.1.1/bin
ARG LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/usr/lib:$R_LIBS_SITE/rJava/jri


FROM ${BASE_REGISTRY}/${BASE_IMAGE}:${BASE_TAG} AS base

FROM ${BUILDER_BASE_REGISTRY}/${BUILDER_BASE_IMAGE}:${BUILDER_BASE_TAG} as mavenpuller

RUN apt-get update -y \
	&& apt-get install -y lsof \
	&& mkdir /opt/semosshome \
	&& cd /opt && git clone https://github.com/SEMOSS/semoss-artifacts \
	&& chmod 777 /opt/semoss-artifacts/artifacts/scripts/*.sh \
	&& /opt/semoss-artifacts/artifacts/scripts/update_latest_dev.sh \
	&& chmod 777 /opt/semosshome/config/Chromedriver/*

FROM base as intermediate

LABEL maintainer="semoss@semoss.org"

ARG LD_LIBRARY_PATH

ENV PATH=$PATH:/opt/semoss-artifacts/artifacts/scripts
ENV LD_LIBRARY_PATH=$LD_LIBRARY_PATH

RUN	wget https://downloads.rclone.org/v1.60.0/rclone-v1.60.0-linux-amd64.deb \
	&& dpkg -i rclone-v1.60.0-linux-amd64.deb \
	&& apt-get install -f \
	&& rm rclone-v1.60.0-linux-amd64.deb \
	&& chmod 777 /usr/bin/rclone \
	&& mkdir /opt/semosshome \
	&& mkdir $TOMCAT_HOME/webapps/Monolith \
	&& mkdir $TOMCAT_HOME/webapps/SemossWeb \
	&& echo "export LD_PRELOAD=/usr/lib/python3.9/config-3.9-x86_64-linux-gnu/libpython3.9.so" >> $TOMCAT_HOME/bin/setenv.sh \
	&& cp $JAVA_HOME/lib/tools.jar $TOMCAT_HOME/lib \
	&& sed -i "s/tomcat.util.scan.StandardJarScanFilter.jarsToSkip=/tomcat.util.scan.StandardJarScanFilter.jarsToSkip=*.jar,/g" $TOMCAT_HOME/conf/catalina.properties;

RUN wget -q -O - https://dl.google.com/linux/linux_signing_key.pub | apt-key add - \
	&& echo "deb http://dl.google.com/linux/chrome/deb/ stable main" | tee /etc/apt/sources.list.d/google-chrome.list \
	&& apt-get update \
	&& apt-get install -y google-chrome-stable bash

RUN apt-get update -y \
	&& apt-get install -y curl lsof \
	&& cd /opt && git clone https://github.com/SEMOSS/semoss-artifacts \
	&& chmod 777 /opt/semoss-artifacts/artifacts/scripts/*.sh

COPY --from=mavenpuller /opt/semosshome /opt/semosshome
COPY --from=mavenpuller $TOMCAT_HOME/webapps/Monolith $TOMCAT_HOME/webapps/Monolith
COPY --from=mavenpuller $TOMCAT_HOME/webapps/SemossWeb $TOMCAT_HOME/webapps/SemossWeb
COPY --from=mavenpuller /opt/semoss-artifacts/ver.txt /opt/semoss-artifacts/ver.txt

# FROM scratch AS final

# COPY --from=intermediate  / /

# ARG JAVA_HOME
# ARG TOMCAT_HOME
# ARG R_HOME
# ARG R_LIBS_SITE
# ARG RSTUDIO_PANDOC

# ENV JAVA_HOME=$JAVA_HOME
# ENV TOMCAT_HOME=$TOMCAT_HOME
# ENV R_HOME=$R_HOME
# ENV R_LIBS_SITE=$R_LIBS_SITE
# ENV RSTUDIO_PANDOC=$RSTUDIO_PANDOC

ENV PATH=$PATH:/opt/apache-maven-3.8.5/bin:$TOMCAT_HOME/bin:$JAVA_HOME/bin:/usr/lib/R/bin::/usr/lib/R/pandoc-2.17.1.1/bin:/opt/semoss-artifacts/artifacts/scripts
WORKDIR /opt/semoss-artifacts/artifacts/scripts
CMD ["bash", "-c", "exec $TOMCAT_HOME/bin/start.sh" ]
