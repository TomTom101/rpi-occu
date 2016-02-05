FROM 	marbon87/rpi-java
MAINTAINER Mark Bonnekessel <marbon@mailbox.org>

#       Install packages------------------------------------------------------
RUN 	apt-get update && apt-get install -y \
        msmtp \
        tcl \
        tcllib \
        libusb-1.0-0-dev \
        unzip \
        rsyslog \
        --no-install-recommends && \
        rm -rf /var/lib/apt/lists/*

#       Activate systemd
ENV     INITSYSTEM on

#       Preparation-----------------------------------------------------------
RUN     mkdir -p /opt/hm && mkdir -p /root/temp 
WORKDIR /root/temp

ENV     HM_HOME=/opt/hm
ENV     LD_LIBRARY_PATH=$HM_HOME/lib

#       Download and unpack occu----------------------------------------------
ENV     OCCU_VERSION 2.15.5
RUN     wget -O occu.zip https://github.com/eq-3/occu/archive/${OCCU_VERSION}.zip ; unzip -q occu.zip; rm occu.zip

#       Copy file to /opt/hm---------------------------------------------------
WORKDIR /root/temp/occu-${OCCU_VERSION}/arm-gnueabihf
RUN     ./install.sh
WORKDIR /root/temp/occu-${OCCU_VERSION}
RUN     ln -s /opt/hm/etc/config /usr/local/etc && ln -s /opt/hm/etc/config /etc
RUN     cp -a firmware /opt/hm && ln -s /opt/hm/firmware /etc/config/firmware
RUN     cp -a HMserver/etc/config_templates/log4j.xml /opt/hm/etc/config && cp -a HMserver/opt/HMServer /opt
RUN     cp -a scripts/debian/init.d/* /etc/init.d

#       Configure rfd----------------------------------------------------------
ADD     ./config/rfd.conf /etc/config/rfd.conf
RUN     systemctl enable rfd

#       lighttpd--------------------------------------------------------------
RUN     systemctl enable lighttpd

#       ReGaHss---------------------------------------------------------------
WORKDIR /root/temp/occu-${OCCU_VERSION}/WebUI
RUN     cp -a bin www /opt/hm
ADD     ./hm_config/syslog /opt/hm/etc/config/syslog
ADD     ./hm_config/netconfig /opt/hm/etc/config/netconfig
ADD     ./hm_config/TZ /opt/hm/etc/config/TZ
ADD     ./boot/VERSION /boot/VERSION
RUN     ln -s /opt/hm/www /www
RUN     systemctl enable regahss

#       HMServer--------------------------------------------------------------
# TODO: HMServer
WORKDIR /root/temp/occu-${OCCU_VERSION}/HMserver
ADD     ./init.d/HMserver /etc/init.d/HMserver
RUN     chmod +x /etc/init.d/HMserver
RUN     systemctl enable HMserver

#       move back to /root----------------------------------------------------
WORKDIR /root
#       cleanup a bit---------------------------------------------------------
RUN     apt-get clean && apt-get purge

