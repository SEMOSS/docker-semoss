#docker build . -t quay.io/semoss/docker:ubi8

ARG BASE_REGISTRY=docker.cfg.deloitte.com
ARG BASE_IMAGE=ashok/docker-tomcat
ARG BASE_TAG=ubi8-r

ARG BUILDER_BASE_REGISTRY=docker.cfg.deloitte.com
ARG BUILDER_BASE_IMAGE=ashok/docker-tomcat
ARG BUILDER_BASE_TAG=ubi8-r

FROM ${BASE_REGISTRY}/${BASE_IMAGE}:${BASE_TAG} as base

FROM ${BUILDER_BASE_REGISTRY}/${BUILDER_BASE_IMAGE}:${BUILDER_BASE_TAG} as mavenpuller

#ADD "http://worldtimeapi.org/api/timezone/America/New_York" skipcache
RUN yum install -y curl lsof \
	#apt-get update -y \
	&& mkdir /opt/semosshome \
	&& cd /opt && git clone https://github.com/SEMOSS/semoss-artifacts \
	&& chmod 777 /opt/semoss-artifacts/artifacts/scripts/*.sh \
	&& /opt/semoss-artifacts/artifacts/scripts/update_latest_dev.sh \
	&& chmod 777 /opt/semosshome/config/Chromedriver/*

FROM base

LABEL maintainer="semoss@semoss.org"

ENV PATH=$PATH:/opt/semoss-artifacts/artifacts/scripts
ENV LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/usr/lib:$R_LIBS_SITE/rJava/jri

# Install Rclone
# Create semosshome
# Clone semoss-artifacts scripts
# Update latest dev code
# Install Chrome
# Set LD_PRELOAD on Tomcat

RUN	wget https://downloads.rclone.org/v1.64.2/rclone-v1.64.2-linux-amd64.rpm \
	&& yum install -y rclone-v1.64.2-linux-amd64.rpm\
	&& rm rclone-v1.*.rpm \
	&& chmod 777 /usr/bin/rclone \
	&& mkdir /opt/semosshome \
	&& mkdir $TOMCAT_HOME/webapps/Monolith \
	&& mkdir $TOMCAT_HOME/webapps/SemossWeb \
	&& echo "export LD_PRELOAD=/usr/local/lib/libpython3.9.so" >> $TOMCAT_HOME/bin/setenv.sh \
	&& cp $JAVA_HOME/lib/tools.jar $TOMCAT_HOME/lib \
	&& sed -i "s/tomcat.util.scan.StandardJarScanFilter.jarsToSkip=/tomcat.util.scan.StandardJarScanFilter.jarsToSkip=*.jar,/g" $TOMCAT_HOME/conf/catalina.properties;

#COPY *.repo /etc/yum.repos.d/

# RUN cd /opt \
# 	&& wget https://dl.google.com/linux/direct/google-chrome-stable_current_x86_64.rpm \
# 	&& wget http://vault.centos.org/8-stream/AppStream/Source/SPackages/xdg-utils-1.1.2-5.el8.src.rpm \
# 	&& wget http://vault.centos.org/8-stream/BaseOS/Source/SPackages/liberation-fonts-2.00.3-7.el8.src.rpm \
# 	&& wget http://mirror.centos.org/centos/8-stream/AppStream/x86_64/os/Packages/vulkan-loader-1.3.250.1-1.el8.x86_64.rpm \
# 	&& yum install -y  *.rpm \ 
# 	&& rm *.rpm

RUN cd /opt && git clone https://github.com/SEMOSS/semoss-artifacts \
	&& chmod 777 /opt/semoss-artifacts/artifacts/scripts/*.sh

COPY --from=mavenpuller /opt/semosshome /opt/semosshome
COPY --from=mavenpuller $TOMCAT_HOME/webapps/Monolith $TOMCAT_HOME/webapps/Monolith
COPY --from=mavenpuller $TOMCAT_HOME/webapps/SemossWeb $TOMCAT_HOME/webapps/SemossWeb
COPY --from=mavenpuller /opt/semoss-artifacts/ver.txt /opt/semoss-artifacts/ver.txt

WORKDIR /opt/semoss-artifacts/artifacts/scripts

CMD ["sh", "-c", "exec $TOMCAT_HOME/bin/start.sh"]
