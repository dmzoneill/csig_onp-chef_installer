#!/bin/bash
mkdir output
mkdir input/solo/downloads
mkdir input/server/downloads
# makeself archives input/solo by itself, so the shared library has to be
# inside that directory while the archive is built.
cp -f input/common/chef-common.sh input/solo/chef-common.sh || exit 1
./download-installer.sh
./contrib/makeself.sh --follow --nox11 --nowait ./input/solo ./output/solo.run "Chef Solo Setup" ./chef-solo.sh
status=$?
rm -f input/solo/chef-common.sh
exit "${status}"
