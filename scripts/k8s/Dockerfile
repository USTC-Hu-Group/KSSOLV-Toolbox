ARG BASE_IMAGE=kssolv-toolbox:plot-startup-fix
FROM ${BASE_IMAGE}
COPY portal/ /opt/kssolv/portal/
COPY manuals/ /opt/kssolv/portal/manuals/
ENV KSSOLV_PORTAL_CONFIG=/etc/kssolv/config.json
ENTRYPOINT ["/usr/bin/tini", "--", "python3", "/opt/kssolv/portal/portal.py"]
