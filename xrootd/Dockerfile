FROM alisw/slc7-builder
COPY installer.sh /
RUN /bin/bash installer.sh
ADD xrootd-conf /etc/xrootd
USER xrootd
ENV TTOKENAUTHZ_AUTHORIZATIONFILE='/jalien-dev/TkAuthz.Authorization'
