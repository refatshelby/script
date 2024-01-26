#!/bin/bash

# Default output file
output=""

while getopts ":u:n:a:o:h" opt; do
  case ${opt} in
    u)
      u=$OPTARG
      ;;
    n)
      n=$OPTARG
      ;;
    a)
      add=$OPTARG
      ;;
    o)
      output="$OPTARG" # Set the output file based on the provided argument
      ;;
    h)
      echo "Usage: scriptname.sh -u <url> -n <number> -a <additional command> -o <output file>"
      exit 0
      ;;
    ?)
      echo "Invalid option: -$OPTARG" 1>&2
      exit 1
      ;;
    :)
      echo "Option -$OPTARG requires an argument." 1>&2
      exit 1
      ;;
  esac
done

random=$RANDOM

ffuf -H "User-Agent: Mozilla/5.0 (Windows NT 10.0; rv:91.0) Gecko/20100101 Firefox/91.0" -e / -mc all -fc 404,400 -w ~/wordlists/$n.txt -u $u -o /tmp/$random/results.json -od /tmp/$random/bodies/ -of json $add

ffufPostprocessing -result-file /tmp/$random/results.json -bodies-folder /tmp/$random/bodies/ -new-result-file $random.json

# Check if the -o option was provided
if [ -n "$output" ]; then
  # Ensure the output file has the ".txt" extension
  if [[ ! $output == *.txt ]]; then
    output="$output.txt"
  fi

  cat $random.json | jq -r '"\(.config.method) \(.results[] | "\(.input.FUZZ) \(.url) \(.status) \(.length) \(.words) \(.lines) \(.redirectlocation)")"' | column -t | sort -k5,5nr | anew "$output"
else
  # If -o was not used, print the output in the terminal
  cat $random.json | jq -r '"\(.config.method) \(.results[] | "\(.input.FUZZ) \(.url) \(.status) \(.length) \(.words) \(.lines) \(.redirectlocation)")"' | column -t | sort -k5,5nr
fi

# Clean up temporary files
rm -rf $random.json
rm -rf /tmp/$random