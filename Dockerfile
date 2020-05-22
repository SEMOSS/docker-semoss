FROM semoss/docker-r-python:R3.6.2-debian10

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
RUN apt-get update -y \
	&& apt-get install -y curl \
	&& apt-get install -y lsof \
	&& wget https://downloads.rclone.org/v1.47.0/rclone-v1.47.0-linux-amd64.deb \
	&& dpkg -i rclone-v1.47.0-linux-amd64.deb \
	&& apt-get install -f \
	&& rm rclone-v1.47.0-linux-amd64.deb \
	&& mkdir /opt/semosshome \
	&& cd /opt && git clone https://github.com/SEMOSS/semoss-artifacts \
	&& chmod 777 /opt/semoss-artifacts/artifacts/scripts/*.sh \
	&& /opt/semoss-artifacts/artifacts/scripts/update_latest_dev.sh \
	&& wget -q -O - https://dl.google.com/linux/linux_signing_key.pub | apt-key add - \
	&& echo "deb http://dl.google.com/linux/chrome/deb/ stable main" | tee /etc/apt/sources.list.d/google-chrome.list \
	&& apt-get update \
	&& apt-get install -y google-chrome-stable \
	&& chmod 777 /opt/semosshome/config/Chromedriver/* \
	&& echo "export LD_PRELOAD=/usr/lib/python3.7/config-3.7m-x86_64-linux-gnu/libpython3.7.so" >> $TOMCAT_HOME/bin/setenv.sh \
	&& cp /usr/lib/jvm/zulu8.44.0.13-ca-fx-jdk8.0.242-linux_x64/lib/tools.jar $TOMCAT_HOME/lib

WORKDIR /opt/semoss-artifacts/artifacts/scripts

CMD ["start.sh"]
