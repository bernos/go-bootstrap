#!/usr/bin/env bash

GO_PKG=github.com/bernos/go-bootstrap

DOCKER_IMAGE="golang:1.5"
DOCKER_SRC_VOLUME=/go/src/$GO_PKG
DOCKER_DIST_VOLUME=/go/src/$GO_PKG/dist
DOCKER_LOG_VOLUME=/var/app/log

# Dockerfile will expect
# Build the proj. Run build in docker so build server doesnt need golang

abort()
{
    echo "An error occurred. Exiting..." >&2
    exit 1

}

trap 'abort' 0

set -e

if hash go 2>/dev/null; then
    echo "go toolchain found. building locally"
    $MAKE
else
    echo "go toolchain not found. building in docker"

    dockerDataVolumeContainerGUID=$(
        docker create \
               --volume $DOCKER_DIST_VOLUME \
               --volume $DOCKER_LOG_VOLUME \
               $DOCKER_IMAGE \
               /dev/null
                                 )

    set +e

    docker run \
           --rm \
           --volume $(which docker):/bin/docker:ro \
           --volume "$PWD":$DOCKER_SRC_VOLUME \
           --volumes-from $dockerDataVolumeContainerGUID \
           -w $DOCKER_SRC_VOLUME \
           -e "TEAMCITY_VERSION=$TEAMCITY_VERSION" \
           -e "PWD=$DOCKER_SRC_VOLUME" \
           -e "BUILD_NUMBER=$BUILD_NUMBER" \
           $DOCKER_IMAGE \
           make

    dockerExitStatus=$?
    set +e

    if [[ $dockerExitStatus -ne 0 ]]; then
        docker rm $dockerDataVolumeContainerGUID || true
        exit $dockerExitStatus
    fi

    rm -rf ./dist
    docker cp $dockerDataVolumeContainerGUID:$DOCKER_DIST_VOLUME ./
    docker rm $dockerDataVolumeContainerGUID || true
fi

trap : 0
