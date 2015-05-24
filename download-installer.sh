#!/bin/bash
SERVER=chef-server-core-12.0.6-1.el6.x86_64.rpm
CLIENT=chef-12.1.2-1.el6.x86_64.rpm
DDIR=input/server/downloads
SDDIR=input/solo/downloads
WWW=http://sivapp002.ir.intel.com/~dmoneil2/onp/downloads
PIP=python-pip-1.3.1-4.el6.noarch.rpm
 
if [ ! -f $DDIR/$CLIENT ]; then
    wget --no-check-certificate -O $DDIR/$CLIENT $WWW/$CLIENT
fi 

if [ ! -f $DDIR/$SERVER ]; then
    wget --no-check-certificate -O $DDIR/$SERVER $WWW/$SERVER 
fi

if [ ! -f $DDIR/$PIP ]; then
    wget --no-check-certificate -O $DDIR/$PIP $WWW/$PIP 
fi

if [ ! -f $SDDIR/$CLIENT ]; then
    ln -s ../../../$DDIR/$CLIENT $SDDIR/$CLIENT
fi
