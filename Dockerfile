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
        cron \
        man \
        sendmail \
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
RUN     sed -i "s|#server.errorlog-use-syslog|server.errorlog-use-syslog|g" $HM_HOME/etc/lighttpd/lighttpd.conf

#       ReGaHss---------------------------------------------------------------
WORKDIR /root/temp/occu-${OCCU_VERSION}/WebUI
RUN     cp -a bin www /opt/hm
ADD     ./hm_config/syslog /opt/hm/etc/config/syslog
ADD     ./hm_config/netconfig /opt/hm/etc/config/netconfig
ADD     ./hm_config/TZ /opt/hm/etc/config/TZ
RUN     echo "VERSION=${OCCU_VERSION}" > /boot/VERSION
RUN     ln -s /opt/hm/www /www
RUN     systemctl enable regahss

## Allow restart of rsyslog
RUN     sed -i "s|catch {exec killall syslogd}|#catch {exec killall syslogd}|g" /opt/hm/www/config/cp_maintenance.cgi 
RUN     sed -i "s|catch {exec killall klogd}|#catch {exec killall klogd}|g" /opt/hm/www/config/cp_maintenance.cgi 
RUN     sed -i "s|exec /etc/init.d/S01logging start|exec systemctl restart rsyslog|g" /opt/hm/www/config/cp_maintenance.cgi 

#       HMServer--------------------------------------------------------------
WORKDIR /root/temp/occu-${OCCU_VERSION}/HMserver
RUN     echo "#!/bin/sh\n### BEGIN INIT INFO\n# Provides:          HMserver\n# Required-Start:    \$network \$remote_fs \$syslog\n# Required-Stop:     \$network \$remote_fs \$syslog\n# Default-Start:     2 3 4 5\n# Default-Stop:      0 1 6\n# Short-Description: HomeMatic HMserver service\n# Description:       HomeMatic HMserver service\n### END INIT INFO\n" "$(tail -n +5 ./etc/init.d)" > /etc/init.d/HMserver
RUN     chmod +x /etc/init.d/HMserver
RUN     sed -i "s|java|${JAVA_HOME}/bin/java|g" /etc/init.d/HMserver
RUN     systemctl enable HMserver

#       Modifications for backup,restore and add-on installation--------------
ADD     ./bin /bin
RUN     chmod +x  /bin/crypttool /bin/firmware_update.sh
RUN     sed -i "s|exec /bin/kill -SIGQUIT 1|#exec /bin/kill -SIGQUIT 1\n        # OCCU: Erst noch die homematic.regadom sichern\n        rega system.Save()\n        # OCCU: Then execute firmware update script\n        exec /opt/hm/bin/firmware_update.sh|g" /opt/hm/www/config/cp_software.cgi
RUN     sed -i "s|exec umount /usr/local|#exec umount /usr/local|g"  /opt/hm/www/config/cp_security.cgi && \
sed -i "s|exec /usr/sbin/ubidetach -p /dev/mtd6|#exec /usr/sbin/ubidetach -p /dev/mtd6|g"  /opt/hm/www/config/cp_security.cgi && \
sed -i "s|exec /usr/sbin/ubiformat /dev/mtd6 -y|#exec /usr/sbin/ubiformat /dev/mtd6 -y|g"  /opt/hm/www/config/cp_security.cgi && \
sed -i "s|exec /usr/sbin/ubiattach -p /dev/mtd6|#exec /usr/sbin/ubiattach -p /dev/mtd6|g"  /opt/hm/www/config/cp_security.cgi && \
sed -i "s|exec /usr/sbin/ubimkvol /dev/ubi1 -N user -m|#exec /usr/sbin/ubimkvol /dev/ubi1 -N user -m|g"  /opt/hm/www/config/cp_security.cgi && \
sed -i "s|exec mount /usr/local|#exec mount /usr/local|g"  /opt/hm/www/config/cp_security.cgi
RUN     touch /var/ids

#       Simulate sd-card------------------------------------------------------
RUN     mkdir -p /media/sd-mmcblk0/measurement && \
        mkdir -p /opt/HMServer/measurement && \
        mkdir -p /etc/config/measurement && \
        mkdir -p /var/status && \
        touch /var/status/hasSD && \
        touch /var/status/SDinitialised && \
        touch /media/sd-mmcblk0/.initialised



#       move back to /root----------------------------------------------------
WORKDIR /root
#       cleanup a bit---------------------------------------------------------
RUN     apt-get clean && apt-get purge

