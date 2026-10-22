ARG RUNTIME_IMAGE=containers.mathworks.com/matlab-runtime:r2026b
FROM ${RUNTIME_IMAGE}
USER root
RUN apt-get update && apt-get install -y --no-install-recommends nginx-light python3 tini xvfb \
    && rm -rf /var/lib/apt/lists/* \
    && groupadd --gid 10001 kssolv \
    && useradd --uid 10001 --gid 10001 --no-create-home kssolv \
    && mkdir -p /data/home /data/preferences /data/work /data/cache/runtime /tmp/kssolv \
    && chown -R 10001:10001 /data /tmp/kssolv
COPY app/ /opt/kssolv/app/
COPY runtime/ /opt/kssolv/
ENV HOME=/data/home MATLAB_PREFDIR=/data/preferences \
    KSSOLV_USER_DATA_DIR=/data/preferences/KSSOLV_Toolbox \
    MCR_CACHE_ROOT=/data/cache/runtime KSSOLV_HOST_IN_BROWSER=true KSSOLV_ONLINE=true \
    KSSOLV_BROWSER_SESSION_FILE=/tmp/kssolv/session.json DISPLAY=:99
USER 10001:10001
# On an empty Kubernetes PVC, the container engine would create a missing
# WORKDIR as root. The unprivileged supervisor creates /data/work instead.
WORKDIR /data
EXPOSE 8080
STOPSIGNAL SIGTERM
HEALTHCHECK --interval=30s --timeout=5s --start-period=300s \
    CMD ["python3", "/opt/kssolv/serve.py", "--healthcheck"]
ENTRYPOINT ["/usr/bin/tini", "--", "python3", "/opt/kssolv/serve.py"]
