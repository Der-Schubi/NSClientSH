#!/bin/bash
. nsclientsh.conf

# Init options
opt_Verbose=0
opt_SkipUpdate=0
opt_ForceUpdate=0
updated=0
declare arr_requests=()
result=""

get_entries_json() {
  #rm $entries_json
  wget $ns_url/api/v2/entries.json?count=36\&token=$token -qO $entries_json 2> /dev/null
}

secs2mins() {
  ((h=${1}/3600))
  ((m=(${1}%3600)/60))
  echo $((($h/60)+$m))
}

[ -f "$entries_json" ] && [ -s "$entries_json" ] && jq empty $entries_json &> /dev/null
retVal=$?
if [ $retVal -ne 0 ]; then
  [ $opt_Verbose -eq 1 ] && echo "Error parsing entries.json"
  opt_SkipUpdate=0
  opt_ForceUpdate=1
fi

# Update entries.json
if [ $opt_SkipUpdate -ne 1 ]; then
  if [ $opt_ForceUpdate -eq 1 ]; then
    [ $opt_Verbose -eq 1 ] && echo "Forcing update"
    rm $entries_json
  fi

  if [ ! -f "$entries_json" ]; then
    [ $opt_Verbose -eq 1 ] && echo "Updating entries.json"
    get_entries_json
    updated=1
  else
    mills=$(jq -r '.[0].mills' $entries_json)
    age=$(($(date +%s%N | cut -b1-10) - ${mills::-3}))
    age_mins=$(secs2mins $age)
    [ $opt_Verbose -eq 1 ] && echo "Age of data: $age_mins minutes ($age seconds)"
    if [ "$age_mins" -gt "4" ]; then
      [ $opt_Verbose -eq 1 ] && echo "Updating entries.json"
      get_entries_json
      updated=1
    fi
  fi
elif [ $opt_Verbose -eq 1 ]; then
  echo "Skipping update"
fi

# Second integrity check of entries.json, in case we updated it
if [ $updated -eq 1 ]; then
  [ $opt_Verbose -eq 1 ] && echo "Updating file information"
  [ -f "$entries_json" ] && [ -s "$entries_json" ] && jq empty $entries_json &> /dev/null
  retVal=$?
  if [ $retVal -ne 0 ]; then
    [ $opt_Verbose -eq 1 ] && echo "Error parsing entries.json, exiting!"
    exit 1
  fi
  # Update data age
  mills=$(jq -r '.[0].mills' $entries_json)
  age=$(($(date +%s%N | cut -b1-10) - ${mills::-3}))
  age_mins=$(secs2mins $age)
fi

[ $opt_Verbose -eq 1 ] && echo "Fetching requests (.[0..35].sgv)"
for (( c=0; c<=35; c++ )); do
  if [ -n "$result" ]; then
    result="${result},"
  fi
  request=".[$c].sgv"
  response=$(jq -r $request $entries_json)
  result="${result}$response"
done
echo $result
