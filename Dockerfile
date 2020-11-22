FROM semoss/docker-r-python:R3.6.1-debian10.5-builder as base

FROM semoss/docker-tomcat:9.0.37 as mavenpuller

# skip cache based on the semoss-artifacts 
RUN apt-get update -y \
	&& apt-get install -y curl lsof \
	&& mkdir /opt/semosshome
ADD "https://api.github.com/repos/SEMOSS/semoss-artifacts/git/refs/heads/master" skipcache
RUN cd /opt && git clone https://github.com/SEMOSS/semoss-artifacts \
	&& chmod 777 /opt/semoss-artifacts/artifacts/scripts/*.sh \
	&& /opt/semoss-artifacts/artifacts/scripts/update_latest_dev.sh \
	&& chmod 777 /opt/semosshome/config/Chromedriver/*

FROM base

LABEL maintainer="semoss@semoss.org"

ENV PATH=$PATH:/opt/semoss-artifacts/artifacts/scripts
ENV LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/usr/lib:/usr/local/lib/R/site-library/rJava/jri
ENV R_HOME=/usr/lib/R

# Install Rclone
# Create semosshome
# Clone semoss-artifacts scripts
# Update latest dev code
# Install Chrome
# Set LD_PRELOAD on Tomcat

RUN	wget https://downloads.rclone.org/v1.47.0/rclone-v1.47.0-linux-amd64.deb \
	&& dpkg -i rclone-v1.47.0-linux-amd64.deb \
	&& apt-get install -f \
	&& rm rclone-v1.47.0-linux-amd64.deb \
	&& chmod 777 /usr/bin/rclone \
	&& mkdir /opt/semosshome \
	&& mkdir $TOMCAT_HOME/webapps/Monolith \
	&& mkdir $TOMCAT_HOME/webapps/SemossWeb \
	&& echo "export LD_PRELOAD=/usr/lib/python3.7/config-3.7m-x86_64-linux-gnu/libpython3.7.so" >> $TOMCAT_HOME/bin/setenv.sh \
	&& cp /usr/lib/jvm/zulu8.44.0.13-ca-fx-jdk8.0.242-linux_x64/lib/tools.jar $TOMCAT_HOME/lib \
	&& sed -i "s/tomcat.util.scan.StandardJarScanFilter.jarsToSkip=/tomcat.util.scan.StandardJarScanFilter.jarsToSkip=*.jar,/g" $TOMCAT_HOME/conf/catalina.properties;

RUN wget -q -O - https://dl.google.com/linux/linux_signing_key.pub | apt-key add - \
	&& echo "deb http://dl.google.com/linux/chrome/deb/ stable main" | tee /etc/apt/sources.list.d/google-chrome.list \
	&& apt-get update \
	&& apt-get install -y google-chrome-stable

ADD "https://api.github.com/repos/SEMOSS/semoss-artifacts/git/refs/heads/master" skipcache
RUN apt-get update -y \
	&& apt-get install -y curl lsof \
	&& cd /opt && git clone https://github.com/SEMOSS/semoss-artifacts \
	&& chmod 777 /opt/semoss-artifacts/artifacts/scripts/*.sh
	
RUN rm /usr/local/lib/python3.7/dist-packages/distributed/tests/tls-ca-key.pem \
	&& rm /usr/local/lib/python3.7/dist-packages/distributed/tests/tls-key-cert.pem \
	&& rm /usr/local/lib/python3.7/dist-packages/distributed/tests/tls-key.pem \
	&& rm /usr/local/lib/python3.7/dist-packages/distributed/tests/tls-self-signed-key.pem \
	&& rm /usr/local/lib/python3.7/dist-packages/tornado/test/test.key \
	&& rm /usr/share/doc/libnet-ssleay-perl/examples/server_key.pem

COPY --from=mavenpuller /opt/semosshome /opt/semosshome
RUN chmod 777 /opt/semosshome/social.properties
COPY --from=mavenpuller $TOMCAT_HOME/webapps/Monolith $TOMCAT_HOME/webapps/Monolith
COPY --from=mavenpuller $TOMCAT_HOME/webapps/SemossWeb $TOMCAT_HOME/webapps/SemossWeb
COPY --from=mavenpuller /opt/semoss-artifacts/ver.txt /opt/semoss-artifacts/ver.txt

RUN  rm $TOMCAT_HOME/webapps/Monolith/WEB-INF/lib/simba-athena-jdbc-driver* \
	&& rm $TOMCAT_HOME/webapps/Monolith/WEB-INF/lib/redshift-jdbc42* \
	&& rm $TOMCAT_HOME/webapps/Monolith/WEB-INF/lib/gremlin-shaded* \
	&& rm $TOMCAT_HOME/webapps/Monolith/WEB-INF/lib/neo4j-java-driver* \
	&& rm $TOMCAT_HOME/webapps/Monolith/WEB-INF/web.xml* \
	&& rm -r $TOMCAT_HOME/webapps/SemossWeb/playsheet
	
COPY terajdbc4.jar $TOMCAT_HOME/webapps/Monolith/WEB-INF/lib
COPY gremlin-shaded-3.4.1.jar $TOMCAT_HOME/webapps/Monolith/WEB-INF/lib
COPY neo4j-java-driver-1.7.5.jar $TOMCAT_HOME/webapps/Monolith/WEB-INF/lib
COPY web.xml $TOMCAT_HOME/webapps/Monolith/WEB-INF/web.xml
COPY server.xml $TOMCAT_HOME/conf/server.xml;

# RUN sed -i "s/HH:mm:ss}/HH:mm:ss,SSS}/g" log4j.prop /opt/semosshome/log4j.prop;

# Tomcat lof4j2 changes
# Make directories
RUN mkdir -pv $TOMCAT_HOME/log4j2/lib
RUN mkdir -pv $TOMCAT_HOME/log4j2/conf
# Move jars / configuration file
COPY log4j2/lib/log4j-* $TOMCAT_HOME/log4j2/lib/
COPY log4j2/conf/log4j2-* $TOMCAT_HOME/log4j2/conf/
# Modify setenv
RUN echo "CLASSPATH=\"$TOMCAT_HOME/log4j2/lib/*:$TOMCAT_HOME/log4j2/conf\"" >> $TOMCAT_HOME/bin/setenv.sh
# Delete old configuration file
RUN rm $TOMCAT_HOME/conf/logging.properties

# Final change to chmod before switching to non-root user
RUN chmod -R 777 /opt
RUN chmod -R 777 /usr/bin/rclone
RUN chmod -R 777 /usr/lib/jvm/zulu8.44.0.13-ca-fx-jdk8.0.242-linux_x64/jre/lib/security

USER 1001

WORKDIR /opt/semoss-artifacts/artifacts/scripts

ENV PATH=$PATH:$TOMCAT_HOME/bin:/usr/bin

CMD ["/opt/apache-tomcat-9.0.37/bin/start.sh"]
