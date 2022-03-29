#! /usr/bin/env bash

ogr2ogr \
    # select necessary attributes
    -sql "select contourelevation as elevation, Shape from contour_modulo" \
    # coerce to XY, 2d coordinates
    -dim XY \
    # Apply a bit of geom simplification, in tests this reduced the file size by 1/5
    # with very little difference in the contours
    -simplify 0.00003 \
    # write as GeoJSONSeq for parallelization in tippecanoe
    -f GeoJSONSeq data/usgs-contours/usgs-contour.geojson \
    data/usgs-contours/contour_modulo.gpkg

# tile using tippecanoe
tippecanoe \
    `# Set min zoom to 11` \
    -Z11 \
    `# Set max zoom to 13` \
    -z13 \
    `# Read features in parallel; only works with GeoJSONSeq input` \
    -P \
    `# Keep only the ele_ft attribute` \
    -y elevation \
    `# Put contours into layer named 'contour_40ft'` \
    -l contour-feet \
    `# Export to contour_40ft.mbtiles` \
    -o data/usgs-contours/usgs-contours.mbtiles \
    data/usgs-contours/usgs-contour.geojson