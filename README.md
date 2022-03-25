# vt-contours

Create vector tiles from USGS contours from The National Map. Heavily borrowed from Kyle Barron's [nst-guide/terrain](https://github.com/nst-guide/terrain).

## Usage

Clone this repository:

```shell
git clone https://github.com/kissmygritts/vt-contours.git
cd vt-contours
```

Install dependencies. This part is still a work in progress. Here is a list of the following dependencies. I've only tested this on Windows with WSL for now.

* `python3`
* `jq` - a command line JSON utility
* `gdal` - a geospatial CLI utility library
* `tippecanoe` - a CLI utility to create vector tiles

```shell
# python and jq can be installed with apt-get
sudo apt-get install python3 jq

# gdal requires a PPA for the most recent version this should install gdal 3.3.2 (as of 2022-03-25)
sudo add-apt-repository ppa:ubuntugis/ppa
sudo apt-get update
sudo apt-get install gdal-bin

ogrinfo --version    # test it installed

# tippecanoe 
cd ~    # <- change to whatever directory you install CLI tools
git clone https://github.com/mapbox/tippecanoe.git
cd tippecanoe
sudo make -j
sudo make install

tippecanoe --version    # test install worked
```

## USGS Contours

[Contours from the USGS are available](http://prd-tnm.s3.amazonaws.com/index.html?prefix=StagedProducts/Contours/), in a variety of format, at their staged products file server. However, the vector data available in these downloads have different contour intervals across 7.5 minute grids. In some areas 20ft contours are available, and in a grid cell right next to it 40ft contours are available. Not to mention, there national data clocks in at 120gb. 

We can go ahead and tile this data and deal with the differences across grids. Or, we can filter the contours to include only 40, or 200 foot contours.

## DEMs

We can genearate our own contours from DEMs as an alternative. The USGS provides 1, 1/3, and 1/9 arc second DEMS across the US [at the same staged products file server](http://prd-tnm.s3.amazonaws.com/index.html?prefix=StagedProducts/Elevation/). From Kyle's repo:

- **1 arc-second seamless DEM**. This has ~30m horizontal accuracy, which is accurate enough for many purposes, and gives it the smallest file sizes, making it easy to work with.
- **1/3 arc-second seamless DEM**. This dataset has the best precision available (~10m horizontal accuracy) for a seamless dataset. Note that the file sizes are about 9x bigger than the 1 arc-second data, making each 1x1 degree cell about 450MB unzipped.
- **1/9 arc-second project-based DEM and 1-meter project-based DEM**. These have very high horizontal accuracy, but aren't available for the entire US yet. If you want to use these datasets, go to the [National Map download page](https://viewer.nationalmap.gov/basic/), check "Elevation Products (3DEP)", and then click "Show Availability" under the layer you're interested in, so that you can see if they exist for the area you're interested in.

For testing purposes I've started using the 1 arc-second DEMs. They tile download and tile quickly.

### Stage Products

A lot of USGS' data is available at their [staged products server](http://prd-tnm.s3.amazonaws.com/index.html?prefix=). There are a few things to note about the elevation data. 

1. Data is available as GeoTIFF and jpg images. 
2. The data is gridded accross the US, see the [index.gpkg](http://prd-tnm.s3.amazonaws.com/index.html?prefix=StagedProducts/Elevation/1/TIFF/) for an overview of the grid.
3. Each cell in the grid is named with the following schema `n00w000`.
4. Depending on the dataset the directory structure will have the following:
    * **/current**: This has the most current DEM available. 
    * **/historic**: This will have, potentially, a few DEMs with the date published at the end
    * A directory for each grid with the most current DEM (Not in ever directory)

## The National Map API

We can use [The National Map API](https://apps.nationalmap.gov/tnmaccess/#/) to identify the download URLs for each DEM given a bounding box. I highly recommend testing out a few API calls with their [API query generator](https://apps.nationalmap.gov/tnmaccess/#/product) to better understand how it works. 

Note: as far as I can tell the API returns the download link to the historic DEMs, and I can't find a method to return the most current DEMs. I've done what I can in the code to get the most current DEM.

For example: to return the 1 arc-second DEMs for a bounding box around Lake Tahoe the query might look like the following:

`https://tnmaccess.nationalmap.gov/api/v1/products?bbox=-120.335,38.814,-119.775,39.293&datasets=National%20Elevation%20Dataset%20(NED)%201%20arc-second&prodExtents=1%20x%201%20degree`

Example Bounding boxes:

* NV 100km buffer bounding box : `-120.904,34.262,-113.141,42.666`
* Tahoe AOI bounding box       : `-120.335,38.814,-119.775,39.293`

## Code Overview

Most of the code is written as series of bash scripts in the hopes of making it as portable as possible. Some exceptions are a few lines of Python 3 and GDAL CLI commands. 

`get-tnm-urls.sh`

This bash script will make a (several) calls to The National Map API to to get the download URLs for each DEM. By default the TNM API returns 50 items at a time. This can be changed. If the total number of items available are greater than 50 then multiple calls to the API will be made. 

Once all the items have been fetched the URLs will be rewritten to point to the most current DEM. Any duplicate URLs will be removed. The resulting list will be save to a `data/tnm-url-list.txt` file. 

This script uses a config file (`data/config.json`) to configure the querstring for the API calls. The [example config file](data/config.json) will make the following request to the API: `https://tnmaccess.nationalmap.gov/api/v1/products?bbox=-120.335,38.814,-119.775,39.293&datasets=National%20Elevation%20Dataset%20(NED)%201%20arc-second&prodExtents=1%20x%201%20degree`. Before making modifications to the config make several calls to the TNM API to get an idea for how it works.

`make-vrt.sh`

This function will create a VRT for the given file. [A VRT](https://gdal.org/drivers/raster/vrt.) is a virtual format for GDAL. They are XML files that contain metadata about the original source data. A really nice features about VRTs is that the can be used to stack intermediate steps like reprojecting. 

VRTs can also be combined with the GDAL's virtual file system to point to network or compressed files. We can avoid downloading the source DEMs by pre-pending the URLs from `get-tnm-urls.sh` with `/vsicurl/`. If the files are compressed we can stack decompression with `/vsizip//vsicurl/`.

This script is called in the Makefile `stage-vrt` target like: `cat data/tnm-url-list.txt | sed 's/^/\/vsicurl\//' | xargs -L1 ./code/make-vrt.sh` I do it like this instead of including it in the create contours process so that we have the flexibility to use the same source DEMs to create metric contours, download the DEMs, or any number of other operations.

`make-contours-feet.sh`

Given an single input DEM (preferably a VRT created with `/vsicurl/`) this script will generate a [GeoJSONSeq](https://gdal.org/drivers/vector/geojsonseq.html) file of contours. Currently the script defaults to 40ft contours in feet. GeoJSONSeq is a file format that can be parallelized for input into tippecanoe.

I call this script in the make file with `xargs -P` to [parallelize](https://www.gnu.org/software/findutils/manual/html_node/find_html/Controlling-Parallelism.html) the creation of contours.