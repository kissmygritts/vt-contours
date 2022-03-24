get-url-list:
	./code/get-tnm-urls.sh

stage-vrt:
	mkdir data/vrt
	cat data/tnm-url-list.txt | sed 's/^/\/vsicurl\//' | xargs -L1 ./code/make-vrt.sh

create-contours-feet:
	cpus=4
	find data/vrt/ -type f -name '*.vrt' | xargs -P $cpus -L1 ./code/make-contours-feet.sh

mbtile-feet:
	tippecanoe -Z11 -z13 -P -y ele_ft -l contour-feet -o data/contour-feet.mbtiles data/contour_40ft/USGS_1_n39w121.geojson

clean:
	rm -rf data/contour_40ft