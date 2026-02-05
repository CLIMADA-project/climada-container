
ARG CLIMADA_VERSION=v4.0.0
ARG PETALS_VERSION=v4.0.1

FROM python:3.11-slim as base-slim

ENV APP_ROOT=/src

WORKDIR ${APP_ROOT}

RUN echo 'Europe/Zurich' > /etc/timezone && \
    ln -sfn /usr/share/zoneinfo/Europe/Zurich /etc/localtime

FROM base-slim as geospatial-extras

ENV SUMMARY="climada-container base image with installed geospatial Debian dependencies"

RUN apt-get update \
	&& apt-get install -y --no-install-recommends  \
    build-essential \
    libgdal-dev \
    libgeos-dev \
    libaec-dev \
    libeccodes-dev \
    && apt-get clean \
    && apt-get autoremove -y \
    && rm -rf /var/lib/apt/lists/*


FROM geospatial-extras AS prep

# Cache shapefiles for Cartopy for containers without internet access
RUN apt-get update && apt-get install -y --no-install-recommends unzip wget git
ARG SHAPEFILE_URL=https://naturalearth.s3.amazonaws.com
ARG BASE_PATH=cartopy-data/shapefiles/natural_earth
ARG NE_CULTURAL=$BASE_PATH/cultural
ARG NE_PHYSICAL=$BASE_PATH/physical
ARG TMP_FOLDER=tmp
RUN mkdir -p "$NE_CULTURAL" "$NE_PHYSICAL"

# Download and prepare shapefiles for countries
RUN wget $SHAPEFILE_URL/10m_cultural/ne_10m_admin_0_boundary_lines_land.zip -P $TMP_FOLDER  \
    && unzip $TMP_FOLDER/ne_10m_admin_0_boundary_lines_land.zip -d ${NE_CULTURAL}
RUN wget $SHAPEFILE_URL/10m_cultural/ne_10m_admin_0_countries.zip -P $TMP_FOLDER  \
    && unzip $TMP_FOLDER/ne_10m_admin_0_countries.zip -d ${NE_CULTURAL}
# Download and prepare shapefiles for states and provinces
RUN wget $SHAPEFILE_URL/10m_cultural/ne_10m_admin_1_states_provinces_lines.zip -P $TMP_FOLDER \
    && unzip $TMP_FOLDER/ne_10m_admin_1_states_provinces_lines.zip -d ${NE_CULTURAL}
# Download and prepare shapefiles for world coastlines
RUN wget $SHAPEFILE_URL/10m_physical/ne_10m_coastline.zip -P $TMP_FOLDER \
    && unzip $TMP_FOLDER/ne_10m_coastline.zip -d ${NE_PHYSICAL}
RUN dir -s
RUN echo $(ls -1 .)

# Download versions of CLIMADA
ARG GIT_FOLDER=climada_git
ARG CLIMADA_VERSION
ARG PETALS_VERSION
ARG TMP_CLIMADA=$GIT_FOLDER/tmp_climada
ARG TMP_PETALS=$GIT_FOLDER/tmp_petals
RUN mkdir -p "$TMP_CLIMADA" "$TMP_PETALS"
RUN git clone --depth 1 --branch ${CLIMADA_VERSION} https://github.com/CLIMADA-project/climada_python.git $TMP_CLIMADA \
    && git clone --depth 1 --branch ${PETALS_VERSION} https://github.com/CLIMADA-project/climada_petals.git $TMP_PETALS

# install poetry and install python environment
COPY pyproject.toml poetry.lock ./

RUN pip install --upgrade pip && \
    pip install "poetry>=1.6"

ENV PATH="/root/.local/bin:$PATH"

# save the specific python package versions from the poetry environment
RUN poetry export -f requirements.txt --output requirements.txt


FROM geospatial-extras AS climada-container-image-base

ARG CLIMADA_VERSION
ARG PETALS_VERSION
ENV VERSION=${CLIMADA_VERSION}_${PETALS_VERSION}

# The cartopy input is copied to the default location of data_dir, cf. cartopy.config['data_dir']
COPY --from=prep /src/cartopy-data /src/.local/share/cartopy

COPY --from=prep /src/requirements.txt /src/climada_container/requirements.txt
COPY --from=prep /src/climada_git/tmp_climada /src/climada_python
COPY --from=prep /src/climada_git/tmp_petals /src/climada_petals

# the specific python package versions are installed using pip
RUN cd /src/climada_container/ \
    && pip install --no-cache-dir --no-deps --require-hashes -r requirements.txt \
    && pip install --no-cache-dir --no-deps -e ../climada_python/. \
    && pip install --no-cache-dir --no-deps -e ../climada_petals/.

# Configure matplotlib configuration directory to be writable
ARG MATPLOTLIBDIR=/home/.config/matplotlib
RUN mkdir -p $MATPLOTLIBDIR
ENV MPLCONFIGDIR=$MATPLOTLIBDIR
RUN chgrp -R 0 $MATPLOTLIBDIR && chmod -R g=u $MATPLOTLIBDIR

WORKDIR /src


FROM climada-container-image-base AS climada-container-image-prod

CMD ["jupyter", "lab", "--ip", "0.0.0.0", "--no-browser", "--allow-root"]
