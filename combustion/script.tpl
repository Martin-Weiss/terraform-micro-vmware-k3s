#!/bin/bash
## disabled "network" in combustion due to race condition "igition" vs "combustion" vs "static network"
# c#ombustion: network
echo ${servername} > /root/combustion-was-here

# this does not work from combustion as combustion is in chroot, already - and this needs network activated which is a race condition problem as well.
# so moving this to terraform for the moment
#curl -Sks  https://susemanager.weiss.ddnss.de/pub/bootstrap/bootstrap.sh | sed 's/^ACTIVATION_KEYS=.*/ACTIVATION_KEYS=1-k3s-micro-55/g' | sed 's/^ORG_CA_CERT=.*/ORG_CA_CERT=RHN-ORG-TRUSTED-SSL-CERT/g' | sed 's/^ORG_CA_CERT_IS_RPM_YN=.*/ORG_CA_CERT_IS_RPM_YN=0/g' |bash
#systemctl reboot
