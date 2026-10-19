#!/bin/bash
mkdir output
mkdir input/server/downloads
# makeself archives input/server by itself, so the shared library has to be
# inside that directory while the archive is built.
cp -f input/common/chef-common.sh input/server/chef-common.sh || exit 1
./download-installer.sh
./contrib/makeself.sh --follow --nox11 --nowait ./input/server ./output/server.run "Chef Server Setup" ./chef-server.sh
status=$?
rm -f input/server/chef-common.sh
exit "${status}"
