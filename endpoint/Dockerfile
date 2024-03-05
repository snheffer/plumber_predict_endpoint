# Use the official R base image with a stable version of R
FROM r-base:4.3.1 as builder

# Set environment variables
ENV CRAN_MIRROR=https://cran.r-project.org

# Install Requirements for Debian/Ubuntu.
RUN apt update && apt install -y \ 
libudunits2-dev \
libxml2 \
libxml2-dev \
libssl-dev \
libgdal-dev \
libfontconfig1-dev \
libcairo2-dev \
libharfbuzz-dev \
libfribidi-dev \
libsodium-dev \
curl

# Install renv package
RUN R -e "install.packages('renv', repos='$CRAN_MIRROR')"

# Copy the renv.lock and renv folder to the image
COPY renv.lock /app/renv.lock
COPY renv /app/renv

# Set the working directory
WORKDIR /app

# Restore the project environment using renv
RUN R -e "renv::restore(confirm=FALSE)"

# Copy your Plumber script to the image
COPY plumber_endpoint.R /app/plumber_endpoint.R
COPY entrypoint.R /app/entrypoint.R
COPY utilities /app/utilities

# Expose the API port
EXPOSE 8000

##Not Necessary As It's a Multi-Stage Build.
# RUN apt remove -y \ 
# libudunits2-dev \ 
# libssl-dev \
# libgdal-dev \
# libfontconfig1-dev \
# libcairo2-dev \
# libharfbuzz-dev \
# libfribidi-dev \
# libsodium-dev && apt clean

# ####### Multi Stage #######
FROM r-base:4.3.1

# #Copy app to alpine
COPY --from=builder /usr/local/lib/R/site-library/ /usr/local/lib/R/site-library
COPY --from=builder /usr/share/doc /usr/share/doc
COPY --from=builder /app /app
COPY --from=builder /usr/bin/curl /usr/bin/curl

RUN apt update && apt install -y \ 
libudunits2-dev \
libxml2 \
libxml2-dev \
libssl-dev \
libgdal-dev \
libfontconfig1-dev \
libcairo2-dev \
libharfbuzz-dev \
libfribidi-dev \
libsodium-dev \
curl

WORKDIR /app

# Expose the API port
EXPOSE 8000

# # Do a health check
# HEALTHCHECK --interval=1m --timeout=3s \
#   CMD curl -f http://localhost:8000/plumber/healthcheck || exit 1

# Run the Plumber API using Rscript
CMD ["/app/entrypoint.R"]