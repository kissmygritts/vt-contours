#! /usr/bin/env bash

start=`date +%s`

temp_dir=$(mktemp -d)

gdalwarp \
    -q \
    -r cubicspline \
    -t_srs EPSG:4326 \
    -ot Int16 \
    -dstnodata -32768 \
    -multi \
    data/vrt/merged.vrt ${temp_dir}/test_wgs84.vrt

gdal_translate \
    -q \
    -scale 0 0.3048 0 1 \
    ${temp_dir}/test_wgs84.vrt ${temp_dir}/test_wgs84_feet.vrt

gdal_contour \
    `# Put elevation values into 'ele_ft'` \
    -a ele_ft \
    `# Generate contour line every 40 feet` \
    -i 40 \
    `# Export to newline-delimited GeoJSON, so Tippecanoe can read in parallel` \
    -f GPKG \
    ${temp_dir}/test_wgs84_feet.vrt data/contour.gpkg

ogr2ogr -simplify 0.00003 -f GeoJSONSeq data/contour.geojson data/contour.gpkg

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
    -o data/test.mbtiles \
    data/contour.geojson


end=`date +%s`
runtime=$((end-start))
echo $runtime