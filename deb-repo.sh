#!/usr/bin/env bash
#
# Create APT repositories
#
[ -z "$DEBUG" ] || set -x
set -o pipefail

# Main executable
PROGRAM="$(realpath ${BASH_SOURCE[0]})"
GNUPGHOME=""
APTLY=${APTLY:-aptly}
APTLY_DIR="${APTLY_DIR:-/data/aptly}"
APTLY_CONF="${APTLY_CONF:-${APTLY_DIR}/aptly.conf}"
REPOSITORY_DIR="${REPOSITORY_DIR:-/repository}"
REPOSITORY_COMPONENT="${REPOSITORY_COMPONENT:-main}"
REPOSITORY_PACKAGES="${REPOSITORY_PACKAGES:-/packages}"
REPOSITORY_DISTRIBUTION="${REPOSITORY_DISTRIBUTION:-testing}"
REPOSITORY_COMMENT="${REPOSITORY_COMMENT:-Apt repository for $REPOSITORY_DISTRIBUTION, components: $REPOSITORY_COMPONENTS}"
REPOSITORY_ORIGIN="${REPOSITORY_ORIGIN:-git}"
REPOSITORY_SUITE="${REPOSITORY_SUITE:-$REPOSITORY_DISTRIBUTION}"
REPOSITORY_GPG_KEY="${REPOSITORY_GPG_KEY:-}"
REPOSITORY_GPG_KEYID="${REPOSITORY_GPG_KEYID:-}"
REPOSITORY_GPG_PASSPHRASE="${REPOSITORY_GPG_PASSPHRASE:-}"

usage() {
    echo "Usage: $0 [-h] [-d <distribution>] [-p <packages>] [-i <comment>] [-c <component>] <codename>"
    echo "  Aptly wrapper to manage repositories"
    echo "  Default aptly folder: ${APTLY_DIR}"
    echo "  Repository directory: ${REPOSITORY_DIR}"
    echo "  Input Packages directory: ${REPOSITORY_PACKAGES}"
    echo
}


cleanup() {
    [ -d "${GNUPGHOME}" ] && rm -rf "$GNUPGHOME"
    exit
}


init() {
    local disablesign="true"

    mkdir -p "${APTLY_DIR}"
    mkdir -p "${REPOSITORY_DIR}"
    if [ -n "${REPOSITORY_GPG_KEY}" ]
    then
        echo "# Importing gpg key for signing ..."
        export GNUPGHOME="$(mktemp -d /tmp/XXXXXX)"
        echo "${REPOSITORY_GPG_KEY}" > "${GNUPGHOME}/gpg.key"
        [ -n "${REPOSITORY_GPG_PASSPHRASE}" ] && echo "${REPOSITORY_GPG_PASSPHRASE}" > "${GNUPGHOME}/passphrase"
        gpg --import $GNUPGHOME/gpg.key
        gpg --list-keys
        disablesign="false"
    fi
    [ -r "${APTLY_CONF}" ] || cat <<-EOF > "${APTLY_CONF}"
		{
		    "rootDir": "${APTLY_DIR}",
		    "downloadConcurrency": 4,
		    "downloadSpeedLimit": 0,
		    "downloadRetries": 0,
		    "downloader": "default",
		    "databaseOpenAttempts": -1,
		    "architectures": [],
		    "dependencyFollowSuggests": false,
		    "dependencyFollowRecommends": false,
		    "dependencyFollowAllVariants": false,
		    "dependencyFollowSource": false,
		    "dependencyVerboseResolve": false,
		    "gpgDisableSign": ${disablesign},
		    "gpgDisableVerify": false,
		    "gpgProvider": "gpg",
		    "downloadSourcePackages": false,
		    "skipLegacyPool": true,
		    "ppaDistributorID": "debian",
		    "ppaCodename": "",
		    "skipContentsPublishing": false,
		    "skipBz2Publishing": false,
		    "FileSystemPublishEndpoints": {
		        "output": {
		            "rootDir": "${REPOSITORY_DIR}",
		            "linkMethod": "copy",
		            "verifyMethod": "md5"
		        }
		    },
		    "S3PublishEndpoints": {},
		    "SwiftPublishEndpoints": {},
		    "AzurePublishEndpoints": {},
		    "AsyncAPI": false,
		    "enableMetricsEndpoint": false
		}
		EOF
}


