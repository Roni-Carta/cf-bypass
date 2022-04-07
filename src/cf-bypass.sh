#!/bin/bash

# Configure Bash
IFS=$'\n\t'
trap ctrl_c INT

# Global Variables
useragent="user-agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/96.0.4664.110 Safari/537.36"

# Modes

ST_MODE=0
COLLAB_MODE=0

ctrl_c()
{
  # If the user interrupts the script, we want to exit gracefully.
  echo "** Quitting ..."
  exit 1;
}

get_domain()
{
  # Get the domain from the URL.
  link="$1"
  echo "$link" |\
  sed 's/^.*:\/\///g' |\
  sed 's/\/.*$//g'
}

check_domain()
{
  # If domain is not NXDOMAIN, then it's valid
  domain="$1"
  if [[ $(dig +short "$domain") ]]; then
    echo "OK"
  fi
}

is_cloudflare()
{
  # Check if the domain is a Cloudflare domain.
  domain="$1"
  result=`curl -N --connect-timeout 2 -L -sk -H "$useragent" "https://$domain/'OR%201='1" | sed 's/\x0//g'`
  if [[ `echo "$result" | grep "Cloudflare Ray"` ]]; then
    echo "OK"
  elif [[ `echo "$result" | grep "error code: 1020"` ]]; then
    echo "OK"
  fi
}

get_historical_data()
{
  # Get historical data from Security Trails.
  domain="$1"

  # if $debug exists, then we're in debug mode.
  if [[ "$debug" != "0" ]]; then
    # Get historical data from Security Trails of the domain
    response=`curl -N -s "https://api.securitytrails.com/v1/history/$domain/dns/a?page=1" \
      --header "APIKEY: $SECURITY_TRAILS_API_KEY" \
      --header 'Accept: application/json'`
    _debug "get_historical_data: Debug is not in Mock Mode"
  else
    response=`cat test/mock.json`
    _debug "get_historical_data: Debug is in Mock Mode"
  fi

  # Check for errors regarding the API Key
  if [[ `echo "$response" | grep "You've exceeded the usage limits for your account."` ]]; then
    >&2 echo "ERROR: You've exceeded the usage limits for your Security Trails account."
    exit 1
  fi

  ips=`echo "$response" | jq .records[]?.values[]?.ip -r | sort -u`
  _debug "get_historical_data: IPS $ips"
  echo "$ips"
}

calc()
{
  # I like this kind of calculator ! :)
  awk "BEGIN { print "$*" }";
}

_debug()
{
  # We want to print informations to debug.txt only if we are in debug mode.
  if [[ "$debug" ]]; then
    echo "$@" >> debug.txt
  fi
}
calculate_certainty()
{
  # Here we are calculating the difference in percent of the length of the response with:
  # 1. The length of the response going trough Cloudflare
  # 2. The length of the response going trough the original domain
  # Then we are calculating ((cloudflare_length-original_length)/original_length)*100
  # If the result is negative, we are multiplying by -1 to make it positive.
  # The percent will give us the certainty of the response. Lower the percent, the more certain we are.

  domain="$1"
  ip="$2"

  _debug "calculate_certainty: IP: $ip / Domain : $domain"

  rand="$RANDOM"
  website=`curl -N -X GET --connect-timeout 2 -L -sk -H "$useragent" "https://$domain/thishsouldbea404-$rand'%20OR1'1" | sed 's/\x0//g'`
  check=`curl -N -X GET --connect-timeout 2 -L -sk -H "$useragent" "https://$ip/thishsouldbea404-$rand'%20OR1'1" -H "Host: $domain" | sed 's/\x0//g'`

  website_length="${#website}"

  check_length="${#check}"

  # If check_length is 0, then make it 1
  if [[ "$check_length" -eq 0 ]]; then
    check_length=1
  fi

  _debug "calculate_certainty: Calcul (($website_length-$check_length)/$check_length)*100"


  certainty=`calc "(($website_length-$check_length)/$check_length)*100" | cut -d. -f1 | sed 's/-//g'`
  _debug "calculate_certainty: Result $certainty"

  # Arbitrary certainty threshold
  if [[ "$certainty" -gt 30 ]]; then
        :
  elif [[ "$certainty" -ge 0 && "$certainty" -le 10 ]]; then
      echo -e "\033[0;31m[!] Certain Risk: $ip $domain\x1B[0m"
    elif [[ "$certainty" -ge 11 && "$certainty" -le 19 ]]; then
      echo -e "\033[1;35m[+] High Risk: $ip $domain\x1B[0m"
    elif [[ "$certainty" -ge 20 ]]; then
      echo -e "\033[0;34m[!] Low Risk: $ip $domain\x1B[0m"
    fi
}

