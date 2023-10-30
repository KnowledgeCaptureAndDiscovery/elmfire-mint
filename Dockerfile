FROM debian

RUN apt-get update && apt-get upgrade -y
RUN apt-get install -y bc csvkit gdal-bin gfortran jq libopenmpi-dev openmpi-bin python3 python3-pip pigz unzip wget zip git
RUN pip3 install --break-system-packages google-api-python-client python-dateutil
RUN pip3 install --break-system-packages grpcio grpcio-tools

RUN git clone https://github.com/lautenberger/elmfire.git

RUN mkdir /scratch

ENV ELMFIRE_SCRATCH_BASE=/scratch
ENV ELMFIRE_BASE_DIR=/elmfire
ENV ELMFIRE_INSTALL_DIR=$ELMFIRE_BASE_DIR/build/linux/bin
ENV CLOUDFIRE_SERVER=172.92.17.198
ENV PATH=$PATH:$ELMFIRE_INSTALL_DIR:$ELMFIRE_BASE_DIR/cloudfire

WORKDIR $ELMFIRE_BASE_DIR/build/linux
RUN ./make_gnu.sh

COPY 06-landscape-optimization /elmfire/tutorials/06-landscape-optimization
