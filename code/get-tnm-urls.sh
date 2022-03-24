#! /usr/bin/env bash

# read and parse configuration file into TNM API querystring
CONFIG_FILE="data/config.json"
BASE_URL="https://tnmaccess.nationalmap.gov/api/v1/products"

# initialize querystring for first iteration
querystring=$(cat $CONFIG_FILE | python3 -c "import urllib.parse, json, sys; x = json.loads(sys.stdin.read()); print(urllib.parse.urlencode(x, quote_via=urllib.parse.quote))")
url="${BASE_URL}?${querystring}"

# initialize current page and item total (which is unknown, so init as 1)
current_page=0
item_total=1

while [ $current_page -lt $item_total ]; do
    echo item_total: $item_total
    echo current_page: $current_page

    # send query to TNM API
    response=$(curl $url)

    # parse query response
    item_length=$(echo $response | jq '.items | length')
    echo $response | jq -r '.items | .[] | .urls.TIFF' >> urls.txt
    echo $response | jq '.messages'

    # increment variables
    ((current_page+=item_length))
    item_total=$(echo $response | jq '.total')

    # build querystring for next iteration
    querystring=$(echo $querystring | sed 's/&offset=.*//')
    querystring+="&offset=$current_page"
    url="${BASE_URL}?${querystring}"
done

# read urls.txt to create download url to download current
readarray -t url_arr < urls.txt
declare -a parsed_urls=()

# for each url in url_arr, parse 
# from: https://prd-tnm.s3.amazonaws.com/StagedProducts/Elevation/1/TIFF/historical/n35w114/USGS_1_n35w114_20211215.tif
# to  : https://prd-tnm.s3.amazonaws.com/StagedProducts/Elevation/1/TIFF/current/n35w114/USGS_1_n35w114.tif
for url in ${url_arr[@]}; do
    file_name=$(basename $url)
    grid_name=$(echo $url | grep -oP '(USGS_.*)(?=_\d*)')
    base_url=$(echo ${url%%$file_name} | sed 's/historical/current/g')
    final_url="$base_url$grid_name.tif"
    parsed_urls+=($final_url)
done

# remove duplicate urls
printf "%s\n" "${parsed_urls[@]}" | sort -u > data/tnm-url-list.txt

rm urls.txt