#!/bin/sh
# Copyright (C) 2011-2012 Luka Perkov <freecwmp@lukaperkov.net>
# Copyright (C) 2013 Inteno Broadband Technology AB
#  Author Mohamed Kallel <mohamed.kallel@pivasoftware.com>
#  Author Ahmed Zribi <ahmed.zribi@pivasoftware.com>

. /lib/functions.sh
. /usr/share/libubox/jshn.sh
. /usr/share/shflags/shflags.sh
. /usr/share/freecwmp/defaults

# define a 'name' command-line string flag
DEFINE_boolean 'newline' false 'do not output the trailing newline' 'n'
DEFINE_boolean 'value' false 'output values only' 'v'
DEFINE_boolean 'json' false 'send values using json' 'j'
DEFINE_boolean 'empty' false 'output empty parameters' 'e'
DEFINE_boolean 'last' false 'output only last line ; for parameters that tend to have huge output' 'l'
DEFINE_boolean 'debug' false 'give debug output' 'd'
DEFINE_boolean 'dummy' false 'echo system commands' 'D'
DEFINE_boolean 'force' false 'force getting values for certain parameters' 'f'

FLAGS_HELP=`cat << EOF
USAGE: $0 [flags] command [parameter] [values]
command:
get [value|notification|name|cache]
  set [value|notification]
  apply [value|notification|download]
  add [object]
  delete [object]
  download
  factory_reset
  reboot
  notify
  end_session
  inform
  json_continuous_input
EOF`

FLAGS "$@" || exit 1
eval set -- "${FLAGS_ARGV}"

if [ ${FLAGS_help} -eq ${FLAGS_TRUE} ]; then
	exit 1
fi

if [ ${FLAGS_newline} -eq ${FLAGS_TRUE} ]; then
	ECHO_newline='-n'
fi

UCI_GET="/sbin/uci ${UCI_CONFIG_DIR:+-c $UCI_CONFIG_DIR} get -q"
UCI_SET="/sbin/uci ${UCI_CONFIG_DIR:+-c $UCI_CONFIG_DIR} set -q"
UCI_BATCH="/sbin/uci ${UCI_CONFIG_DIR:+-c $UCI_CONFIG_DIR} batch -q"
UCI_ADD="/sbin/uci ${UCI_CONFIG_DIR:+-c $UCI_CONFIG_DIR} add -q"
UCI_GET_VARSTATE="/sbin/uci ${UCI_CONFIG_DIR:+-c $UCI_CONFIG_DIR} -P /var/state get -q"
UCI_SHOW="/sbin/uci ${UCI_CONFIG_DIR:+-c $UCI_CONFIG_DIR} show -q"
UCI_DELETE="/sbin/uci ${UCI_CONFIG_DIR:+-c $UCI_CONFIG_DIR} delete -q"
UCI_COMMIT="/sbin/uci ${UCI_CONFIG_DIR:+-c $UCI_CONFIG_DIR} commit -q"
NEW_LINE='\n'
cache_path="/etc/cwmpd/.cache"
set_tmp_file="/etc/cwmpd/.set_tmp_file"
prefix_list=""
	
mkdir -p $cache_path
rm -f "$cache_path/"*"_dynamic"

case "$1" in
	set)
		if [ "$2" = "notification" ]; then
			__arg1="$3"
			__arg2="$4"
			__arg3="$5"
			action="set_notification"
		elif [ "$2" = "value" ]; then
			__arg1="$3"
			__arg2="$4"
			action="set_value"
		else
			__arg1="$2"
			__arg2="$3"
			action="set_value"
		fi
		;;
	get)
		if [ "$2" = "notification" ]; then
			__arg1="$3"
			action="get_notification"
		elif [ "$2" = "value" ]; then
			__arg1="$3"
			action="get_value"
		elif [ "$2" = "name" ]; then
			__arg1="$3"
			__arg2="$4"
			action="get_name"
		elif [ "$2" = "cache" ]; then
			__arg1="$3"
			action="get_cache"
		else
			__arg1="$2"
			action="get_value"
		fi
		;;
	download)
		__arg1="$2"
		__arg2="$3"
		__arg3="$4"
		__arg4="$5"
		__arg5="$6"
		action="download"
		;;
	factory_reset)
		action="factory_reset"
		;;
	reboot)
		action="reboot"
		;;
	apply)
		if [ "$2" = "notification" ]; then
			action="apply_notification"
		elif [ "$2" = "value" ]; then
			action="apply_value"
		elif [ "$2" = "download" ]; then
			__arg1="$3"
			action="apply_download"
		else
			action="apply_value"
		fi
		;;
	add)
			__arg1="$3"
			action="add_object"
		;;
	delete)
			__arg1="$3"
			action="delete_object"
		;;
	inform)
		action="inform"
		;;
	notify)
		action="notify"
		__arg1="$2"
		__arg2="$3"
		__arg3="$4"
		;;
	end_session)
		action="end_session"
		;;
	json_continuous_input)
		action="json_continuous_input"
		;;
	end)
		echo "EOF"
		;;
	exit)
		exit 0
	;;
