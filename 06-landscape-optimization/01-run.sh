#!/bin/bash

FUEL_INPUT_FILE=""
WX_INPUTS_FILE=wx.csv
SIMULATION_TSTOP=22200.0  # Simulation stop time (seconds)

while [[ $# -gt 0 ]]; do
  case $1 in
    -f | --fuel_file)
        echo "Processing 'fuel_file' option. Input argument is '$2'"
        FUEL_INPUT_FILE="$2"
        shift 2
        ;;
    -w | --wind_file)
        echo "Processing 'wind_file' option. Input argument is '$2'"
        WX_INPUTS_FILE="$2"
        shift 2
        ;;
    -s | --simulation_tstop)
        echo "Processing 'simulation_tstop' option. Input argument is '$2'"
        SIMULATION_TSTOP=$2
        shift 2
        ;;
    -*|--*)
      echo "Unknown option $1"
      shift
      ;;
  esac
done

ELMFIRE_VER=${ELMFIRE_VER:-2023.1015}

SCRIPTDIR=`dirname "$0"`

. $SCRIPTDIR/../functions/functions.sh

SCRATCH=./scratch
INPUTS=./inputs
OUTPUTS=./outputs
MISC=./misc

rm -f -r $SCRATCH $INPUTS $OUTPUTS $MISC
mkdir $SCRATCH $INPUTS $OUTPUTS $MISC
cp $SCRIPTDIR/elmfire.data.in $INPUTS/elmfire.data
cp $ELMFIRE_BASE_DIR/build/source/fuel_models.csv $MISC

echo tar -xvf $FUEL_INPUT_FILE -C $INPUTS
tar -xvf $FUEL_INPUT_FILE -C $INPUTS
rm -f $INPUTS/m*.tif $INPUTS/w*.tif $INPUTS/l*.tif $INPUTS/ignition*.tif $INPUTS/forecast_cycle.txt

XMIN=`gdalinfo $INPUTS/fbfm40.tif | grep 'Lower Left'  | cut -d'(' -f2 | cut -d, -f1 | xargs`
YMIN=`gdalinfo $INPUTS/fbfm40.tif | grep 'Lower Left'  | cut -d'(' -f2 | cut -d, -f2 | cut -d')' -f1 | xargs`
XMAX=`gdalinfo $INPUTS/fbfm40.tif | grep 'Upper Right' | cut -d'(' -f2 | cut -d, -f1 | xargs`
YMAX=`gdalinfo $INPUTS/fbfm40.tif | grep 'Upper Right' | cut -d'(' -f2 | cut -d, -f2 | cut -d')' -f1 | xargs`
XCEN=`echo "0.5*($XMIN + $XMAX)" | bc`
YCEN=`echo "0.5*($YMIN + $YMAX)" | bc`
A_SRS=`gdalsrsinfo $INPUTS/fbfm40.tif | grep PROJ.4 | cut -d: -f2 | xargs` # Spatial reference system
CELLSIZE=`gdalinfo $INPUTS/fbfm40.tif | grep 'Pixel Size' | cut -d'(' -f2 | cut -d, -f1` # Grid size in meters
#TR="$CELLSIZE $CELLSIZE"
#TE="$XMIN $YMIN $XMAX $YMAX"

gdalwarp -multi -dstnodata -9999 -tr 300 300 $INPUTS/adj.tif $SCRATCH/dummy.tif
gdal_calc.py -A $SCRATCH/dummy.tif --NoDataValue=-9999 --type=Float32 --outfile="$SCRATCH/float.tif" --calc="A*0.0"

# Create transient float input rasters
COLS=`head -n 1 $WX_INPUTS_FILE | tr ',' ' '`
tail -n +2 $WX_INPUTS_FILE > $SCRATCH/wx.csv
NUM_TIMES=`cat $SCRATCH/wx.csv | wc -l`

ICOL=0
for QUANTITY in $COLS; do
   let "ICOL = ICOL + 1"
   TIMESTEP=0
   FNLIST=''
   while read LINE; do
      VAL=`echo $LINE | cut -d, -f$ICOL`
      FNOUT=$SCRATCH/${QUANTITY}_$TIMESTEP.tif
      FNLIST="$FNLIST $FNOUT"
      gdal_calc.py -A $SCRATCH/float.tif --NoDataValue=-9999 --type=Float32 --outfile="$FNOUT" --calc="A + $VAL" >& /dev/null &
      let "TIMESTEP=TIMESTEP+1"
   done < $SCRATCH/wx.csv
   wait
   gdal_merge.py -separate -n -9999 -init -9999 -a_nodata -9999 -co "COMPRESS=DEFLATE" -co "ZLEVEL=9" -o $INPUTS/$QUANTITY.tif $FNLIST
done

# Set inputs in elmfire.data
replace_line COMPUTATIONAL_DOMAIN_XLLCORNER $XMIN no
replace_line COMPUTATIONAL_DOMAIN_YLLCORNER $YMIN no
replace_line COMPUTATIONAL_DOMAIN_CELLSIZE $CELLSIZE no
replace_line SIMULATION_TSTOP $SIMULATION_TSTOP no
replace_line DTDUMP $SIMULATION_TSTOP no
replace_line A_SRS "$A_SRS" yes
replace_line 'X_IGN(1)' $XCEN no
replace_line 'Y_IGN(1)' $YCEN no

# Execute ELMFIRE
elmfire_$ELMFIRE_VER ./inputs/elmfire.data

# Postprocess
for f in ./outputs/*.bil; do
   gdal_translate -a_srs "$A_SRS" -co "COMPRESS=DEFLATE" -co "ZLEVEL=9" $f ./outputs/`basename $f | cut -d. -f1`.tif
done
#gdal_contour -i 3600 `ls ./outputs/time_of_arrival*.tif` ./outputs/hourly_isochrones.shp

# Clean up and exit:
rm -f -r ./outputs/*.bil ./outputs/*.hdr $SCRATCH $MISC

exit 0
