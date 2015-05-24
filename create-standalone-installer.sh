#!/bin/bash
mkdir output
mkdir input/solo/downloads
mkdir input/server/downloads
./download-installer.sh
./contrib/makeself.sh --follow --nox11 --nowait ./input/solo ./output/solo.run "Chef Solo Setup" ./chef-solo.sh
