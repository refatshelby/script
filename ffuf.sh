#!/bin/bash

output=""
exts=""
wordlist=""

while getopts ":u:w:a:o:e:h" opt; do
  case ${opt} in
    u) u=$OPTARG ;;
    w) wordlist=$OPTARG ;;
    a) add=$OPTARG ;;
    o) output="$OPTARG" ;;
    e) exts=$OPTARG ;;
    h)
      echo "Usage: $0 -u <url> -w <wordlist_path> [-e <extensions>] [-a <ffuf options>] [-o <output file>]"
      echo "  -u  Target URL with FUZZ"
      echo "  -w  Full path to wordlist (e.g., ~/wordlists/fuzz.txt)"
      echo "  -e  Extensions (e.g., .php,.bak) [optional]"
      echo "  -a  Additional ffuf options [optional]"
      echo "  -o  Output file name [optional]"
      exit 0
      ;;
    \?) echo "Invalid option: -$OPTARG" >&2; exit 1 ;;
    :) echo "Option -$OPTARG requires an argument." >&2; exit 1 ;;
  esac
done

if [[ -z "$u" || -z "$wordlist" ]]; then
  echo "Error: -u (URL) and -w (wordlist path) are required." >&2
  exit 1
fi

random=$RANDOM
temp_dir="/tmp/$random"
mkdir -p "$temp_dir"

# Build ffuf command
cmd=(ffuf -H "User-Agent: Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36" \
     -mc all -fc 404,400 \
     -w "$wordlist" -u "$u" \
     -o "$temp_dir/results.json" -od "$temp_dir/bodies/" -of json)

# Add extensions if provided
if [[ -n "$exts" ]]; then
  cmd+=(-e "$exts")
fi

# Add extra ffuf options if provided
if [[ -n "$add" ]]; then
  IFS=' ' read -r -a add_opts <<< "$add"
  cmd+=("${add_opts[@]}")
fi

# Run ffuf
"${cmd[@]}"

# Post-process results
ffufPostprocessing -result-file "$temp_dir/results.json" \
                   -bodies-folder "$temp_dir/bodies/" \
                   -new-result-file "$random.json"

# Format results
results=$(jq -r '"\(.config.method) \(.results[] | "\(.input.FUZZ) \(.url) \(.status) \(.length) \(.words) \(.lines) \(.redirectlocation)")"' "$random.json" | column -t | sort -k5,5nr)

# Output results
if [[ -n "$output" ]]; then
  [[ $output != *.txt ]] && output="$output.txt"
  echo "$results" | anew "$output"
else
  echo "$results"
fi

# Send notification
[[ -n "$results" ]] && echo -e "FFUF Scan Results for $u:\n\n$results" | notify -silent

# Cleanup
rm -rf "$random.json" "$temp_dir"
