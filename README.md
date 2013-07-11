EdgeOS WAN Failover / PBR / DHCP Support
===================

*This software is meant only for use with Ubiquiti's EdgeMax Router (EdgeOS).*

This script will work with version 1.2.0 of EdgeOS.

This article is a guide for setting up automatic WAN failover while using Edgemax's built in Policy Based Router / Load Balancing ( per-connection load balancing using connection marking and probabilistic matching). This feature has been available since version 1.2.0. I was not thrilled with the way gwping.sh was working and the lack of support for a lot of features that people seemed to need so I wrote this script which can be found on github. It's also open source so if you are a developer and would like to help out, that would be great! I am new to bash programming and I sure there are things that could have been done better.
 
**Please keep in mind, this script will make changes to your edgemax configuration while it is running. It will commit these changes but it will NOT save them. If you are running this script and need to make changes, I recommend you end the script process (run top, find the pid and type kill pid#here). Discard the changes or reboot your router (disable script startup) before you change / save your config. Otherwise any changes made by the script will be saved to your config**!
 
 With this script you can use Static WANs, DHCP WANs, or any combination of the two. You can even use several WANs. If you decide you are going to use DHCP WANs, you can set the `next-hop` to anything for that interface (IE: `1.1.1.1 / 2.2.2.2 / 3.3.3.3` etc), the script will overwrite these settings. 
 
**Step 1:** Follow this guide - [http://wiki.ubnt.com/EdgeOS_PBR_WAN_Load_Balance](http://wiki.ubnt.com/EdgeOS_PBR_WAN_Load_Balance "EdgeOS PBR Load Balancing")

*Remember to set `next-hop` for DHCP WANs as per above. For ease of use you should also keep things simple - `WAN1 = Table 1 = Mark 1`, `WAN2 = Table 2 = Mark 2`,  etc.*
 
**Step 2:** Once you have setup your configuration for PBR Load Balancing, save and reboot your router. At the very least make sure to commit and save your configuration changes. The script will change these settings if you are using DHCP but it will not save, so it's good to have a baseline configuation!
 
**Step 3:** Download the script: [https://github.com/jivetek/EdgeOS-Failover_PBR](https://github.com/jivetek/EdgeOS-Failover_PBR "EdgeOS-Failover_PBR")

Place the file `EdgeOS_Failover_PBR.sh` in your `/config/scripts` directory. *(`wget` makes this easy)*

    SSH into your router
    sudo su
    cd /config/scripts
    wget https://raw.github.com/jivetek/EdgeOS-Failover_PBR/master/EdgeOS_Failover_PBR.sh
 

**Step 4:** chmod to 755 

`chmod 755 EdgeOS_Failover_PBR.sh`

**Step 5:** Configure variables for your environment

    
    vi EdgeOS_Failover_PBR.sh
    press "i" for insert mode
    change variables to match your environment (below)
    save your changes (esc, "shift+:" x, enter)


**Step 6:** run the script and test! `./EdgeOS_Failover_PBR.sh`  `(Ctrl+C) ` to exit. 
 
***Interface Variables***
 
**Set** ` INTERFACE=(eth1.500 eth2.600) `to match the interfaces of your WAN's in order, each WAN should be separated by a space. Do no remove the (). 

**Set** `TRAFFIC_MARK=(0x1 0x2)` to the mark that applies to each interface. Make sure this is in the same order as the interfaces or who knows what sort of chaos you will cause!

**Set** `LOOKUP_TABLE=(1 2)` to the tables that apply to each interfaces. Again, this needs to be in the same order as your interfaces!

**Set** `USING_DHCP` to true or false. If you are using DHCP on ANY of your interfaces, set this to true

**Set** `USE_DHCP=(true true)` to match your interfaces. If your interfaces are 
`WAN1-Static WAN2-DHCP WAN3-DHCP` then it would be `USE_DHCP=(false true true)`. *Again, make sure these are in the same order as your interfaces! Notice a trend here?*

**Set** `DHCP_CHECK=30` to how often in seconds you want the script to see if there are new DHCP addresses. *I like 30 seconds as the script will mark a connection as down if the address changes and will re-route traffic. 30 seconds won't kill the processing on the router.*

***Ping Check Variables***
 
**Set** `TEST_ADDRESS=8.8.8.8` to an external address you want to ping to make sure your connection is working. This address should be always available. 8.8.8.8 is Googles public DNS, I can't think of many things with higher availability than Google. This should also probably not be a DNS address, try to keep it to an IP address

**Set** `TIMEOUT=1` to the ping timeout, this really probably doesn't need to be changed but if you have a shoddy connection, you could increase this number. 

**Set** `FAILURE=2` to the number of pings lost in a row that you consider your network down. *I recommend 3-4.*

**Set** `SUCCESS=2` to the number of successful pings in a row that you consider your network up. 

**Set** `PING_TIMER=3` to the number of seconds you would like to wait before pinging through all of your interfaces again. 

***Message output variables***

`MESSAGE=true/false` turns on some general program messages, if you want to see how long it is taking to startup, what version you are running, how to contact the author, etc. Turn this on

`CHANGES=true/false` when this is turned on, you will get output in a log file every time the script detects a network change, makes a network change, or changes routes, etc. *I recommend leaving this on.*

`DEBUG=true/false` turns debug messages on and off this will fill up your log and is mostly only their for development,* it's off by default and I recommend leaving it that way*

`DHCP_DEBUG/PING_DEBUG` are not implemented at this time, I plan to separate debug messages in the future to make development easier. 
 
**Step 7:** Set script to auto run in the background at startup. 

  ssh into router

    sudo su
    cd /config/scripts/post-config.d
    vi launch.sh
    press "i" for insert mode

     #!/bin/sh -e
    	#enter startup commands below
    	#Start Edge Failover / Load Balancing Script
    	nohup /config/scripts/EdgeOS_Failover_PBR.sh &> /var/log/EdgeOS_Failover.log &
    	exit 0

    save script (esc, "shift + :", x)
    chmod 755 launch.sh
  
That's it! The script should now run on startup and output it's data to `/var/log/EdgeOS_Failover.log` ( you can change this location in step 7)
