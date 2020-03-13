FROM semoss/docker-r-python:user

LABEL maintainer="semoss@semoss.org"

ENV LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/home/semoss/R/x86_64-pc-linux-gnu-library/3.5/rJava/jri
ENV R_HOME=/usr/lib/R
ENV SEMOSS_BASE=/home/semoss
#ENV PATH=$PATH:$SEMOSS_BASE/semoss-artifacts/artifacts/scripts

# Install Rclone
# Create semosshome
# Clone semoss-artifacts scripts
# Update latest dev code
# Install Chrome
# Set LD_PRELOAD on Tomcat
RUN sudo apt-get update \
	&& sudo apt-get install -y curl \
	&& sudo apt-get install -y lsof \
	&& cd $SEMOSS_BASE \
	&& wget https://downloads.rclone.org/v1.45/rclone-v1.45-linux-amd64.deb \
	&& sudo dpkg -i rclone-v1.45-linux-amd64.deb \
	&& sudo apt-get install -f \
	&& rm rclone-v1.45-linux-amd64.deb \
	&& mkdir $SEMOSS_BASE/semosshome \
	&& cd $SEMOSS_BASE && git clone https://github.com/SEMOSS/semoss-artifacts \
	&& cd semoss-artifacts \ 
	&& git checkout sudoless \
	&& cd $SEMOSS_BASE \
	&& chmod 777 $SEMOSS_BASE/semoss-artifacts/artifacts/scripts/*.sh \
	&& $SEMOSS_BASE/semoss-artifacts/artifacts/scripts/update_latest_dev.sh \
	#&& wget -q -O - https://dl.google.com/linux/linux_signing_key.pub | apt-key add - \
	#&& echo "deb http://dl.google.com/linux/chrome/deb/ stable main" | tee /etc/apt/sources.list.d/google-chrome.list \
	#&& apt-get update \
	#&& apt-get install -y google-chrome-stable \
	#&& chmod 777 /opt/semosshome/config/Chromedriver/* \
	&& echo "export LD_PRELOAD=/usr/lib/python3.5/config-3.5m-x86_64-linux-gnu/libpython3.5.so" >> $TOMCAT_HOME/bin/setenv.sh \
	&& cp /usr/lib/jvm/java-8-openjdk-amd64/lib/tools.jar $TOMCAT_HOME/lib

# RUN sudo sed -i '$ d' /etc/sudoers

WORKDIR /home/semoss

CMD ["start.sh"]
