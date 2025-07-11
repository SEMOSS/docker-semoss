# Based on quay.io/semoss/docker-tomcat:cuda12.5
#docker build . -t quay.io/semoss/docker:cuda12.5

ARG BASE_REGISTRY=quay.io
ARG BASE_IMAGE=semoss/docker-tomcat
ARG BASE_TAG=cuda12.5

ARG BUILDER_BASE_REGISTRY=quay.io
ARG BUILDER_BASE_IMAGE=semoss/docker-tomcat
ARG BUILDER_BASE_TAG=cuda12.5

# ARG R_HOME=/usr/lib/R
# ARG R_LIBS_SITE=/usr/local/lib/R/site-library
# ARG RSTUDIO_PANDOC=/usr/lib/R/pandoc-2.17.1.1/bin

# JAVA and TOMCAT default versions
ARG TOMCAT_VERSION=9.0.107
ARG JAVA_HOME=/usr/lib/jvm/zulu21
ARG TOMCAT_HOME=/opt/apache-tomcat-${TOMCAT_VERSION}
ARG MAVEN_HOME=/opt/apache-maven-3.8.5


FROM ${BASE_REGISTRY}/${BASE_IMAGE}:${BASE_TAG} AS base

FROM ${BUILDER_BASE_REGISTRY}/${BUILDER_BASE_IMAGE}:${BUILDER_BASE_TAG} AS mavenpuller

# Tomcat  
ARG TOMCAT_VERSION
ARG TOMCAT_HOME=/opt/apache-tomcat-${TOMCAT_VERSION}
ENV TOMCAT_VERSION=${TOMCAT_VERSION}
ENV TOMCAT_HOME=${TOMCAT_HOME}

RUN apt-get update -y \
	&& apt-get install -y curl lsof \
	&& mkdir /opt/semosshome \
	&& cd /opt && git clone https://github.com/SEMOSS/semoss-artifacts \
	&& chmod 777 /opt/semoss-artifacts/artifacts/scripts/*.sh \
	&& /opt/semoss-artifacts/artifacts/scripts/update_latest_dev.sh \
	&& chmod 777 /opt/semosshome/config/Chromedriver/*

FROM base AS intermediate

# Tomcat  
ARG TOMCAT_VERSION
ARG TOMCAT_HOME=/opt/apache-tomcat-${TOMCAT_VERSION}
ENV TOMCAT_VERSION=${TOMCAT_VERSION}
ENV TOMCAT_HOME=${TOMCAT_HOME}

LABEL maintainer="semoss@semoss.org"

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
	&& echo "export LD_PRELOAD=/usr/lib/python3.10/config-3.10-x86_64-linux-gnu/libpython3.10.so" >> $TOMCAT_HOME/bin/setenv.sh \
	&& sed -i "s/tomcat.util.scan.StandardJarScanFilter.jarsToSkip=/tomcat.util.scan.StandardJarScanFilter.jarsToSkip=*.jar,/g" $TOMCAT_HOME/conf/catalina.properties;
	# Removing step to copy JAVA_HOME/lib/tools.jar since this is not present in ZULU java 21
	# && cp $JAVA_HOME/lib/tools.jar $TOMCAT_HOME/lib \
	

RUN wget -q -O - https://dl.google.com/linux/linux_signing_key.pub | apt-key add - \
	&& echo "deb http://dl.google.com/linux/chrome/deb/ stable main" | tee /etc/apt/sources.list.d/google-chrome.list \
	&& apt-get update \
	&& apt-get install -y google-chrome-stable

RUN apt-get update -y \
	&& apt-get install -y lsof \
	&& cd /opt && git clone https://github.com/SEMOSS/semoss-artifacts \
	&& chmod 777 /opt/semoss-artifacts/artifacts/scripts/*.sh

COPY --from=mavenpuller /opt/semosshome /opt/semosshome
COPY --from=mavenpuller $TOMCAT_HOME/webapps/Monolith $TOMCAT_HOME/webapps/Monolith
COPY --from=mavenpuller $TOMCAT_HOME/webapps/SemossWeb $TOMCAT_HOME/webapps/SemossWeb
COPY --from=mavenpuller /opt/semoss-artifacts/ver.txt /opt/semoss-artifacts/ver.txt

RUN sed -i "s:R_KILL_ON_STARTUP.*:R_KILL_ON_STARTUP\tfalse:g" /opt/semosshome/RDF_Map.prop

# FROM scratch AS final

# COPY --from=intermediate  / /
# # ARG R_HOME
# # ARG R_LIBS_SITE
# # ARG RSTUDIO_PANDOC
# ARG JAVA_HOME
# ARG TOMCAT_HOME
# ARG MAVEN_HOME

# # ENV R_HOME=$R_HOME
# # ENV R_LIBS_SITE=$R_LIBS_SITE
# # ENV RSTUDIO_PANDOC=$RSTUDIO_PANDOC
# ENV JAVA_HOME=$JAVA_HOME
# ENV TOMCAT_HOME=$TOMCAT_HOME
# ENV MAVEN_HOME=$MAVEN_HOME
# ENV PATH=$PATH:$MAVEN_HOME/bin:$TOMCAT_HOME/bin:$JAVA_HOME/bin:/opt/semoss-artifacts/artifacts/scripts

WORKDIR /opt/semoss-artifacts/artifacts/scripts
CMD ["sh", "-c", ". /opt/set_env.env && exec $TOMCAT_HOME/bin/start.sh"]