esac

if [ -z "$action" ]; then
	echo invalid action \'$1\'
	exit 1
fi

if [ ${FLAGS_debug} -eq ${FLAGS_TRUE} ]; then
	echo "[debug] started at \"`date`\""
fi

load_script() {
	. $1 
}

load_prefix() {
	prefix_list="$prefix_list $1"
}

handle_scripts() {
	local section="$1"
	config_list_foreach "$section" 'location' load_script
	config_list_foreach "$section" 'prefix' load_prefix
}

config_load cwmp
config_foreach handle_scripts "scripts"

# Fault code

FAULT_CPE_NO_FAULT="0"
FAULT_CPE_REQUEST_DENIED="1"
FAULT_CPE_INTERNAL_ERROR="2"
FAULT_CPE_INVALID_ARGUMENTS="3"
FAULT_CPE_RESOURCES_EXCEEDED="4"
FAULT_CPE_INVALID_PARAMETER_NAME="5"
FAULT_CPE_INVALID_PARAMETER_TYPE="6"
FAULT_CPE_INVALID_PARAMETER_VALUE="7"
FAULT_CPE_NON_WRITABLE_PARAMETER="8"
FAULT_CPE_NOTIFICATION_REJECTED="9"
FAULT_CPE_DOWNLOAD_FAILURE="10"
FAULT_CPE_UPLOAD_FAILURE="11"
FAULT_CPE_FILE_TRANSFER_AUTHENTICATION_FAILURE="12"
FAULT_CPE_FILE_TRANSFER_UNSUPPORTED_PROTOCOL="13"
FAULT_CPE_DOWNLOAD_FAIL_MULTICAST_GROUP="14"
FAULT_CPE_DOWNLOAD_FAIL_CONTACT_SERVER="15"
FAULT_CPE_DOWNLOAD_FAIL_ACCESS_FILE="16"
FAULT_CPE_DOWNLOAD_FAIL_COMPLETE_DOWNLOAD="17"
FAULT_CPE_DOWNLOAD_FAIL_FILE_CORRUPTED="18"
FAULT_CPE_DOWNLOAD_FAIL_FILE_AUTHENTICATION="19"

