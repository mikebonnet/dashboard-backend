FROM registry.fedoraproject.org/fedora:latest

ENV BACKEND_VERSION="0.1" \
    RENV_CONFIG_CACHE_ENABLED="FALSE" \
    RENV_PATHS_ROOT="/srv/dashboard-backend/renv/root" \
    R_CONFIG_ACTIVE="container" \
    DNF_CMD="dnf -y --setopt=deltarpm=false --setopt=install_weak_deps=false --setopt=tsflags=nodocs" \
    LANG=C.UTF-8

LABEL name="conscious-lang-dashboard-backend" \
      vendor="Red Hat Conscious Language Working Group" \
      license="GPL-3.0-or-later" \
      org.opencontainers.image.title="" \
      org.opencontainers.image.version="$BACKEND_VERSION" \
      org.opencontainers.image.description="A service to clone a set of git repos, parse them, and store word counts." \
      org.opencontainers.image.vendor="Red Hat Conscious Language Working Group" \
      org.opencontainers.image.authors="Red Hat Conscious Language Working Group <conscious-lang-group@redhat.com>" \
      org.opencontainers.image.licenses="GPL-3.0-or-later" \
      org.opencontainers.image.url="https://github.com/conscious-lang/dashboard-backend" \
      org.opencontainers.image.source="https://github.com/conscious-lang/dashboard-backend" \
      org.opencontainers.image.documentation="https://github.com/conscious-lang/dashboard-backend" \
      distribution-scope="public"

CMD ["Rscript", "-e", "library(plumber); pr_run(pr('plumber.R'), port=7033, host='0.0.0.0')"]
EXPOSE 7033

RUN $DNF_CMD install R-core R-core-devel \
                     gcc libcurl-devel openssl-devel libxml2-devel libsodium-devel \
                     the_silver_searcher git-core && \
    $DNF_CMD clean all
COPY . /srv/dashboard-backend
WORKDIR /srv/dashboard-backend
RUN R -q -e "renv::restore()"

USER 1001
