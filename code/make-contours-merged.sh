#! /usr/bin/env bash

start=`date +%s`
temp_dir=$(mktemp -d)

# -q         : quiet mode
# -r         : resample method = cubicspline
# -t_srs     : CRS of data
# -ot        : data type
# -dstnodata : no data value
# -multi     : use multi processes to run gdalwarp
gdalwarp \
    -q \
    -r cubicspline \
    -t_srs EPSG:4326 \
    -ot Int16 \
    -dstnodata -32768 \
    -multi \
    data/vrt/merged.vrt ${temp_dir}/test_wgs84.vrt

# convert to feet
gdal_translate \
    -q \
    -scale 0 0.3048 0 1 \
    ${temp_dir}/test_wgs84.vrt ${temp_dir}/test_wgs84_feet.vrt

# -a:       name of the attribute to store data
# -i:       contour interval to generate
# -f:       output format geopackage
gdal_contour \
    `# Put elevation values into 'ele_ft'` \
    -a ele_ft \
    `# Generate contour line every 40 feet` \
    -i 40 \
    `# Export to newline-delimited GeoJSON, so Tippecanoe can read in parallel` \
    -f GPKG \
    ${temp_dir}/test_wgs84_feet.vrt data/contour.gpkg

# -sql      : select, cast attributes to include (and only those attributes)
# -nln      : new layer name = contours
# -simplify : threshold to simplify the geometries by, in the source unit of measure
# -f        : output format, GeoJSONSeq for parallelization in tippecanoe
ogr2ogr \
    -sql "select cast(ele_ft as integer) AS ele_ft, geom from contour" \
    -nln "contours" \
    -simplify 0.00003 \
    -f GeoJSONSeq data/contours.geojson \
    data/contour.gpkg

# Create vector tiles with tippecanoe
# -Z, -z: set min, max zooms
# -P:     run in parallel
# -y:     only incude the ele_ft attribute
# -l:     layer name = contours
# -C:     filter the layers based contour level at different zooms
tippecanoe \
    -Z11 -z13 \
    -P \
    -y ele_ft \
    -l contours \
    -C './code/imperial-prefilter.sh "$@"' \
    -o data/contours.mbtiles \
    data/contours.geojson


end=`date +%s`
runtime=$((end-start))
echo $runtime