repository_create() {
    local reponame="${1}"

    if ! ${APTLY} repo show -config="${APTLY_CONF}" ${reponame} &> /dev/null
    then
        ${APTLY} repo create \
            -component="${REPOSITORY_COMPONENT}" \
            -distribution="${REPOSITORY_DISTRIBUTION}" \
            -comment="${REPOSITORY_COMMENT}"\
            -config="${APTLY_CONF}" \
            ${reponame} &> /dev/null
    else
        ${APTLY} repo edit \
            -component="${REPOSITORY_COMPONENT}" \
            -distribution="${REPOSITORY_DISTRIBUTION}" \
            -comment="${REPOSITORY_COMMENT}"\
            -config="${APTLY_CONF}" \
            ${reponame} &> /dev/null
    fi
    echo "# Repository metadata:"
    ${APTLY} repo show -config="${APTLY_CONF}" ${reponame}
}


repository_add_packages_dir() {
    local reponame="${1}"
    local packagedir="${2}"

    ${APTLY} repo add \
        -force-replace \
        -config="${APTLY_CONF}" \
        ${reponame} \
        ${packagedir}

    echo "# Repository information:"
    ${APTLY} repo show -with-packages -config="${APTLY_CONF}" ${reponame}
}


repository_generate() {
    local reponame="${1}"

    local passphrase
    local signing_args
    if [ -d "${GNUPGHOME}" ]
    then
        gpg --armor --export ${REPOSITORY_GPG_KEYID} > "${REPOSITORY_DIR}/gpg"
        signing_args="-gpg-key=${REPOSITORY_GPG_KEYID}"
        if [ -e "${GNUPGHOME}/passphrase"} ]
        then 
            signing_args="${signing_args} -passphrase-file=${GNUPGHOME}/passphrase"
        fi
    else
        signing_args="-skip-signing"
    fi
    echo "# Generating repository: "
    if  ${APTLY} publish show  \
        -config="${APTLY_CONF}" \
        "${REPOSITORY_DISTRIBUTION}" \
        "filesystem:output:${reponame}" &>/dev/null
    then
        ${APTLY} publish update  \
            -batch \
            -architectures=all \
            ${signing_args} \
            -config="${APTLY_CONF}" \
            "$REPOSITORY_DISTRIBUTION" \
            "filesystem:output:${reponame}"
    else
        ${APTLY} publish repo \
            -batch \
            -architectures=all \
            ${signing_args} \
            -distribution="$REPOSITORY_DISTRIBUTION" \
            -config="${APTLY_CONF}" \
            ${reponame} \
            "filesystem:output:${reponame}"
    fi
}


repository_serve() {
    local port="${1:-8080}"

    ${APTLY} serve \
        -listen=:${port} \
        -config="${APTLY_CONF}"
}


# Program
if [ "$0" == "${BASH_SOURCE[0]}" ]
then
    while getopts ":hd:i:c:" opt
    do
        case ${opt} in
            h)
                usage
                exit 0
                ;;
            d)
                REPOSITORY_DISTRIBUTION="${OPTARG}"
                ;;
            i)
                REPOSITORY_COMMENT="${OPTARG}"
                ;;
            p)
                REPOSITORY_PACKAGES="${OPTARG}"
                ;;
            c)
                REPOSITORY_COMPONENT="${OPTARG}"
                ;;
            :)
                echo "Option -${OPTARG} requires an argument"
                exit 1
                ;;
        esac
    done
    shift $((OPTIND -1))
    name=$1
    shift
    if [ -z "${name}" ]
    then
        usage
        exit 1
    fi
    trap "cleanup" 1 2 3 6 && init
    repository_create "${name}"
    repository_add_packages_dir "${name}" "${REPOSITORY_PACKAGES}"
    repository_generate "${name}"
fi