#!/bin/bash
# Adopted from LXCCU-Project file /bin/update_firmware.run

log() {
  logger -t homematic -p user.notice $1
}

#echo "OCCU: Entering addon install mode"
log "OCCU: Entering addon install mode"
if [ ! -f /var/new_firmware.tar.gz ]; then
  log "OCCU: addon image archive does not exist. Nothing to do"
  #echo "OCCU: addon image archive does not exist. Nothing to do"
  exit
fi

#echo "OCCU: extract addon archive"
log "OCCU: extract addon archive"
cd /var
cat new_firmware.tar.gz | gunzip | tar x
rm new_firmware.tar.gz
if [ ! -x /var/update_script ]; then
  log "OCCU: Error unzipping addon image archive. Nothing to do"
  #echo "OCCU: Error unzipping addon image archive. Nothing to do"
  exit
fi

log "OCCU: prepare mount points to simulate ccu"
#echo "OCCU: prepare mount points to simulate ccu"
cat /var/update_script | sed -r 's/mount -t ubifs ubi0:root ([\/\w\-]*)/mount -o bind \/ \1/' > /var/update_script_prepare
cat /var/update_script_prepare | sed -r 's/mount -t ubifs ubi1:user ([\/\w\-]*)/mount -o bind \/usr\/local \1/' > /var/update_script

log "OCCU: start update_script as OCCU"
#echo "OCCU: start update_script as OCCU"
chmod +x /var/update_script
cd /var/
/var/update_script CCU2

# Fallback
/sbin/reboot
