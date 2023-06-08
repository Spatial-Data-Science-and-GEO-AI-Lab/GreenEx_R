
# GreenExp

<!-- badges: start -->
<!-- badges: end -->
- [Updates](#updates)
- [Installation](#installation)
  * [GEE](#gee)
  * [Rcpp](#rcpp)
- [Functions](#functions)
  * [Availability](#availability)
    + [Calc NDVI](#calc-ndvi)
    + [Land Cover](#land-cover)
    + [Canopy coverage](#canopy-coverage)
    + [Park percentage](#park-percentage)
  * [Accessibility](#accessibility)
    + [Park access](#park-access)
  * [Visibility](#visibility)
    + [Viewshed](#viewshed)
    + [VGVI](#vgvi)
    + [Streetview](#streetview)


# Updates

Over here are the agreements that need to be done this week:

- Make sure the epsg logic is fixed for each function
- Make the accessibility function faster by intersecting the the buffer for the pseudo entrances and for the euclidean buffer, use the nearest neighbours. 
- Start with the motivation of the paper see [overleaf](www.overleaf.com)
- Make a visibility function for the buffer around the address location. Important to take random points in this buffer and use the [VGVI](#vgvi) Function to implement this. 

# Installation

You can install the development version of GreenExp from [GitHub](https://github.com/) with:

``` r
# install.packages("devtools")
devtools::install_github("Spatial-Data-Science-and-GEO-AI-Lab/GreenEx_R")
```

To make optimal use of the package 

## GEE 

This step is optional, by default the [Planetary Computer](https://planetarycomputer.microsoft.com) will be used for satellite images, 
But if you also want to use the [Google Earth Engine](https://earthengine.google.com), and do not have it installed yet,
you need to follow the following steps or the steps given in this [instruction video](https://www.youtube.com/watch?v=_fDhRL_LBdQ)

**Step 1:**

Make an account on  [Google Earth Engine](https://earthengine.google.com)


``` r
install.packages(c("sf", "reticulate", "remotes"))
```
afterwards install the [rgee](https://github.com/r-spatial/rgee) package from github

``` r
# Install the rgee package from the r spatial GitHub
remotes::install_github("r-spatial/rgee")

# load the reticulate and rgee package
library(reticulate)
library(rgee)
```

**Step 2:**

Running `reticulate::py_discover_config()` will install `Miniconda`

``` r
# Use the py_discover_config() function to see what version of Python will be used
# without actually loading pythong
reticulate::py_discover_config()

# python:         /Users/martijn/.virtualenvs/rgee/bin/python
# libpython:      /Users/martijn/anaconda3/lib/libpython3.10.dylib
# pythonhome:     /Users/martijn/.virtualenvs/rgee:/Users/martijn/.virtualenvs/rgee
# version:        3.10.9 (main, Mar  1 2023, 12:20:14) [Clang 14.0.6 ]
# numpy:          /Users/martijn/.virtualenvs/rgee/lib/python3.10/site-packages/numpy
# numpy_version:  1.24.3

# Verify the current Python path
import('sys')$executable
# [1] "/Users/martijn/.virtualenvs/rgee/bin/python"


# Create an isolated Python venv with all rgee dependencies
ee_install()
# look at the path to the rgee env
```

**Step 3:**

After this bit, please restart your pc/laptop and launch R again. 

**Step 4:**

Initializing

``` r
# Set python version to use
reticulate::use_python("/Users/martijn/.virtualenvs/rgee/bin/python")
reticulate::py_config()

library(rgee)

#Initialize the Earth Engine
ee_Initialize()

## 2. Install geemap in the same Python ENV that use rgee
py_install("geemap")
gm <- import("geemap")

```

Enter the email you used to sign-up for GEE 

copy the code into R 

── rgee 1.1.6.9999 ───────────────────────────────────── earthengine-api 0.1.354 ── 

 ✔ user: not_defined 
 
 ✔ Initializing Google Earth Engine:  DONE!
 
 ✔ Earth Engine account: users/ee-greenexp 
 
---

## Rcpp 

Make sure the [Rcpp package](https://cran.r-project.org/web/packages/Rcpp/index.html) is installed.
If you are using mac, make sure you have [Xcode](https://apps.apple.com/nl/app/xcode/id497799835?mt=12) installed. 

Furthermore you have to make a Makevars file if the cpp files are not working. 
go to terminal and do the following:

```
mkdir .R
cd .R 
touch Makevars
open Makevars

## copy and paste:
FC = /opt/homebrew/Cellar/gcc/13.1.0/bin/gfortran
F77 = /opt/homebrew/Cellar/gcc/13.1.0/bin/gfortran
FLIBS = -L/opt/homebrew/Cellar/gcc/13.1.0/lib/gcc/13
```
---

## Mapillary

To use the [streetview](#streetview) function, data will be retrieved using the [mapillary](https://www.mapillary.com) API

---

# Functionalities 

---

## Availability

Availability will be assessed using four functions:

1. [Calc NDVI](#calc-ndvi)
2. [Land Cover](#land-cover)
3. [Canopy coverage](#canopy-coverage)
4. [Park percentage](#park-percentage) 

Each of these functions will provide an [sf](https://r-spatial.github.io/sf/articles/sf1.html) `dataframe` that includes the input location and the specific values requested within a defined buffer.

By default, the buffer around the input location is measured in Euclidean distance. However, it can be modified to utilize a network buffer. The distinction between the two types of buffers is illustrated in the figure below. The Euclidean buffer in this instance has a fixed radius of 1000 meters, while the network buffer is calculated based on a speed of 5 km/h over a duration of 10 minutes.

![](man/figures/buffers_example.png)


In the following subsections, a brief description of each availability function will be provided, along with examples extracted from random data points in Amsterdam.

---

### Calc NDVI 

The `calc_ndvi` function computes the average Normalized Difference Vegetation Index [(NDVI)](https://en.wikipedia.org/wiki/Normalized_difference_vegetation_index) within a specified distance for given location(s). The input for the function is `address_location` which should be an `sf dataframe`. It is recommended to provide the `address location` with a projected Coordinate Reference System [(CRS)](https://docs.qgis.org/3.28/en/docs/gentle_gis_introduction/coordinate_reference_systems.html#:~:text=In%20layman%27s%20term%2C%20map%20projections,real%20places%20on%20the%20earth). If no projected CRS is provided, the address location will be automatically projected to [WGS 84 / World Mercator](https://epsg.io/3395)

You have the option to provide a raster file containing NDVI values. However, if no raster file is provided, the function will use the [Sentinel-2-l2a](https://planetarycomputer.microsoft.com/dataset/sentinel-2-l2a) dataset from Planetary Computer as the default data source for calculating NDVI. The figure below illustrates an example of NDVI in Amsterdam. It showcases three address locations within a Euclidean buffer of 300 meters

![](man/figures/ndvi_pc_plot_eucbuffer.png)

If desired, users are able to switch the engine to `GEE` (Google Earth Engine) for performing the calculations

---

Below you can find the code where the results correspond with the NDVI figure. 

``` r
GreenExp::calc_ndvi(address_3, buffer_distance = 300)
# Euclidean distance will be used to calculate the buffers around the address location that is given
# Sentinel-2-l2a data is used to retrieve the ndvi values. 
#  The ID of the selected image is: S2B_MSIL2A_20200922T104649_R051_T31UFU_20201028T024449
#  The date of the picture that was taken is: 2020-09-22T10:46:49.025000Z
#  The cloud cover of this day was 0.149568% 
# Simple feature collection with 3 features and 2 fields
# Geometry type: POINT
# Dimension:     XY
# Bounding box:  xmin: 118231.8 ymin: 487636.8 xmax: 119718.2 ymax: 488790.5
# Projected CRS: Amersfoort / RD New
#   ID mean_NDVI                  geometry
# 1  1 0.4083971 POINT (118231.8 487636.8)
# 2  2 0.4953944 POINT (119718.2 488790.5)
# 3  3 0.2616829 POINT (119659.3 487693.7)
```

---

### Land Cover

The `land_cover` function calculates the percentage of area covered by each land cover class within a given buffer distance. Again, the input for the function is `address_location` which should be a `sf dataframe`. 

It is possible to provide a raster file with land cover values, but if that is not provided, the [esa-worldcover](https://planetarycomputer.microsoft.com/dataset/esa-worldcover) data set of Planetary Computer will be used to calculate the land cover (see Figure below for an example of land cover in Amsterdam)

![](man/figures/land_cover_network_buffer.png) 

In this instance I will use a network buffer to calculate the land cover values for the address locations.
The [osmextract](https://cran.r-project.org/web/packages/osmextract/vignettes/osmextract.html) package will be used to get the networks, if a network file is not given. 

``` r
GreenExp::land_cover(address_location, buffer_distance=500, network_buffer=T)
# You will use a network to create a buffer around the address location(s),
#               Keep in mind that for large files it can take a while to run the funciton.
# You did not provide a network file, osm will be used to create a network file.
# If a city is missing, it will take more time to run the function
# The input place was matched with Noord-Holland. 
# The chosen file was already detected in the download directory. Skip downloading.
# Start with the vectortranslate operations on the input file!
# 0...10...20...30...40...50...60...70...80...90...100 - done.
# Finished the vectortranslate operations on the input file!
# Reading layer `lines' from data source 
#   `/private/var/folders/ll/vl2jqx3s46189vcv3w8mdgyh0000gn/T/RtmpBIu31i/geofabrik_noord-holland-latest.gpkg' 
#   using driver `GPKG'
# Simple feature collection with 3473 features and 9 fields
# Geometry type: LINESTRING
# Dimension:     XY
# Bounding box:  xmin: 4.757481 ymin: 52.32693 xmax: 4.881442 ymax: 52.40028
# Geodetic CRS:  WGS 84
# Simple feature collection with 3 features and 12 fields
# Geometry type: POINT
# Dimension:     XY
# Bounding box:  xmin: 118231.8 ymin: 487636.8 xmax: 119718.2 ymax: 488790.5
# Projected CRS: Amersfoort / RD New
#   UID                  geometry tree_cover shrubland grassland cropland built-up
# 1   1 POINT (118231.8 487636.8)       0.39         0      0.02        0     0.52
# 2   2 POINT (119718.2 488790.5)       0.24         0      0.05        0     0.57
# 3   3 POINT (119659.3 487693.7)       0.07         0      0.03        0     0.87
#   bare_vegetation snow_ice perm_water_bodies herbaceous_wetland mangroves moss_lichen
# 1               0        0              0.07                  0         0           0
# 2               0        0              0.14                  0         0           0
# 3               0        0              0.03                  0         0           0
```

---

### Canopy coverage

The `canopy_perc` function calculates the percentage of a canopy within a given buffer distance or location. 

``` r
# Read the canopy dataset
canopy <- sf::st_read("Data/CanopyTestArea.gpkg")

canopy_perc(address_location = address_test, canopy_layer = canopy, buffer_distance = 500)
 

# Simple feature collection with 3 features and 2 fields
# Geometry type: POINT
# Dimension:     XY
# Bounding box:  xmin: 385981.9 ymin: 392861.6 xmax: 388644.2 ymax: 395322.2
# Projected CRS: OSGB36 / British National Grid
#   UID canopy_pct                  geometry
# 1   1   14.42063 POINT (388644.2 392861.6)
# 2   2   19.27852 POINT (385981.9 393805.5)
# 3   3   10.67145 POINT (388631.2 395322.2)
```

---

### Park percentage

The `park_pct` function gives the percentage of park coverage given a certain buffer. If the `park_layer` is not given, the parks will be retrieved using features from [osmdata](https://wiki.openstreetmap.org/wiki/Map_features). 

``` r
GreenExp::park_pct(address_location, buffer_distance=300)
# Simple feature collection with 3 features and 2 fields
# Geometry type: POINT
# Dimension:     XY
# Bounding box:  xmin: 385981.9 ymin: 392861.6 xmax: 388644.2 ymax: 395322.2
# Projected CRS: OSGB36 / British National Grid
#   UID   park_pct                  geometry
# 1   1  3.6795963 POINT (388644.2 392861.6)
# 2   2 10.9080537 POINT (385981.9 393805.5)
# 3   3  0.1408044 POINT (388631.2 395322.2)

```

---

## Accessibility

### Park access

In the `parks_access` functions, the nearest parks for the given address locations will be created and whether these parks are within a given buffer distance. To calculate the distance to the parks, fake entry points are created. These fake entrances are created by making a buffer of 20 meter around the park polygon. this buffer is intersected with the intersection nodes which is created by intersecting the network points created with the parks. 


``` r
parks_access(address_location, buffer_distance=350)
# You did not provide a network file, a network will be created using osm.
# If a city is missing, it will take more time to run the function
# The input place was matched with Greater Manchester. 
#   |===============================================================================| 100%
# File downloaded!
# Start with the vectortranslate operations on the input file!
# 0...10...20...30...40...50...60...70...80...90...100 - done.
# Finished the vectortranslate operations on the input file!
# Simple feature collection with 3 features and 3 fields
# Geometry type: POINT
# Dimension:     XY
# Bounding box:  xmin: 385981.9 ymin: 392861.6 xmax: 388644.2 ymax: 395322.2
# Projected CRS: OSGB36 / British National Grid
#   UID closest_park parks_in_buffer                  geometry
# 1   1     264.6468            TRUE POINT (388644.2 392861.6)
# 2   2     167.2045            TRUE POINT (385981.9 393805.5)
# 3   3     278.6349            TRUE POINT (388631.2 395322.2)
```



---

## Visibility
 
The visibility functions are made by the [GVI](https://github.com/STBrinkmann/GVI) package with some adaptations. 

---

### Viewshed

The viewshed function computes a binary viewshed of a single point on a Digital Surface Model (DSM) raster. A radial buffer is applied on the observer position, and visibility is being calculated usig a C++ implementation of Bresenham’s line algorithm [Bresenham 1965](https://ieeexplore.ieee.org/document/5388473) & [Bresenham 1977](https://doi.org/10.1145/359423.359432) and simple geometry. The
result of the `viewshed` function is a radial raster where 0 =
no-visible and 1 = visible area.

For a better explanation, go to the [GVI](https://github.com/STBrinkmann/GVI) package.

**EXAMPLE**

Data can be retrieved from this [site](https://zenodo.org/record/5061257). 

```r
# Read in the digital eleveation model
DEM <- terra::rast('data/GreaterManchester_DTM_5m.tif')
# Read the digital surfaca model
DSM <- terra::rast('data/GreaterManchester_DSM_5m.tif')
# Read the greenspace 
GS <- terra::rast('data/GreaterManchester_GreenSpace_5m.tif')

# 
observer <- sf::st_sf(sfheaders::sf_point(c(388644.2, 392862.7)), crs = sf::st_crs(terra::crs(DEM)))

vs <- GreenExp::viewshed(observer = observer, dsm_rast = DSM, dtm_rast = DEM,
                         max_distance = 200, observer_height = 1.7, plot = TRUE)
```


![](man/figures/viewshed.png)

The left plot represents the Digital Elevation Model (DEM), whereas the right plot represents the viewshed, where green is the visibile area and gray is not visible. 

### VGVI

The Viewshed Greenness Visibility Index (VGVI) represents the proportion of visibile greeness to the total visible area based on the `viewshed`. The estimated VGVI values range between 0 and 1, where = no green cells and 1= all of the visible cells are green.

Based on a viewshed and a binary greenspace raster, all visible points are classified as visible green and visible no-green. All values are summarized using a decay function, to account for the reducing visual prominence of an object in space with increasing distance from the observer. Currently two options are supported, a logistic and an exponential function.

For more information about the VGVI please go to the [GVI](https://github.com/STBrinkmann/GVI) package. For more information about the algorithms look at the paper by [Brinkmann, 2022](https://doi.org/10.5194/agile-giss-3-27-2022)

```r
VGVI <- vgvi_from_sf(observer = observer,
             dsm_rast = DSM, dtm_rast = DEM, greenspace_rast = GS,
             max_distance = 200, observer_height = 1.7,
             m = 0.5, b = 8, mode = "logit")
# Simple feature collection with 1 feature and 2 fields
# Geometry type: POINT
# Dimension:     XY
# Bounding box:  xmin: 388644.2 ymin: 392862.7 xmax: 388644.2 ymax: 392862.7
# Projected CRS: OSGB36 / British National Grid
#   id      VGVI                  geometry
# 1  1 0.3177667 POINT (388644.2 392862.7)
```

--- 

### streetview 

