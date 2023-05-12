#!/bin/bash
. nsclientsh.conf

help() {
  echo "NSClientSH is a tool to get values such as blood sugar from a NightScout instance."
}

unlock_instance()
{
  rm -f $pid_file
}

lock_instance()
{
  trap unlock_instance EXIT
  echo $$ > $pid_file
}

wait_instance()
{
  while [ -f $pid_file ];
  do
    sleep 1;
  done;
}

secs2mins() {
  ((h=${1}/3600))
  ((m=(${1}%3600)/60))
  echo $((($h/60)+$m))
}

get_properties_json() {
  #rm $properties_json
  #rm $entries_json
  wget $ns_url/api/v2/properties.json?token=$token -qO $properties_json 2> /dev/null
}


if [[ $# -eq 0 ]]; then
  help
  echo -e "\nNSClientSH requires at least one option. Try 'nsclientsh.sh --blood-sugar'"
  exit 1
fi

VALID_ARGS=$(getopt -o hvbadticpruofNF --long help,verbose,blood-sugar,arrow,delta,time-ago,iob,cob,tbr-percent,tbr-remaining,tbr-units,reservoir,reservoir-percent,no-update,force-update -- "$@")
if [[ $? -ne 0 ]]; then
  exit 1
fi

# Init options
opt_Verbose=0
opt_SkipUpdate=0
opt_ForceUpdate=0
updated=0
declare arr_requests=()
result=""

eval set -- "$VALID_ARGS"
while [ : ]; do
  case "$1" in
    -h | --help)
      help
      shift
      ;;
    -v | --verbose)
      opt_Verbose=1
      shift
      ;;
    -b | --blood-sugar)
      arr_requests+=('.bgnow.sgvs[0].scaled')
      shift
      ;;
    -a | --arrow)
      arr_requests+=('.direction.label')
      shift
      ;;
    -d | --delta)
      arr_requests+=('.delta.display')
      shift
      ;;
    -t | --time-ago)
      arr_requests+=('!time-ago')
      updated=1
      shift
      ;;
    -i | --iob)
      arr_requests+=('.iob.display')
      shift
      ;;
    -c | --cob)
      arr_requests+=('.cob.display')
      shift
      ;;
    -r | --tbr-remaining)
      arr_requests+=('.pump.pump.extended.TempBasalRemaining')
      shift
      ;;
    -u | --tbr-units)
      arr_requests+=('.pump.pump.extended.TempBasalAbsoluteRate')
      shift
      ;;
    -o | --reservoir)
      arr_requests+=('.pump.pump.reservoir')
      shift
      ;;

    -f | --reservoir-percent)
      arr_requests+=('!reservoir-percent')
      shift
      ;;
    -p | --tbr-percent)
      arr_requests+=('!tbr-percent')
      shift
      ;;

    -N | --no-update)
      opt_SkipUpdate=1
      shift
      ;;

    -F | --force-update)
      opt_ForceUpdate=1
      shift
      ;;

    --) shift;
      break 2
      ;;
  esac

done

wait_instance
lock_instance

# Check integrity of properties.json
[ -f "$properties_json" ] && [ -s "$properties_json" ] && jq empty $properties_json &> /dev/null
retVal=$?
if [ $retVal -ne 0 ]; then
  [ $opt_Verbose -eq 1 ] && echo "Error parsing properties.json"
  opt_SkipUpdate=0
  opt_ForceUpdate=1
fi

# Update properties.json
if [ $opt_SkipUpdate -ne 1 ]; then
  if [ $opt_ForceUpdate -eq 1 ]; then
    [ $opt_Verbose -eq 1 ] && echo "Forcing update"
    rm $properties_json
  fi

  if [ ! -f "$properties_json" ]; then
    [ $opt_Verbose -eq 1 ] && echo "Updating properties.json"
    get_properties_json
    updated=1
  else
    mills=$(jq -r '.bgnow.mills' $properties_json)
    age=$(($(date +%s%N | cut -b1-10) - ${mills::-3}))
    age_mins=$(secs2mins $age)
    [ $opt_Verbose -eq 1 ] && echo "Age of data: $age_mins minutes ($age seconds)"
    if [ "$age_mins" -gt "4" ]; then
      [ $opt_Verbose -eq 1 ] && echo "Updating properties.json"
      get_properties_json
      updated=1
    fi
  fi
elif [ $opt_Verbose -eq 1 ]; then
  echo "Skipping update"
fi

# Second integrity check of properties.json, in case we updated it
if [ $updated -eq 1 ]; then
  [ $opt_Verbose -eq 1 ] && echo "Updating file information"
  [ -f "$properties_json" ] && [ -s "$properties_json" ] && jq empty $properties_json &> /dev/null
  retVal=$?
  if [ $retVal -ne 0 ]; then
    [ $opt_Verbose -eq 1 ] && echo "Error parsing properties.json, exiting!"
    exit 1
  fi
  # Update data age
  mills=$(jq -r '.bgnow.mills' $properties_json)
  age=$(($(date +%s%N | cut -b1-10) - ${mills::-3}))
  age_mins=$(secs2mins $age)
fi

unlock_instance

for request in "${arr_requests[@]}"
do
  [ $opt_Verbose -eq 1 ] && echo "Fetching $request"
  if [[ $request == "!time-ago" ]]; then
    [ $opt_Verbose -eq 1 ] && echo "Age of data: $age_mins minutes ($age seconds)"
    result=$age_mins
  elif [[ $request == "!reservoir-percent" ]]; then
    resU=$(jq -r '.pump.pump.reservoir' $properties_json)
    result=$(awk -vn=$resU 'BEGIN{printf("%.0f\n",n/1000*315)}')
  elif [[ $request == "!tbr-percent" ]]; then
    abs=$(jq -r '.pump.pump.extended.TempBasalAbsoluteRate' $properties_json)
    base=$(jq -r '.pump.pump.extended.BaseBasalRate' $properties_json)
    result=$(awk -vabs=1.8 -vbase=1.55 'BEGIN{printf("%.0f\n",100/base*abs)}')
  else
    result=$(jq -r $request $properties_json)
  fi

  if [[ $request == ".pump.pump.extended.TempBasalAbsoluteRate" ]]; then
    result=$(LC_NUMERIC="en_US.UTF-8" printf "%.*f\n" "2" "${result}")
  fi
  echo $result
done

exit 0



