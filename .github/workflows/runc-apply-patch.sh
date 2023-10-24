#!/bin/bash

set -euo pipefail

source "${GHA_SCRIPTS_DIR}/.github/workflows/common.sh"

prepare_git_repo

if ! check_remote_branch "runc-${VERSION_NEW}-${TARGET_BRANCH}"; then
    echo "remote branch already exists, nothing to do"
    exit 0
fi

pushd "${SDK_OUTER_OVERLAY}"

# Get the newest runc version, including official releases and rc
# versions. We need some sed tweaks like replacing dots with
# underscores, adding trailing underscore, sort, and trim the trailing
# underscore and replace other underscores with dots again, so that
# sort -V can properly sort "1.0.0" as newer than "1.0.0-rc95" and
# "0.0.2.1" as newer than "0.0.2".
VERSION_OLD=$(sed -n "s/^DIST runc-\([0-9]*\.[0-9]*.*\)\.tar.*/\1_/p" app-containers/runc/Manifest | tr '.' '_' | sort -ruV | sed -e 's/_$//' | tr '_' '.' | head -n1)
if [[ "${VERSION_NEW}" = "${VERSION_OLD}" ]]; then
    echo "already the latest Runc, nothing to do"
    exit 0
fi

runcEbuildOld=$(get_ebuild_filename app-containers/runc "${VERSION_OLD}")
runcEbuildNew="app-containers/runc/runc-${VERSION_NEW}.ebuild"
git mv "${runcEbuildOld}" "${runcEbuildNew}"
sed -i "s/${VERSION_OLD}/${VERSION_NEW}/g" "${runcEbuildNew}"
sed -i "s/COMMIT_ID=\"\(.*\)\"/COMMIT_ID=\"${COMMIT_HASH}\"/g" "${runcEbuildNew}"

# update also runc versions used by docker and containerd
sed -i "s/runc-${VERSION_OLD}/runc-${VERSION_NEW}/g" app-containers/containerd/containerd-9999.ebuild

dockerVersion=$(sed -n "s/^DIST docker-\([0-9]*.[0-9]*.[0-9]*\).*/\1/p" app-containers/docker/Manifest | sort -ruV | head -n1)

popd

URL="https://github.com/opencontainers/runc/releases/tag/v${VERSION_NEW}"

generate_update_changelog 'runc' "${VERSION_NEW}" "${URL}" 'runc'

commit_changes app-containers/runc "${VERSION_OLD}" "${VERSION_NEW}" \
               app-containers/containerd

cleanup_repo

echo "VERSION_OLD=${VERSION_OLD}" >>"${GITHUB_OUTPUT}"
echo 'UPDATE_NEEDED=1' >>"${GITHUB_OUTPUT}"