handle_action() {
	local fault_code=$FAULT_CPE_NO_FAULT
	if [ "$action" = "get_cache" ]; then
		if [ "$__arg1" != "" ];then
			local l=${#__arg1}
			let l--
			local c=${__arg1:$l:1}
			if [ "$c" != "." ];then
				echo "Invalid prefix argument"
			exit -1
		fi
	fi
		local tmp_cache="/tmp/.freecwmp_dm"
		local ls_cache=`ls $tmp_cache`
		local pid=""
		for pid in $ls_cache; do
			if [ ! -d /proc/$pid ]; then
				rm -rf "$tmp_cache/$pid"
			fi
		done
		pid="$$"
		mkdir -p "$tmp_cache/$pid"
	
		for prefix in $prefix_list; do
			case $prefix in $__arg1*)
				local found=1
				local f=${prefix%.}
				f=${f//./_}
				f="get_cache_""$f"
				$f > "$tmp_cache/$pid/$prefix"
				mv "$tmp_cache/$pid/$prefix" "$cache_path/$prefix"
				;;
			esac
		done
		
		rm -rf "$tmp_cache/$pid"
		ls_cache=`ls $tmp_cache`
		for pid in $ls_cache; do
			if [ ! -d /proc/$pid ]; then
				rm -rf "$tmp_cache/$pid"
			fi
		done
		ls_cache=`ls $tmp_cache`
		if [ "_$ls_cache" = "_" ]; then
			rm -rf "$tmp_cache"
		fi
		fi
	
	if [ "$action" = "get_value" ]; then
		get_param_value_generic "$__arg1"
		fault_code="$?"
	if [ "$fault_code" != "0" ]; then
		let fault_code=$fault_code+9000
			freecwmp_output "$__arg1" "" "" "" "" "$fault_code"
	fi
fi

	if [ "$action" = "get_name" ]; then
		if [ "$__arg2" != "0" -a "$__arg2" != "1" ]; then
			fault_code="$FAULT_CPE_INVALID_ARGUMENTS"
			else
			get_param_name_generic "$__arg1" "$__arg2"
			fault_code="$?"
		fi
	if [ "$fault_code" != "0" ]; then
		let fault_code=$fault_code+9000
			freecwmp_output "$__arg1" "" "" "" "" "$fault_code"
	fi
fi

	if [ "$action" = "get_notification" ]; then
		get_param_notification_generic "$__arg1"
		fault_code="$?"
	if [ "$fault_code" != "0" ]; then
		let fault_code=$fault_code+9000
			freecwmp_output "$__arg1" "" "" "" "" "$fault_code"
	fi
fi

	if [ "$action" = "set_value" ]; then	
		set_param_value_generic "$__arg1" "$__arg2"
		fault_code="$?"
	if [ "$fault_code" != "0" ]; then
		let fault_code=$fault_code+9000
			freecwmp_set_parameter_fault "$__arg1" "$fault_code"
	fi
fi

	if [ "$action" = "set_notification" -a "$__arg3" = "1" ]; then
		set_param_notification_generic "$__arg1" "$__arg2"
			fault_code="$?"
	if [ "$fault_code" != "0" ]; then
		let fault_code=$fault_code+9000
			freecwmp_set_parameter_fault "$__arg1" "$fault_code"
	fi
fi


if [ "$action" = "add_object" ]; then
		object_fn_generic "$__arg1"
	fault_code="$?"
	if [ "$fault_code" != "0" ]; then
		let fault_code=$fault_code+9000
			freecwmp_output "" "" "" "" "" "$fault_code"
	fi
fi

if [ "$action" = "delete_object" ]; then
		object_fn_generic "$__arg1"
		fault_code="$?"
	if [ "$fault_code" != "0" ]; then
		let fault_code=$fault_code+9000
			freecwmp_output "" "" "" "" "" "$fault_code"
fi
fi

if [ "$action" = "download" ]; then
	local fault_code="9000"
		if [ "$__arg4" = "" -o "$__arg5" = "" ];then
			wget -O /tmp/freecwmp_download "$__arg1" 2> /dev/null
		if [ "$?" != "0" ];then
			let fault_code=$fault_code+$FAULT_CPE_DOWNLOAD_FAILURE
			freecwmp_fault_output "" "$fault_code"
			exit 1
		fi
	else
			local url="http://$__arg4:$__arg5@`echo $__arg1|sed 's/http:\/\///g'`"
			wget -O /tmp/freecwmp_download "$url" 2> /dev/null
		if [ "$?" != "0" ];then
			let fault_code=$fault_code+$FAULT_CPE_DOWNLOAD_FAILURE
			freecwmp_fault_output "" "$fault_code"
			exit 1
		fi
	fi

	local flashsize="`freecwmp_check_flash_size`"
	local filesize=`ls -l /tmp/freecwmp_download | awk '{ print $5 }'`
		if [ $flashsize -gt 0 -a $flashsize -lt $__arg2 ]; then
		let fault_code=$fault_code+$FAULT_CPE_DOWNLOAD_FAILURE
		rm /tmp/freecwmp_download 2> /dev/null
		freecwmp_fault_output "" "$fault_code"
	else
			if [ "$__arg3" = "1" ];then
			mv /tmp/freecwmp_download /tmp/firmware_upgrade_image 2> /dev/null
			freecwmp_check_image
			if [ "$?" = "0" ];then
				if [ $flashsize -gt 0 -a $filesize -gt $flashsize ];then
					let fault_code=$fault_code+$FAULT_CPE_DOWNLOAD_FAIL_FILE_CORRUPTED
					rm /tmp/firmware_upgrade_image 2> /dev/null
					freecwmp_fault_output "" "$fault_code"
				else
					rm /tmp/firmware_upgrade_image_last_valid 2> /dev/null
					mv /tmp/firmware_upgrade_image /tmp/firmware_upgrade_image_last_valid 2> /dev/null
					freecwmp_fault_output "" "$FAULT_CPE_NO_FAULT"
				fi
			else
				let fault_code=$fault_code+$FAULT_CPE_DOWNLOAD_FAIL_FILE_CORRUPTED
				rm /tmp/firmware_upgrade_image 2> /dev/null
				freecwmp_fault_output "" "$fault_code"
			fi
			elif [ "$__arg3" = "2" ];then
			mv /tmp/freecwmp_download /tmp/web_content.ipk 2> /dev/null
			freecwmp_fault_output "" "$FAULT_CPE_NO_FAULT"
			elif [ "$__arg3" = "3" ];then
			mv /tmp/freecwmp_download /tmp/vendor_configuration_file.cfg 2> /dev/null
			freecwmp_fault_output "" "$FAULT_CPE_NO_FAULT"
		else
			let fault_code=$fault_code+$FAULT_CPE_DOWNLOAD_FAILURE
			freecwmp_fault_output "" "$fault_code"
			rm /tmp/freecwmp_download 2> /dev/null
		fi
	fi
fi

if [ "$action" = "apply_download" ]; then
		case "$__arg1" in
		1) freecwmp_apply_firmware ;;
		2) freecwmp_apply_web_content ;;
		3) freecwmp_apply_vendor_configuration ;;
	esac