check_if_blocked()
{
  # Check when sending a request to the domain, with 'OR 1='1 we get blocked by Cloduflare.
  host="$1"
  hostname="$2"
  _debug "check_if_blocked: $host $hostname"
  code=`curl -N --connect-timeout 2 -L -ski -H "$useragent" -H "Host: $hostname" "https://$host/'OR%201='1" | head -n1 | awk '{ print $2 }' | sed 's/\x0//g'`
  _debug "check_if_blocked: Code $code"
  # If code is not null
  if [[ "$code" && "$code" != "530" ]]; then
    _debug "check_if_blocked: Code is not null nor 530"
    # If code is 403
    if [[ "$code" == 403 ]]; then
      _debug "check_if_blocked: Code is 403"
      echo "blocked"
    else
      echo "OK"
    fi
  fi
}

bypass-cf()
{
  # Here the magic begin :)
  domain="$1"
  if [ "$ST_MODE" = "1" ]; then
    historical_data=`get_historical_data "$domain"`
    for ip in $historical_data; do
      # Check if IP get's blocked
      if [[ $(check_if_blocked "$ip" "$domain") == "OK" ]]; then
        calculate_certainty "$domain" "$ip"
      fi
    done
  fi 
}

check_random_host()
{
  # Check if a random host is blocked. This will avoid false positives :)
  _debug "check_random_host: Checking if domain accepts a random host"
  domain="$1"
  certainty=`calculate_certainty "$RANDOM.$domain" "$domain"`
  if [[ "$certainty" ]]; then
    echo "NOPE"
  fi
}

get_ips()
{
  # Get all IPs from a domain
  domain="$1"
  ips=`dig +short "$domain" | grep '^[.0-9]*$'`
  echo "$ips"
}

put()
{
  # If $silence doesn't exist, then print the message
  if [[ ! "$silence" ]]; then
    echo -e "$@"
    _debug "$@"
  fi
}

parse_modes()
{
  modes="$1"
  activated=""
  for mode in `echo "$modes" | sed 's/,/ /g'`; do
	if [ "$mode" = "st" ]; then
		ST_MODE=1
		activated+="Security Trails "
	elif [ "$mode" = "c" ]; then
		COLLAB_MODE=1
    activated+="Collaborator "
	fi
  done

  if [ "$activated" = "" ]; then 
    printf "\nYou have to chose from the different modes:\n\tst: Security Trails Detection\n\tc: Collaborator Based Detection\n\n"
    exit 1
  else
    put "[*] Active Modes: $activated"
  fi
}


helpage()
{
  echo "CF-Bypass is a Scanner that will attempt to bypass Cloudflare by finding the Origin IP of the server."
  # Usage
  printf "\tUsage:\n\t\tcf-bypass <flag> [options]\n\n"
  # Flags
  printf "\tFlags:\n\t\tcheck <hostname> <host>: Check if you can bypass the provided Hostname using the provided IP/Host\n\n"
  # Options
  printf "\tOptions:\n"
  printf "\t\t-h: Show this help\n"
  printf "\t\t-d: Enable Debugging\n"
  printf "\t\t-f: file containing a list of subdomains\n"
  printf "\t\t-s: silent output\n"
  printf "\t\t-m: Enabling Mode. Available Modes:\n"
  # Modes
  printf "\t\t\tst: Activate Security Trails Detection\n"
  printf "\t\t\tc: Activate Collaborator Detection\n"
  # Examples
  printf "\tExamples:\n\t\tcat subs.txt | cf-bypass [options]; # Uses Security Trails credits\n"
  printf "\t\tcf-bypass check www.cloudflare.com 1.1.1.1\n"
  printf "\t\tcf-bypass -f subs.txt\n"
  printf "\t\techo www.cloudflare.com | cf-bypass -n st,c\n"
  exit 1
}

