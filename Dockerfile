#docker build . -t quay.io/semoss/docker:R4.2.1-debian11

ARG BASE_REGISTRY=quay.io
ARG BASE_IMAGE=semoss/docker-r-python
ARG BASE_TAG=R4.2.1-debian11

ARG BUILDER_BASE_REGISTRY=quay.io
ARG BUILDER_BASE_IMAGE=semoss/docker-tomcat
ARG BUILDER_BASE_TAG=debian11

FROM ${BASE_REGISTRY}/${BASE_IMAGE}:${BASE_TAG} as base

FROM ${BUILDER_BASE_REGISTRY}/${BUILDER_BASE_IMAGE}:${BUILDER_BASE_TAG} as mavenpuller

#ADD "http://worldtimeapi.org/api/timezone/America/New_York" skipcache
RUN apt-get update -y \
	&& apt-get install -y curl lsof \
	&& mkdir /opt/semosshome \
    && cd /opt && git clone https://github.com/SEMOSS/semoss-artifacts \
	&& chmod 777 /opt/semoss-artifacts/artifacts/scripts/*.sh \
	&& /opt/semoss-artifacts/artifacts/scripts/update_latest_dev.sh \
	&& chmod 777 /opt/semosshome/config/Chromedriver/*

FROM base

LABEL maintainer="semoss@semoss.org"

ENV PATH=$PATH:/opt/semoss-artifacts/artifacts/scripts
ENV R_HOME=/usr/lib/R
ENV R_LIBS_SITE=/usr/local/lib/R/site-library
ENV RSTUDIO_PANDOC=/usr/lib/R/pandoc-2.17.1.1/bin
ENV LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/usr/lib:$R_LIBS_SITE/rJava/jri

# Install Rclone
# Create semosshome
# Clone semoss-artifacts scripts
# Update latest dev code
# Install Chrome
# Set LD_PRELOAD on Tomcat

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
	&& apt-get install -y google-chrome-stable

RUN apt-get update -y \
	&& apt-get install -y curl lsof \
	&& cd /opt && git clone https://github.com/SEMOSS/semoss-artifacts \
	&& chmod 777 /opt/semoss-artifacts/artifacts/scripts/*.sh

COPY --from=mavenpuller /opt/semosshome /opt/semosshome
COPY --from=mavenpuller $TOMCAT_HOME/webapps/Monolith $TOMCAT_HOME/webapps/Monolith
COPY --from=mavenpuller $TOMCAT_HOME/webapps/SemossWeb $TOMCAT_HOME/webapps/SemossWeb
COPY --from=mavenpuller /opt/semoss-artifacts/ver.txt /opt/semoss-artifacts/ver.txt

WORKDIR /opt/semoss-artifacts/artifacts/scripts

CMD ["sh", "-c", "exec $TOMCAT_HOME/bin/start.sh"]
