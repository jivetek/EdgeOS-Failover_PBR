#!/bin/vbash
source /opt/vyatta/etc/functions/script-template
run=/opt/vyatta/bin/vyatta-op-cmd-wrapper
##############################CONFIGURATION VARIABLES###############################

####################
#INTERFACE SETTINGS
#IF1 IF2 IF3 IF4 etc
####################
INTERFACE=(eth1.500 eth2.600)

###################
#MARK TO CHANGE FOR EACH INTERFACE
###################
TRAFFIC_MARK=(0x1 0x2)

###################
#LOOKUP TABLE FOR EACH INTERFACE
###################
LOOKUP_TABLE=(1 2)

####################
#USE DHCP ON AN INTERFACE
####################
USING_DHCP=true

####################
#DHCP FOR EACH INTERFACE
#IF USING_DHCP=false - THIS DOESNT MATTER
#true/false FOR EACH INTERFACE 
####################
USE_DHCP=(true true)

####################
#MINIMUM TIME TO CHECK DHCP (also affected by ping wait)
####################
DHCP_CHECK=30

####################
#IP ADDRESS TO PING
####################
TEST_ADDRESS=8.8.8.8

####################
#PING TIMEOUT WAIT TIME
####################
TIMEOUT=1

####################C
#CONSECUTIVE FAILURES BEFORE CONSIDERED DOWN
####################
FAILURE=3

####################
#CONSECUTIVE SUCCESS BEFORE CONSIDERED UP
####################
SUCCESS=3

####################
#MINIMUM TIME TO WAIT BETWEEN PINGS (also affected by dhcp wait)
####################
PING_TIMER=5

####################
#DISPLAY CHANGE MESSAGES
####################
CHANGES=true

####################
#DISPLAY INFO MESSAGE
####################
MESSAGE=true

####################
#DEBUG true/false
####################
DEBUG=true

##############################DO NOT EDIT BELOW#####################################
##############################NON CONFIGURABLE VARIABLES############################
###
declare -A CURRENT_SUCCESS
declare -A CURRENT_FAILURE
declare -A CURRENT_STATUS
declare -A CHANGED_ROUTE
declare -A INTERFACE_TABLE
declare -A INTERFACE_MARK
declare -A GW_ADDRESS
declare -A GW_CURRENT
declare -A DHCP_LIST
declare -A INITIALIZED_INTERFACES
declare -A IP_ADDRESS
INTERFACES=
GATEWAY=
INITIALIZING=true
ALL_ROUTES_DOWN=false
version=0.1
##############################DHCP / GATEWAY FUNCTIONS##############################
###
do_gateway_check(){
	get_all_gateways
	set_all_gateways
}
###
get_all_gateways(){
	if [ $USING_DHCP = true ]; then
		all_dhcp_leases=$($run show dhcp client leases)
		all_dhcp_leases+=$'\n'	
		x=0
		unset data
		while read -r line
		do
			if [ -z "$line" ]; then
				dhcp_lease_array[$x]="$data"
				unset data
				let x++                
			else
				data+=$'\n'
				data+=$line
			fi
		done <<< "$all_dhcp_leases"
		
		for(( i = 0; i < $INTERFACES; i++ )); do
			key=${INTERFACE[$i]}
			if [ ${DHCP_LIST[$key]} = true ]; then
				for j in "${dhcp_lease_array[@]}"
				do
					current_dhcp_interface=$(echo "$j" | grep interface | sed 's/.*interface  : \(.*\)/\1/')		
					current_dhcp_gateway=$(echo "$j" | grep router | grep -o [0-9].*)
					current_ip_address=$(echo "$j" | grep address | grep -o [0-9].* | cut -f1 -d"	")
					if [ $current_dhcp_interface = $key ]; then
						if [[ ! -z $current_dhcp_interface && ! -z $current_dhcp_gateway ]]; then
							GW_ADDRESS[$key]=$current_dhcp_gateway
							IP_ADDRESS[$key]=$current_ip_address
						fi
					fi
				done
			else
				if [ $INITIALIZING = true ]; then			
					GATEWAY=$(ip route show default | awk "/dev $key weight/ {print \$3}")
					if [ ! -z "$GATEWAY" ]; then		
						GW_ADDRESS[$key]=$GATEWAY
					else
						change_message "ERROR: $key using STATIC IP has no GATEWAY set"
						change_message "exiting"
						exit
					fi	
				fi		
			fi	
		done
	fi
}

