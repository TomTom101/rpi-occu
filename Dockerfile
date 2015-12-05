FROM 	marbon87/rpi-occu
MAINTAINER Mark Bonnekessel <marbon@mailbox.org>

#       Install packages------------------------------------------------------
RUN 	apt-get update && apt-get install -y \
        msmtp \
        tcl \
        tcllib \
        libusb-1.0-0-dev \
        unzip \
        --no-install-recommends && \
        rm -rf /var/lib/apt/lists/*

#       Preparation-----------------------------------------------------------
RUN     mkdir -p /opt/hm && mkdir -p /root/temp 
WORKDIR /root/temp

#       Download and unpack occu----------------------------------------------
RUN     wget -O occu.zip https://github.com/eq-3/occu/archive/master.zip ; unzip -q occu.zip; rm occu.zip
WORKDIR /root/temp/occu-master/arm-gnueabihf

#       Copy file to /opt/hm---------------------------------------------------
RUN     ./install.sh
RUN     ln -s /opt/hm/etc/config /etc/config

#       Configure rfd----------------------------------------------------------
ADD     ./rfd.conf /etc/config/rfd.conf
ENV     HM_HOME=/opt/hm
ENV     LD_LIBRARY=$HM_HOME/lib

#       cleanup a bit---------------------------------------------------------
RUN     apt-get clean && apt-get purge

