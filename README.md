EdgeOS-Failover_PBR
===================

Auto Failover including support for DHCP for use with Edge OS Policy Based Routing

Assumes you have setup your PBR according to this example:
http://wiki.ubnt.com/EdgeOS_PBR_WAN_Load_Balance_Config

If using DHCP addresses, you can set the next hop for each table that uses a DHCP WAN as anything... 
1.1.1.1, 2.2.2.2, 3.3.3.3 etc. Script will overwrite these entries upon launching. 

When setting variables, they should always be in the same order

EXAMPLE:
WANs are... DHCP STATIC STATIC DHCP

INTERFACE=(WAN1 WAN2 WAN3 WAN3)
USE_DHCP=(true false false true)
LOOKUP_TABLE=(1 2 3 4)
TRAFFIC_MARK=(0x1 0x2 0x3 0x4)

Still a work in progress...
