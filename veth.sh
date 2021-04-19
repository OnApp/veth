#!/bin/bash
function ConfigureBackupNetwork {
read -p "Are your Compute Resource(s) and Backup Server(s) on the same Network/VLAN? (yes/no)" same_net
if [[ $same_net == "yes" ]]; then
  read -p "Do you want to configure a Local Backup/Provisioning network? (yes/no)" backup_net
  if [[ $backup_net == "yes" ]]; then
    read -p "Which private IP do you want to use for this server?" backup_ip
    ipcalc -cs $backup_ip || { echo "Please try again with a valid IP"; exit $ERRCODE; }
    read -p "Which Netmask do you want to use? (For example 255.255.255.0)" backup_netmask
    ipcalc -cs $backup_netmask || { echo "Please try again with a valid Netmask"; exit $ERRCODE; }
echo -e "DEVICE=onappBridge:1
ONBOOT=yes
NM_CONTROLLED=no
BOOTPROTO=static
IPADDR=$backup_ip
NETMASK=$backup_netmask" > ifcfg-onappBridge:1
  fi
fi
}


#Check if onappBridge is not active
if  [[ $(cat /sys/class/net/onappBridge/operstate) == up ]]; then
echo "Network is already configured, onappBridge is up"
ConfigureBackupNetwork
exit 2
fi

#Install dependency
yum install bridge-utils net-tools arptables -y

#Get default variables
ip=$(ip route get 8.8.8.8 | head -1 | awk '{print $7}')
echo default_ip $ip
default_if=$(ip route list | awk '/^default/ {print $5}')
echo default_if $default_if
default_route=$(ip route list | awk '/^default/ {print $3}')
echo default_route $default_route
default_netmask=$(ifconfig $default_if | grep netmask | awk  '{print $4}')
echo default_netmask $default_netmask
default_mac=$(cat /sys/class/net/$default_if/address)

#Generate ifup-veth
cd /etc/sysconfig/network-scripts
echo -e '. /etc/init.d/functions
cd /etc/sysconfig/network-scripts
. ./network-functions
[ -f ../network ] && . ../network
CONFIG=${1}
need_config ${CONFIG}
source_config
OTHERSCRIPT="/etc/sysconfig/network-scripts/ifup-${REAL_DEVICETYPE}"

if [ ! -x ${OTHERSCRIPT} ]; then
        OTHERSCRIPT="/etc/sysconfig/network-scripts/ifup-eth"
fi

ip link add ${DEVICE} \
        type ${TYPE:-veth} peer name ${VETH_PEER}

${OTHERSCRIPT} ${CONFIG}
ifconfig ${VETH_PEER} up' >  ifup-veth

chmod +x ifup-veth

echo -e "Generating onappBridge config file\n"
if [[ $1 == "MAC" ]]; then
echo -e "DEVICE=onappBridge
DEVICETYPE=Bridge
ONBOOT=yes
NM_CONTROLLED=no
HWADDR=$default_mac
BOOTPROTO=static
IPADDR=$ip
NETMASK=$default_netmask
GATEWAY=$default_route" > ifcfg-onappBridge
else
echo -e "DEVICE=onappBridge
DEVICETYPE=Bridge
ONBOOT=yes
NM_CONTROLLED=no
#HWADDR=$default_mac
BOOTPROTO=static
IPADDR=$ip
NETMASK=$default_netmask
GATEWAY=$default_route" > ifcfg-onappBridge
fi

echo -e "Generating ethManagement Network config file \n"
echo -e "DEVICE=ethManagement
DEVICETYPE=veth
VETH_PEER=ethAppliance
BRIDGE=onappBridge
ONBOOT=yes
NM_CONTROLLED=no" > ifcfg-ethManagement

echo -e "Generating ethAppliance Network config file\n"
echo -e "DEVICE=ethAppliance
DEVICETYPE=veth
VETH_PEER=ethManagement
ONBOOT=yes
NM_CONTROLLED=no" > ifcfg-ethAppliance


cp ifcfg-$default_if ifcfg-$default_if.orig
echo -e "Generating $default_if  Network config file\n"
echo -e "DEVICE=$default_if
TYPE=Ethernet
HWADDR=$default_mac
BOOTPROTO=none
ONBOOT=yes
BRIDGE=onappBridge
NM_CONTROLLED=no" > ifcfg-$default_if

sed -i --follow-symlinks 's/^GATEWAY.*//g' /etc/sysconfig/network

ConfigureBackupNetwork

echo "Restarting network"
service network restart

if [[ $1 == "MAC" ]]; then
echo -e "arptables -I FORWARD -i $default_if -j ACCEPT
arptables -I FORWARD -i ethManagement   -j ACCEPT
iptables -I FORWARD -p all -i onappBridge -j ACCEPT
sysctl -w net.ipv4.conf.all.forwarding=1" > /opt/PrepareOnappNetwork.sh
else 
echo -e "arptables -I FORWARD -i $default_if -j ACCEPT
arptables -I FORWARD -i ethManagement   -j ACCEPT
iptables -I FORWARD -p all -i onappBridge -j ACCEPT" > /opt/PrepareOnappNetwork.sh
fi


chmod +x /opt/PrepareOnappNetwork.sh
bash /opt/PrepareOnappNetwork.sh
echo "@reboot bash /opt/PrepareOnappNetwork.sh" > /etc/cron.d/PrepareOnappNetwork
