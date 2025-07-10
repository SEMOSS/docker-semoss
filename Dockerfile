# Based on quay.io/semoss/docker-tomcat:ubi8-rhel
#docker build . -t quay.io/semoss/docker:ubi8-rhel

ARG BASE_REGISTRY=quay.io
ARG BASE_IMAGE=semoss/docker-tomcat
ARG BASE_TAG=ubi8-rhel

# JAVA, JDK and TOMCAT default versions
ARG AZUL_ZULU_VERSION=21.42.19
ARG JAVA_HOME=/usr/lib/jvm/zulu21
ARG JDK_VERSION=21.0.7
ARG TOMCAT_VERSION=9.0.107
ARG MAVEN_HOME=/opt/apache-maven-3.8.5

FROM ${BASE_REGISTRY}/${BASE_IMAGE}:${BASE_TAG} AS base

FROM base AS mavenpuller
# Tomcat  
ARG TOMCAT_VERSION
ARG TOMCAT_HOME=/opt/apache-tomcat-${TOMCAT_VERSION}

ENV TOMCAT_VERSION=${TOMCAT_VERSION}
ENV TOMCAT_HOME=${TOMCAT_HOME}

RUN yum install -y curl lsof \
	&& mkdir /opt/semosshome \
	&& cd /opt && git clone https://github.com/SEMOSS/semoss-artifacts \
	&& chmod 777 /opt/semoss-artifacts/artifacts/scripts/*.sh \
	&& /opt/semoss-artifacts/artifacts/scripts/update_latest_dev.sh \
	&& chmod 777 /opt/semosshome/config/Chromedriver/*

FROM base AS intermediate

LABEL maintainer="semoss@semoss.org"

ENV PATH=$PATH:/opt/semoss-artifacts/artifacts/scripts
ENV LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/usr/lib:$R_LIBS_SITE/rJava/jri

# Tomcat and Maven 
ARG TOMCAT_VERSION
ARG TOMCAT_HOME=/opt/apache-tomcat-${TOMCAT_VERSION}

# JAVA arguments
ARG AZUL_ZULU_VERSION
ARG JAVA_HOME
ARG JDK_VERSION

#JAVA env values for install_java.sh
ENV AZUL_ZULU_VERSION=${AZUL_ZULU_VERSION}
ENV JDK_VERSION=${JDK_VERSION}

ENV TOMCAT_VERSION=${TOMCAT_VERSION}
ENV TOMCAT_HOME=${TOMCAT_HOME}
ENV JAVA_HOME=${JAVA_HOME}

RUN wget https://downloads.rclone.org/v1.64.2/rclone-v1.64.2-linux-amd64.rpm \
	&& yum install -y rclone-v1.64.2-linux-amd64.rpm\
	&& rm rclone-v1.*.rpm \
	&& chmod 777 /usr/bin/rclone \
	&& mkdir /opt/semosshome \
	&& mkdir $TOMCAT_HOME/webapps/Monolith \
	&& mkdir $TOMCAT_HOME/webapps/SemossWeb \
	&& echo "export LD_PRELOAD=/usr/lib64/libpython3.9.so" >> $TOMCAT_HOME/bin/setenv.sh \
	&& sed -i "s/tomcat.util.scan.StandardJarScanFilter.jarsToSkip=/tomcat.util.scan.StandardJarScanFilter.jarsToSkip=*.jar,/g" $TOMCAT_HOME/conf/catalina.properties;
	# Removing step to copy JAVA_HOME/lib/tools.jar since this is not present in ZULU java 21
	# && cp $JAVA_HOME/lib/tools.jar $TOMCAT_HOME/lib \
	

RUN cd /opt && git clone https://github.com/SEMOSS/semoss-artifacts \
	&& chmod 777 /opt/semoss-artifacts/artifacts/scripts/*.sh

RUN fips-mode-setup --enable

COPY --from=mavenpuller /opt/semosshome /opt/semosshome
COPY --from=mavenpuller $TOMCAT_HOME/webapps/Monolith $TOMCAT_HOME/webapps/Monolith
COPY --from=mavenpuller $TOMCAT_HOME/webapps/SemossWeb $TOMCAT_HOME/webapps/SemossWeb
COPY --from=mavenpuller /opt/semoss-artifacts/ver.txt /opt/semoss-artifacts/ver.txt

FROM scratch AS final

# Tomcat arguments 
ARG TOMCAT_VERSION 
ARG TOMCAT_HOME=/opt/apache-tomcat-${TOMCAT_VERSION} 

# JAVA arguments
ARG JAVA_HOME 

ENV TOMCAT_VERSION=${TOMCAT_VERSION} 
ENV TOMCAT_HOME=${TOMCAT_HOME} 
ENV JAVA_HOME=${JAVA_HOME} 

ENV MAVEN_HOME=/opt/apache-maven-3.8.5
ENV LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/usr/local/lib/python3.9/dist-packages/jep
ENV PATH=$PATH:${MAVEN_HOME}/bin:${TOMCAT_HOME}/bin:${JAVA_HOME}/bin:/usr/lib/R/bin::/usr/lib/R/pandoc-2.17.1.1/bin:/opt/semoss-artifacts/artifacts/scripts

COPY --from=intermediate  / /

RUN useradd -u 1001 -r -g 0 -d ${HOME} -s /bin/bash -c "Default Application User" default \ 
	&& chown -R 1001:0 ${HOME}

RUN chown -R 1001:0 /opt

WORKDIR /opt/semoss-artifacts/artifacts/scripts
CMD ["sh", "-c", "source /opt/set_env.env && exec $TOMCAT_HOME/bin/start.sh"]
