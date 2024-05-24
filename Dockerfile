#docker build . -t quay.io/semoss/docker:ubi8-rhel

ARG BASE_REGISTRY=quay.io
ARG BASE_IMAGE=semoss/docker-tomcat
ARG BASE_TAG=ubi8-rhel

FROM ${BASE_REGISTRY}/${BASE_IMAGE}:${BASE_TAG} as base

FROM base as mavenpuller

RUN yum install -y curl lsof \
	&& mkdir /opt/semosshome \
	&& cd /opt && git clone https://github.com/SEMOSS/semoss-artifacts \
	&& chmod 777 /opt/semoss-artifacts/artifacts/scripts/*.sh \
	&& /opt/semoss-artifacts/artifacts/scripts/update_latest_dev.sh \
	&& chmod 777 /opt/semosshome/config/Chromedriver/*

FROM base as intermediate

LABEL maintainer="semoss@semoss.org"

ENV PATH=$PATH:/opt/semoss-artifacts/artifacts/scripts
ENV LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/usr/lib:$R_LIBS_SITE/rJava/jri

RUN wget https://downloads.rclone.org/v1.64.2/rclone-v1.64.2-linux-amd64.rpm \
	&& yum install -y rclone-v1.64.2-linux-amd64.rpm\
	&& rm rclone-v1.*.rpm \
	&& chmod 777 /usr/bin/rclone \
	&& mkdir /opt/semosshome \
	&& mkdir $TOMCAT_HOME/webapps/Monolith \
	&& mkdir $TOMCAT_HOME/webapps/SemossWeb \
	&& echo "export LD_PRELOAD=/usr/lib64/libpython3.9.so" >> $TOMCAT_HOME/bin/setenv.sh \
	&& cp $JAVA_HOME/lib/tools.jar $TOMCAT_HOME/lib \
	&& sed -i "s/tomcat.util.scan.StandardJarScanFilter.jarsToSkip=/tomcat.util.scan.StandardJarScanFilter.jarsToSkip=*.jar,/g" $TOMCAT_HOME/conf/catalina.properties; 

RUN cd /opt && git clone https://github.com/SEMOSS/semoss-artifacts \
	&& chmod 777 /opt/semoss-artifacts/artifacts/scripts/*.sh

RUN fips-mode-setup --enable

COPY --from=mavenpuller /opt/semosshome /opt/semosshome
COPY --from=mavenpuller $TOMCAT_HOME/webapps/Monolith $TOMCAT_HOME/webapps/Monolith
COPY --from=mavenpuller $TOMCAT_HOME/webapps/SemossWeb $TOMCAT_HOME/webapps/SemossWeb
COPY --from=mavenpuller /opt/semoss-artifacts/ver.txt /opt/semoss-artifacts/ver.txt

FROM scratch AS final

ENV JAVA_HOME=/usr/lib/jvm/zulu8
ENV TOMCAT_HOME=/opt/apache-tomcat-9.0.88
ENV MAVEN_HOME=/opt/apache-maven-3.8.5
ENV LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/usr/local/lib/python3.9/dist-packages/jep
ENV PATH=$PATH:${MAVEN_HOME}/bin:${TOMCAT_HOME}/bin:${JAVA_HOME}/bin:/usr/lib/R/bin::/usr/lib/R/pandoc-2.17.1.1/bin:/opt/semoss-artifacts/artifacts/scripts

COPY --from=intermediate  / /
WORKDIR /opt/semoss-artifacts/artifacts/scripts
CMD ["sh", "-c", "source /opt/set_env.env && exec $TOMCAT_HOME/bin/start.sh"]