if [[ "$*" == *-h* ]]
then
  helpage
fi

while getopts d:f:s:m: flag
do
    case "${flag}" in
        d) debug=${OPTARG};;
        f) subs=${OPTARG};;
        s) silence=${OPTARG};;
        m) modes=${OPTARG};;
    esac
done

put "           ___       _                                                     "
put "          / __)     | |                                                    "
put "   ____ _| |__ _____| |__  _   _ ____  _____  ___  ___                     "
put "  / ___|_   __|_____)  _ \| | | |  _ \(____ |/___)/___)                    "
put " ( (___  | |        | |_) ) |_| | |_| / ___ |___ |___ |                    "
put "  \____) |_|        |____/ \__  |  __/\_____(___/(___/                     "
put "                          (____/|_|                     0.0.1              "
put "                                                                           "
put "                                                                           "
put "                                     Roni Carta (0xLupin)                  "
put " "
put " "

if [ "$debug" = "0" ]; then
  put "[!] Debug Mode is activated with Mock Mode"
elif [ "$debug" ]; then
   put "[!] Debug Mode is activated"
fi

# If cf-bypass check <hostname> <host>
if [[ "$1" == *check* ]]; then
  hostname="$2"
  host="$3"
  random_host=`check_random_host "$domain"`
  if [[ "$random_host" == "NOPE" ]]; then
    exit 1;
  fi
  if [[ $(check_if_blocked "$host" "$hostname") == "OK" ]]; then
      calculate_certainty "$hostname" "$host"
  fi
  exit 1
fi

# If cf-bypass -f <subs.txt>
if [[ -f "$subs" ]]; then
  put "[*] Subdomain IP Search"
  while read -r subdomain; do
    ips=`get_ips "$subdomain"`
    ip_json+="{\"$subdomain\":\"$ips\"}"
  done < "$subs"

  put "[*] Check Subdomains"
  while read -r subdomain; do
    for ip in `echo "$ip_json" | jq -r .[]?`; do
      # If $ip in ip_json, skip
      if [[ ! `echo "$ip_json" | jq -r ".[\"$subdomain\"] | select( . != null )" | grep "$ip"` ]]; then
        #echo "[*] Checking: $subdomain $ip"
        random_host=`check_random_host "$domain"`
        if [[ $(check_if_blocked "$ip" "$subdomain") == "OK" && "$random_host" != "NOPE" ]]; then
          calculate_certainty "$subdomain" "$ip"
        fi
      fi
    done
  done < "$subs"
  exit 1;
fi

if [[ "$modes" ]]; then
    parse_modes "$modes"
fi

if [ "$COLLAB_MODE" = "0" ] && [ "$ST_MODE" = "0" ]; then
  ST_MODE="1"
fi

# Check if env contains security trails API key
if [[ -z $SECURITY_TRAILS_API_KEY ]]; then
  echo "Please set SECURITY_TRAILS_API_KEY in your environment variables"
  exit 1
fi

if [[ -t 0 ]]; then
  helpage
fi

# Read all input from pipe
while read line; do
  domain=`get_domain "$line"`
  is_valid=`check_domain "$domain"`
  random_host=`check_random_host "$domain"`

  if [[ "$is_valid" == "OK" &&  "$random_host" != "NOPE" ]]; then
    if [[ `is_cloudflare "$domain"` == "OK" ]]; then
      bypass-cf "$domain"
    fi
  fi
done
