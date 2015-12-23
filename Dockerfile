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

ADD     ./supervisor/rsyslog.conf /etc/supervisor/conf.d/rsyslog.conf
#       Preparation-----------------------------------------------------------
RUN     mkdir -p /opt/hm && mkdir -p /root/temp 
WORKDIR /root/temp

#       Download and unpack occu----------------------------------------------
RUN     wget -O occu.zip https://github.com/eq-3/occu/archive/master.zip ; unzip -q occu.zip; rm occu.zip
WORKDIR /root/temp/occu-master/arm-gnueabihf

#       Copy file to /opt/hm---------------------------------------------------
RUN     ./install.sh
WORKDIR /root/temp/occu-master
RUN     ln -s /opt/hm/etc/config /usr/local/etc && ln -s /opt/hm/etc/config /etc
RUN     cp -a firmware /opt/hm && ln -s /opt/hm/firmware /etc/config/firmware
RUN     cp -a HMserver/etc/config_templates/log4j.xml /opt/hm/etc/config && cp -a HMserver/opt/HMServer /opt

#       Configure rfd----------------------------------------------------------
ADD     ./config/rfd.conf /etc/config/rfd.conf
ADD     ./init.d/rfd /etc/init.d/rfd
RUN     chmod +x /etc/init.d/rfd && update-rc.d rfd defaults
ADD     ./supervisor/gpio_init.conf /etc/supervisor/conf.d/gpio_init.conf
ADD     ./supervisor/rfd.conf /etc/supervisor/conf.d/rfd.conf

ENV     HM_HOME=/opt/hm
ENV     LD_LIBRARY_PATH=$HM_HOME/lib

#       lighttpd--------------------------------------------------------------
ADD     ./init.d/lighttpd /etc/init.d/lighttpd
RUN     chmod +x /etc/init.d/lighttpd && update-rc.d lighttpd defaults
ADD     ./supervisor/lighttpd.conf /etc/supervisor/conf.d/lighttpd.conf

#       ReGaHss---------------------------------------------------------------
WORKDIR /root/temp/occu-master/WebUI
RUN     cp -a bin www /opt/hm
ADD     ./hm_config/syslog /opt/hm/etc/config/syslog
ADD     ./hm_config/netconfig /opt/hm/etc/config/netconfig
ADD     ./hm_config/TZ /opt/hm/etc/config/TZ
ADD     ./boot/VERSION /boot/VERSION
RUN     ln -s /opt/hm/www /www
ADD     ./supervisor/rega.conf /etc/supervisor/conf.d/rega.conf

#       HMServer--------------------------------------------------------------
ADD     ./supervisor/HMServer.conf /etc/supervisor/conf.d/HMServer.conf

RUN     sed -i 's/catch {exec killall syslogd}/#catch {exec killall syslogd}/g' /opt/hm/www/config/cp_maintenance.cgi
RUN     sed -i 's/catch {exec killall klogd}/#catch {exec killall klogd}/g' /opt/hm/www/config/cp_maintenance.cgi
RUN     sed -i 's/exec \/etc\/init.d\/S01logging start/exec \/etc\/init.d\/rsyslog restart/g' /opt/hm/www/config/cp_maintenance.cgi 

ADD     ./bin/firmware_update.sh /opt/hm/bin/firmware_update.sh
ADD     ./bin/crypttool /bin/crypttool
RUN     chmod +x /bin/crypttool

#       move back to /root----------------------------------------------------
WORKDIR /root
#       cleanup a bit---------------------------------------------------------
RUN     apt-get clean && apt-get purge