###
set_all_gateways(){	
	if [ $USING_DHCP = true ]; then
		MAKE_CHANGES=false
		for(( i = 0; i < $INTERFACES; i++ )); do
			key=${INTERFACE[$i]}
			if [ ! ${GW_ADDRESS[$key]} = 0 ]; then
				if [ "${GW_ADDRESS[$key]}" != "${GW_CURRENT[$key]}" ]; then
					MAKE_CHANGES=true
					break
				fi
			fi
		done
		
		if [ $MAKE_CHANGES = true ]; then
			configure
			edit protocols
			if [ $INITIALIZING = true ]; then
				change_message "INITIALIZING: DELETE static route 0.0.0.0/0 next-hop"
				delete static route 0.0.0.0/0 next-hop
			fi
			for(( i = 0; i < $INTERFACES; i++ )); do
				key=${INTERFACE[$i]}
				CURRENT_TABLE=${INTERFACE_TABLE[$key]}
				if [ ! ${GW_ADDRESS[$key]} = 0 ]; then
					if [ ${GW_CURRENT[$key]} = 0 ]; then
						GW_CURRENT[$key]=${GW_ADDRESS[$key]}
						if [ ${DHCP_LIST[$key]} = true ]; then
							if [ $INITIALIZING = true ]; then
								change_message "INITIALIZING: SET static route 0.0.0.0/0 next-hop ${GW_ADDRESS[$key]}"
								set static route 0.0.0.0/0 next-hop ${GW_ADDRESS[$key]}
								change_message "INITIALIZING: DELETE static table $CURRENT_TABLE route 0.0.0.0/0 next-hop"
								delete static table $CURRENT_TABLE route 0.0.0.0/0 next-hop
								change_message "INITIALIZING: SET static table $CURRENT_TABLE route 0.0.0.0/0 next-hop ${GW_ADDRESS[$key]}"
								set static table $CURRENT_TABLE route 0.0.0.0/0 next-hop ${GW_ADDRESS[$key]}
							else
								change_message "GATEWAY CHANGE: SET static route $CURRENT_TABLE route 0.0.0.0/0 next-hop"							
								set static route 0.0.0.0/0 next-hop ${GW_ADDRESS[$key]}
								change_message "GATEWAY CHANGE: DELETE static table $CURRENT_TABLE route 0.0.0.0/0 next-hop"
								delete static table $CURRENT_TABLE route 0.0.0.0/0 next-hop
								change_message "GATEWAY CHANGE: SET static table $CURRENT_TABLE route 0.0.0.0/0 next-hop ${GW_ADDRESS[$key]}"
								set static table $CURRENT_TABLE route 0.0.0.0/0 next-hop ${GW_ADDRESS[$key]}								
							fi
						fi
					else
						if [ $INITIALIZING = true ]; then
								change_message "INITIALIZING: SET static route 0.0.0.0/0 next-hop ${GW_ADDRESS[$key]}"
								set static route 0.0.0.0/0 next-hop ${GW_ADDRESS[$key]}						
								change_message "INITIALIZING: DELETE static table $CURRENT_TABLE route 0.0.0.0/0 next-hop ${GW_CURRENT[$key]}"
								delete static table $CURRENT_TABLE route 0.0.0.0/0 next-hop ${GW_CURRENT[$key]}
								change_message "INITIALIZING: SET static table $CURRENT_TABLE route 0.0.0.0/0 next-hop ${GW_ADDRESS[$key]}"
								set static table $CURRENT_TABLE route 0.0.0.0/0 next-hop ${GW_ADDRESS[$key]}
								GW_CURRENT[$key]=${GW_ADDRESS[$key]}						
						else
							if [ "${GW_ADDRESS[$key]}" != "${GW_CURRENT[$key]}" ]; then
								change_message "GATEWAY CHANGE: DELETE static route 0.0.0.0/0 next-hop ${GW_CURRENT[$key]}"
								delete static route 0.0.0.0/0 next-hop ${GW_CURRENT[$key]}
								change_message "GATEWAY CHANGE: SET static route 0.0.0.0/0 next-hop ${GW_ADDRESS[$key]}"
								set static route 0.0.0.0/0 next-hop ${GW_ADDRESS[$key]}
								change_message "GATEWAY CHANGE: DELETE static table $CURRENT_TABLE route 0.0.0.0/0 next-hop ${GW_CURRENT[$key]}"
								delete static table $CURRENT_TABLE route 0.0.0.0/0 next-hop ${GW_CURRENT[$key]}
								change_message "GATEWAY CHANGE: SET static table $CURRENT_TABLE route 0.0.0.0/0 next-hop ${GW_ADDRESS[$key]}"
								set static table $CURRENT_TABLE route 0.0.0.0/0 next-hop ${GW_ADDRESS[$key]}
								GW_CURRENT[$key]=${GW_ADDRESS[$key]}
							fi
						fi
					fi
				fi
			done
			up
			commit
		fi
	fi
}
##############################PBR / IP RULE FUNCTIONS###############################
###
do_ping_check(){
	for(( n = 0; n < ${#INTERFACE[*]}; n++ )); do
		SINGLE_INTERFACE=${INTERFACE[n]}
		ping_interface $TIMEOUT $SINGLE_INTERFACE $TEST_ADDRESS
		set_ping_status $SINGLE_INTERFACE $PRESULT
	done	
	change_routes
}
###
ping_interface(){
    #sudo ping -W $1 -I ${IP_ADDRESS[$2]} -c 1 $3 > /dev/null  2>&1
	sudo ping -W $1 -I $2 -c 1 $3 > /dev/null  2>&1
    PRESULT=$?
}
###
set_ping_status(){
	#loop through and ping all of the interfaces
	#
	
	#ping_interface $TIMEOUT $SINGLE_INTERFACE $TEST_ADDRESS
	if [ $2 = 0 ]; then
		x=${CURRENT_SUCCESS[$1]}
		if [[ $x < $SUCCESS ]]; then
			((CURRENT_SUCCESS[$1]=x+1))
			x=${CURRENT_SUCCESS[$1]}
			if [ $x = $SUCCESS ]; then
				set_interface_status $1 true
			fi
			CURRENT_FAILURE[$1]=0
		fi
	else
		x=${CURRENT_FAILURE[$1]}
		if [[ $x < $FAILURE ]]; then
			((CURRENT_FAILURE[$1]=x+1))
			x=${CURRENT_FAILURE[$1]}
			if [ $x = $FAILURE ]; then
				set_interface_status $1 false
			fi
			CURRENT_SUCCESS[$1]=0
		fi
	fi	
}
###
set_interface_status(){
	prev_status=${CURRENT_STATUS[$1]}
	CURRENT_STATUS[$1]=$2
	STATUS_MARK=${INTERFACE_MARK[$1]}
	STATUS_TABLE=${INTERFACE_TABLE[$1]}
	if [ $2 = true ]; then
		status=UP
	else
		status=DOWN
	fi
	
	if [ $prev_status = false ]; then
		if [[ $prev_status != $2 ]]; then
			if [ $INITIALIZING = true ]; then
				INITIALIZED_INTERFACES[$1]=true
				change_message "INITIALIZING: $1 [$status] | Traffic Mark [$STATUS_MARK] | Lookup Table [$STATUS_TABLE]"
			else
				change_message "STATUS: $1 [$status] | Traffic Mark [$STATUS_MARK] | Lookup Table [$STATUS_TABLE]"
			fi
		else
			if [ $INITIALIZING = true ]; then
				INITIALIZED_INTERFACES[$1]=true
				change_message "INITIALIZING: $1 [$status] | Traffic Mark [$STATUS_MARK] | Lookup Table [$STATUS_TABLE]"
			else
				change_message "STATUS: $1 [$status] | Traffic Mark [$STATUS_MARK] | Lookup Table [$STATUS_TABLE]"
			fi			
		fi
	else
		if [ $INITIALIZING = true ]; then
			INITIALIZED_INTERFACES[$1]=true
			change_message "INITIALIZING: $1 [$status] | Traffic Mark [$STATUS_MARK] | Lookup Table [$STATUS_TABLE]"
		
		else
			change_message "STATUS: $1 [$status] | Traffic Mark [$STATUS_MARK] | Lookup Table [$STATUS_TABLE]"
		fi		
	fi
}
###
change_routes(){
	for((r = 0; r < $INTERFACES; r++)); do
		route_key="${INTERFACE[$r]}"
		route_status=${CURRENT_STATUS[$route_key]}
		available_route=false
		if [ $route_status = false ]; then
			if [ ${CHANGED_ROUTE[$route_key]} = 0 ]; then
				for(( z = 0; z < $INTERFACES; z++ )); do
					new_key=${INTERFACE[z]}
					check_route=${CURRENT_STATUS[$new_key]}
					if [ $check_route = true ]; then
						available_route=true
						ALL_ROUTES_DOWN=false
						break
					fi
				done
				if [ $available_route = true ]; then
					route_mark=${INTERFACE_MARK[$route_key]}
					route_table=${INTERFACE_TABLE[$route_key]}
					new_table=${INTERFACE_TABLE[$new_key]}
					change_message "ROUTE CHANGE: ADD Traffic Marked [$route_mark] From Table [$route_table] To Table [$new_table]"
					((CHANGED_ROUTE[$route_key]=$new_table))	
					add_route $route_mark $new_table				
				else
					if [ $ALL_ROUTES_DOWN = false ]; then
						change_message "OUTAGE: ## All Routes [DOWN] ##" 
						ALL_ROUTES_DOWN=true
					fi
				fi
			fi
		else
			ALL_ROUTES_DOWN=false
			if [ ${CHANGED_ROUTE[$route_key]} != 0 ]; then
				route_mark=${INTERFACE_MARK[$route_key]}
				route_table=${INTERFACE_TABLE[$route_key]}
				new_table=${CHANGED_ROUTE[$route_key]}				
				change_message "ROUTE CHANGE: DELETE Traffic Marked [$route_mark] From Table [$new_table]"
				((CHANGED_ROUTE[$route_key]=0))	
				delete_route $route_mark $new_table			
			fi
		fi
		
	done
}
###
add_route(){
	ip rule add from all fwmark $1 lookup $2
}
###
delete_route(){
	ip rule delete from all fwmark $1 lookup $2
}
##############################MISC OTHER FUNCTIONS##################################
###
initialize(){	
	for(( i = 0; i < ${#INTERFACE[*]}; i++ )); do
		key=${INTERFACE[i]}
		CURRENT_SUCCESS[$key]=0
		CURRENT_FAILURE[$key]=0
		CURRENT_STATUS[$key]=false
		CHANGED_ROUTE[$key]=0
		DHCP_LIST[$key]=${USE_DHCP[$i]}	
		INTERFACE_TABLE[$key]=${LOOKUP_TABLE[$i]}
		INTERFACE_MARK[$key]=${TRAFFIC_MARK[$i]}
		GW_ADDRESS[$key]=0
		GW_CURRENT[$key]=0
		IP_ADDRESS[$key]=0
		INITIALIZED_INTERFACES[$key]=false
	done
	INTERFACES=$i
	info_message "INITIALIZING: Getting Gateway Addresses"	
	get_all_gateways
	info_message "INITIALIZING: Setting Gateway Addresses"	
	set_all_gateways
	info_message "INITIALIZING: Getting Status of Interfaces"
	get_all_status
	INITIALIZING=false
	display_info $(date +%s)
}

###
display_info(){
	if [ ! -z $1 ]; then
		initialize_time=$(( $1 - $begin_time ))
		info_message "INITIALIZATION COMPLETED: took $initialize_time seconds"
	else
		info_message "----------------------------------------------"
		info_message "| EDGEMAX LITE - PBR / FAILOVER SCRIPT "
		info_message "| by Matthew Holder matthew.holder@jivetek.com"
		info_message "| version $version"
		info_message "----------------------------------------------"
		info_message " "
		info_message "STARTUP TIME: $display_time"
		info_message "INITIALIZING: Setting Environmental Variables"
	fi
}

###
get_all_status(){
	for(( s = 0; s < $INTERFACES; s++ )); do
		init_current_if="${INTERFACE[$s]}"
		current_is_initialized=${INITIALIZED_INTERFACES[$init_current_if]}
		until [ $current_is_initialized = true ]; do
			ping_interface $TIMEOUT $init_current_if $TEST_ADDRESS
			set_ping_status $init_current_if $PRESULT
			current_is_initialized=${INITIALIZED_INTERFACES[$init_current_if]}
		done
	done
}
###
debug_message(){
	if [ $DEBUG = true ]; then
		echo "   ---DEBUG MESSAGE---"
		echo "   "$1
	fi	
}
###
info_message(){
	if [ $MESSAGE = true ]; then
		echo $1
	fi
}
###
change_message(){
	if [ $CHANGES = true ]; then
		echo $1
	fi
}
##############################PROGRAM MAIN##########################################
begin_time=$(date +%s)
display_time=$(date)
clear
display_info
initialize
dhcp_begin_time=$(date +%s)
ping_begin_time=$(date +%s)
while : ; do
	if [ $USING_DHCP = true ]; then
		dhcp_current_time=$(date +%s)
		dhcp_check_time="$(( $dhcp_current_time - $dhcp_begin_time ))"
		if [ $dhcp_check_time -ge $DHCP_CHECK ]; then
			do_gateway_check
			dhcp_begin_time=$(date +%s)
		fi		
	fi
	ping_current_time=$(date +%s)
	ping_check_time="$(( $ping_current_time - $ping_begin_time ))"
	if [ $ping_check_time -ge $PING_TIMER ]; then
		do_ping_check
		ping_begin_time=$(date +%s)
	fi
done
