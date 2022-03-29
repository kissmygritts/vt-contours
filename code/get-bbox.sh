#! /usr/bin/env bash

INFO=$1
extent=$(echo "$INFO" | grep -oP '(?<=Extent:\W).*')
extent_arr=($(echo "$extent" | grep -oP '\-?\d*\.?\d+'))

echo ${extent_arr[0]} ${extent_arr[1]} ${extent_arr[2]} ${extent_arr[3]}
