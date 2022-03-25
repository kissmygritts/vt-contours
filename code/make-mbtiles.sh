#! /usr/bin/env bash

path=$1
out_dir="data/mbtiles-feet"

# get filename without extension
filename=$(basename -- "${path}")
extension="${filename##*.}"
filename="${filename%.*}"
out_filename="$out_dir/$filename.mbtiles"

# Run tippecanoe on 40ft contours
tippecanoe \
    `# Set min zoom to 11` \
    -Z11 \
    `# Set max zoom to 13` \
    -z13 \
    `# Read features in parallel; only works with GeoJSONSeq input` \
    -P \
    `# Keep only the ele_ft attribute` \
    -y ele_ft \
    `# Put contours into layer named 'contour_40ft'` \
    -l contour_40ft \
    `# Export to contour_40ft.mbtiles` \
    -o $out_filename \
    $path
