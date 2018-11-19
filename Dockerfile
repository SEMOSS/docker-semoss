FROM tbanach/docker-r

LABEL maintainer="semoss@semoss.org"

ENV PATH=$PATH:/opt/semoss-artifacts/artifacts/scripts
ENV LD_LIBRARY_PATH=/usr/lib:/usr/local/lib/R/site-library/rJava/jri
ENV R_HOME=/usr/lib/R

# Create semosshome
# Clone semoss-artifacts scripts
# Update latest dev code
# Install Rclone
# Install Chrome
RUN apt-get update \
	&& mkdir /opt/semosshome \
	&& cd /opt && git clone https://github.com/SEMOSS/semoss-artifacts \
	&& chmod 777 /opt/semoss-artifacts/artifacts/scripts/*.sh \
	&& apt-get install -y curl \
	&& /opt/semoss-artifacts/artifacts/scripts/update_latest_dev.sh \
	&& apt-get install -y fuse \
	&& apt-get install -y man-db \
	&& curl https://rclone.org/install.sh | bash \
	&& wget -q -O - https://dl.google.com/linux/linux_signing_key.pub | apt-key add - \
	&& echo "deb http://dl.google.com/linux/chrome/deb/ stable main" | tee /etc/apt/sources.list.d/google-chrome.list \
	&& apt-get update \
	&& apt-get install -y google-chrome-stable \
	&& chmod 777 /opt/semosshome/config/Chromedriver/* 

WORKDIR /opt/semoss-artifacts/artifacts/scripts

CMD ["start.sh"]