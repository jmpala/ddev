#!/bin/bash

# trigger_release.sh $circle_token $release_tag $github_token $project_optional

# .circleci/trigger_release.sh circlepikey0908b3a58316baf928b v1.5.9 githubpersonaltokenc5ad9f7c353962dea optional/ddev  | jq -r 'del(.circle_yml)'

# api docs: https://circleci.com/docs/api
# Trigger a new job: https://circleci.com/docs/api/v1-reference/#new-build

set -o errexit -o pipefail -o noclobber -o nounset

GITHUB_PROJECT=drud/ddev
BUILD_IMAGE_TARBALLS=true

# Long option parsing example: https://stackoverflow.com/a/29754866/215713
# On macOS this requires `brew install gnu-getopt`
OS=$(uname -s)
if [ ${OS} = "Darwin" ]; then PATH="/usr/local/opt/gnu-getopt/bin:$PATH"; fi
if [ ${OS} = "Darwin" ] && [ ! -f "/usr/local/opt/gnu-getopt/bin/getopt" ]; then
    echo "This script requires `brew install gnu-getopt`" && exit 1
fi

! getopt --test > /dev/null
if [[ ${PIPESTATUS[0]} -ne 4 ]]; then
    echo '`getopt --test` failed in this environment.'
    exit 1
fi


OPTIONS=c:g:r:p:s:b:h:
LONGOPTS=circleci-token:,github-token:,release-tag:,github-project:,windows-signing-password:,build-image-tarballs:,chocolatey-api-key:

! PARSED=$(getopt --options=$OPTIONS --longoptions=$LONGOPTS --name "$0" -- "$@")
if [[ ${PIPESTATUS[0]} -ne 0 ]]; then
    # e.g. return value is 1
    #  then getopt has complained about wrong arguments to stdout
    printf "\n\nFailed parsing options:\n"
    getopt --options=$OPTIONS --longoptions=$LONGOPTS --name "$0" -- "$@"
    exit 2
fi

eval set -- "$PARSED"

while true; do
    case "$1" in
    -c|--circleci-token)
        CIRCLE_TOKEN=$2
        shift 2
        ;;
    -g|--github-token)
        GITHUB_TOKEN=$2
        shift 2
        ;;
    -t|--release-tag)
        RELEASE_TAG=$2
        shift 2
        ;;
    -p|--github-project)
        GITHUB_PROJECT=$2
        shift 2
        ;;
    -s|--windows-signing-password)
        DDEV_WINDOWS_SIGNING_PASSWORD=$2
        shift 2
        ;;
    -h|--chocolatey-api-key)
        CHOCOLATEY_API_KEY=$2
        shift 2
        ;;
    # For debugging we can set BUILD_IMAGE_TARBALLS=false to avoid waiting for that.
    -b|--build-image-tarballs)
        BUILD_IMAGE_TARBALLS=$2
        shift 2
        ;;
    --)
        break;
    esac
done

trigger_build_url=https://circleci.com/api/v1.1/project/github/$GITHUB_PROJECT?circle-token=${CIRCLE_TOKEN}

set -x
BUILD_PARAMS="\"CIRCLE_JOB\": \"release_build\", \"job_name\": \"release_build\", \"GITHUB_TOKEN\":\"${GITHUB_TOKEN:-}\", \"RELEASE_TAG\": \"${RELEASE_TAG}\",\"DDEV_WINDOWS_SIGNING_PASSWORD\":\"${DDEV_WINDOWS_SIGNING_PASSWORD:-}\",\"CHOCOLATEY_API_KEY\":\"${CHOCOLATEY_API_KEY:-}\",\"BUILD_IMAGE_TARBALLS\":\"${BUILD_IMAGE_TARBALLS:-true}\""
if [ "${RELEASE_TAG:-}" != "" ]; then
    DATA="\"tag\": \"$RELEASE_TAG\","
fi

DATA="${DATA} \"build_parameters\": { ${BUILD_PARAMS} } "

curl -X POST -sS \
  --header "Content-Type: application/json" \
  --data "{ ${DATA} }" \
    $trigger_build_url

