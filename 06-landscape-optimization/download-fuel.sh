#!/bin/bash

ELMFIRE_VER=${ELMFIRE_VER:-2023.1015}

. ../functions/functions.sh

# Get fuel data for a tile:
$ELMFIRE_BASE_DIR/cloudfire/fuel_wx_ign.py \
    --do_wx=False --do_ignition=False \
    --center_lon=-120.281 --center_lat=37.440 \
    --fuel_source='landfire' --fuel_version='2.2.0' \
    --outdir='.' --name='fuel'
