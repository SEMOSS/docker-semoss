FROM semoss/docker-r-python:R3.6.1-debian10.5-builder as base

FROM semoss/docker-tomcat:9.0.37 as mavenpuller

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
COPY --from=mavenpuller $TOMCAT_HOME/webapps/Monolith $TOMCAT_HOME/webapps/Monolith
COPY --from=mavenpuller $TOMCAT_HOME/webapps/SemossWeb $TOMCAT_HOME/webapps/SemossWeb
COPY --from=mavenpuller /opt/semoss-artifacts/ver.txt /opt/semoss-artifacts/ver.txt

RUN  rm $TOMCAT_HOME/webapps/Monolith/WEB-INF/lib/simba-athena-jdbc-driver* \
	&& rm $TOMCAT_HOME/webapps/Monolith/WEB-INF/lib/redshift-jdbc42* \
	&& rm $TOMCAT_HOME/webapps/Monolith/WEB-INF/lib/gremlin-shaded*
	
COPY terajdbc4.jar $TOMCAT_HOME/webapps/Monolith/WEB-INF/lib
COPY gremlin-shaded-3.4.1.jar $TOMCAT_HOME/webapps/Monolith/WEB-INF/lib

RUN chmod -R 777 /opt
RUN chmod -R 777 /usr/bin/rclone

USER 1001

WORKDIR /opt/semoss-artifacts/artifacts/scripts

ENV PATH=$PATH:$TOMCAT_HOME/bin:/usr/bin

CMD ["/opt/apache-tomcat-9.0.37/bin/start.sh"]
