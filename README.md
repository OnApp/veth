The veth.sh tool is designed to reconfigure Compute Resources or Backup Servers networking for use with OnApp over a single NIC.

It creates VETH (Virtual Ethernet) devices. They are created in pairs: "ethAppliance" and "ethManagement"
The first Virtual Interface is attached to the Appliance bridge (for Virtual Server networking)
The second is attached to bridge with the physical NIC

The Public IP is configured on the bridge interface named "OnAppBridge"
Run this script with argument MAC, if persistant MAC address is required for onappBridge interface, this may be required in providers who block traffic coming from a MAC which differs from the servers primary interface. Example: bash veth.sh MAC
Hardware address of physical interface will be set into onappBridge persistant config.

A copy of the initial configuration for the physical NIC is backed up, for example a backup file for a eth0 interface would be found at /etc/sysconfig/network-scripts/ifcfg-eth0.orig.

If the Compute Resources and Backup Servers are attached to the same physical Network/VLAN, a new network alias can be added which can be utilised for the Provisioning network to keep traffic flowing locally where possible. That interface will be configured as ifcfg-OnAppBridge:1.

This tool does not touch the network configuration files if OnAppBridge is already up on the host when it is run, although it does still allow to change IP Address or Netmask for ifcfg-OnAppBridge:1

To undo the changes made by this tool, you can perform the following actions (in this example the primary interface is enp1s0):
mv /etc/sysconfig/network-scripts/ifcfg-enp1s0.orig /etc/sysconfig/network-scripts/ifcfg-enp1s0
rm /etc/sysconfig/network-scripts/ifcfg-ethAppliance
rm /etc/sysconfig/network-scripts/ifcfg-ethManagement
rm /etc/sysconfig/network-scripts/ifcfg-onappBridge
rm /etc/sysconfig/network-scripts/ifcfg-onappBridge:1
rm /etc/cron.d/PrepareOnappNetwork

Thanks go to https://github.com/larsks and https://github.com/jbessaguet for the inspiration and foundations of this tool found at https://github.com/jbessaguet/initscripts-veth
