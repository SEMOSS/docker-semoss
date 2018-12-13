FROM semoss/docker-r-python

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
RUN apt-get update \
	&& apt-get install -y curl \
	&& apt-get install -y fuse \
	&& apt-get install -y man-db \
	&& curl https://rclone.org/install.sh | bash \
	&& mkdir /opt/semosshome \
	&& cd /opt && git clone https://github.com/SEMOSS/semoss-artifacts \
	&& chmod 777 /opt/semoss-artifacts/artifacts/scripts/*.sh \
	&& /opt/semoss-artifacts/artifacts/scripts/update_latest_prod.sh \
	&& wget -q -O - https://dl.google.com/linux/linux_signing_key.pub | apt-key add - \
	&& echo "deb http://dl.google.com/linux/chrome/deb/ stable main" | tee /etc/apt/sources.list.d/google-chrome.list \
	&& apt-get update \
	&& apt-get install -y google-chrome-stable \
	&& chmod 777 /opt/semosshome/config/Chromedriver/* \
	&& echo "export LD_PRELOAD=/usr/lib/python2.7/config-x86_64-linux-gnu/libpython2.7.so" >> /opt/apache-tomcat-8.0.41/bin/setenv.sh

WORKDIR /opt/semoss-artifacts/artifacts/scripts

CMD ["start.sh"]
