#! /usr/bin/env bash
OUT_DIR="data/vrt"
path=$1

# get filename
filename=$(basename -- "${path}")
extension="${filename##*.}"
filename="${filename%.*}"

outfile="$OUT_DIR/$filename.vrt"

# create vrt
gdalbuildvrt -q \
    $outfile \
    $path