FROM lsstsqre/centos:7-stackbase-devtoolset-8

ARG     D_USER
ARG     D_UID
ARG     D_GROUP
ARG     D_GID
ARG     D_HOME

USER    root
RUN     yum install -y tcsh

RUN     mkdir -p "$(dirname "$D_HOME")"
RUN     groupadd -g "$D_GID" "$D_GROUP"
RUN     useradd -d "$D_HOME" -g "$D_GROUP" -u "$D_UID" "$D_USER"

USER    $D_USER
WORKDIR $D_HOME

SHELL ["/bin/bash", "-lc"]
