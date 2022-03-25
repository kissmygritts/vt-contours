CPUS=4

get-url-list:
	./code/get-tnm-urls.sh

stage-vrt:
	mkdir data/vrt
	cat data/tnm-url-list.txt | sed 's/^/\/vsicurl\//' | xargs -L1 ./code/make-vrt.sh
	gdalbuildvrt data/vrt/merged.vrt data/vrt/*.vrt

create-contours-feet:
	find data/vrt/ -type f -name '*.vrt' | xargs -P $(CPUS) -L1 ./code/make-contours-feet.sh

merged-mbtiles:
	bash ./code/make-contours-merged.sh

mbtiles-feet:
	mkdir -p data/mbtiles-feet
	find data/contour_40ft/ -type f -name '*.geojson' -print0 |\
		xargs -P 0 -0 -L1 ./code/make-mbtiles.sh

merge-mbtiles:
	tile-join -o data/contours-feet.mbtiles data/mbtiles-feet/*.mbtiles

tippecanoe:
	tippecanoe -Z11 -z13 \
		-P -y ele_ft -l contour-feet \
		-o data/contour-feet.mbtiles \
		data/contour_40ft/USGS_1_n39w121.geojson

clean:
	rm -rf data/contour_40ft