fi

if [ "$action" = "factory_reset" ]; then
	if [ ${FLAGS_dummy} -eq ${FLAGS_TRUE} ]; then
		echo "# factory_reset"
	else
		jffs2_mark_erase "rootfs_data"
		sync
		reboot
	fi
fi

if [ "$action" = "reboot" ]; then
	if [ ${FLAGS_dummy} -eq ${FLAGS_TRUE} ]; then
		echo "# reboot"
	else
		sync
		reboot
	fi
fi

if [ "$action" = "apply_notification" -o "$action" = "apply_value" ]; then
	__fault_count=`cat /var/state/cwmp 2> /dev/null |wc -l 2> /dev/null`
	let __fault_count=$__fault_count/3
	if [ "$__fault_count" = "0" ]; then
		# applying
			$UCI_COMMIT
			local prefix=""
			local filename=""
			local max_len=0
			local len=0

			case $action in
				apply_notification)
				cat $set_tmp_file | while read line; do
					json_init
					json_load "$line"
					json_get_var parameter parameter
					json_get_var notification notification
					max_len=0
					for prefix in $prefix_list; do
						case  "$parameter" in "$prefix"*)
							len=${#prefix}
							if [ $len -gt $max_len ]; then
								max_len=$len
								filename="$prefix"
		fi
						esac
					done
					local l=${#parameter}
					let l--
					if [ "${parameter:$l:1}" != "." ]; then
						sed -i "/\<$parameter\>/s/.*/$line/" $cache_path/$filename
					else
						cat $cache_path/$filename|grep "$parameter"|grep "\"notification\""| while read line; do
							json_init
							json_load "$line"
							json_get_var parameter_name parameter
							json_add_string "notification" "$notification"
							json_close_object
							param=`json_dump`
							sed -i "/\<$parameter_name\>/s/.*/$param/" $cache_path/$filename
						done
					fi
				done
				freecwmp_output "" "" "" "" "" "" "" "" "0"
				;;
				apply_value)
				cat $set_tmp_file | while read line; do
					json_init
					json_load "$line"
					json_get_var parameter parameter
					json_get_var value value
					json_get_var notification notification
					json_get_var type type
					max_len=0
					for prefix in $prefix_list; do
						case  "$parameter" in "$prefix"*)
							len=${#prefix}
							if [ $len -gt $max_len ]; then
								max_len=$len
								filename="$prefix"
							fi
						esac
					done
					sed -i "/\<$parameter\>/s/.*/$line/" $cache_path/$filename
					freecwmp_notify "$parameter" "$value" "$notification" "$type"
				done
				freecwmp_output "" "" "" "" "" "" "1"
				;;
			esac
	else
		let n=$__fault_count-1
		for i in `seq 0 $n`
		do
			local parm=`/sbin/uci ${UCI_CONFIG_DIR:+-c $UCI_CONFIG_DIR} -q -P /var/state get cwmp.@fault[$i].parameter 2> /dev/null`
			local fault_code=`/sbin/uci ${UCI_CONFIG_DIR:+-c $UCI_CONFIG_DIR} -q -P /var/state get cwmp.@fault[$i].fault_code 2> /dev/null`
			freecwmp_fault_output "$parm" "$fault_code"
			if [ "$action" = "apply_notification" ]; then break; fi
		done
		rm -rf /var/state/cwmp 2> /dev/null
		/sbin/uci ${UCI_CONFIG_DIR:+-c $UCI_CONFIG_DIR} -q revert cwmp
	fi
		rm -f $set_tmp_file
fi

if [ "$action" = "inform" ]; then
		cat "$cache_path/"* | grep "\"forced_inform\"" | grep -v "\"get_cmd\""
		cat "$cache_path/"* | grep "\"forced_inform\"" | grep "\"get_cmd\"" | while read line; do
			json_init
			json_load "$line"
			json_get_var exec_get_cmd get_cmd
			json_get_var param parameter
			json_get_var type type
			val=`eval "$exec_get_cmd"`
			freecwmp_output "$param" "$val" "" "$type"
		done
fi

if [ "$action" = "notify" ]; then
		freecwmp_notify "$__arg1" "$__arg2"
fi

if [ "$action" = "end_session" ]; then
	echo 'rm -f /tmp/end_session.sh' >> /tmp/end_session.sh
	/bin/sh /tmp/end_session.sh
fi
	if [ "$action" = "json_continuous_input" ]; then
		echo "EOF"
		while read CMD; do
			[ -z "$CMD" ] && continue
			result=""
			json_init
			json_load "$CMD"
			json_get_var command command
			json_get_var  action action
			case "$command" in
				set)
					if [ "$action" = "notification" ]; then
						json_get_var __arg1 parameter
						json_get_var __arg2 value
						json_get_var __arg3 change
						action="set_notification"
					elif [ "$action" = "value" ]; then
						json_get_var __arg1 parameter
						json_get_var __arg2 value
						action="set_value"
					else
						json_get_var __arg1 parameter
						json_get_var __arg2 value
						action="set_value"
					fi
					;;
				get)
					if [ "$action" = "cache" ]; then
						json_get_var __arg1 parameter
						action="get_cache"
					elif [ "$action" = "notification" ]; then
						json_get_var __arg1 parameter
						action="get_notification"
					elif [ "$action" = "value" ]; then
						json_get_var __arg1 parameter
						action="get_value"
					elif [ "$action" = "name" ]; then
						json_get_var __arg1 parameter
						json_get_var __arg2 next_level
						action="get_name"
					else
						json_get_var __arg1 parameter
						action="get_value"
					fi
					;;
				download)
					json_get_var __arg1 url
					json_get_var __arg2 size
					json_get_var __arg3 type
					json_get_var __arg4 user
					json_get_var __arg5 pass
					action="download"
					;;
				factory_reset)
					action="factory_reset"
					;;
				reboot)
					action="reboot"
					;;
				apply)
					if [ "$action" = "notification" ]; then
						action="apply_notification"
					elif [ "$action" = "value" ]; then
						action="apply_value"
					elif [ "$action" = "download" ]; then
						json_get_var __arg1 type
						action="apply_download"
					else
						action="apply_value"
					fi
					;;
				add)
					json_get_var __arg1 parameter
					action="add_object"
					;;
				delete)
					json_get_var __arg1 parameter
					action="delete_object"
					;;
				inform)
					action="inform"
					;;
				end_session)
					action="end_session"
					;;
				end)
					echo "EOF"
					;;
				exit)
					exit 0
					;;
				*)
					continue
					;;
			esac
			handle_action
		done
	
		exit 0;
	fi
}

handle_action 2> /dev/null

if [ ${FLAGS_debug} -eq ${FLAGS_TRUE} ]; then
	echo "[debug] exited at \"`date`\""
fi