#!/bin/bash

ZONE=`hostname -d`
USEHTTPPROXY=1
HTTPPROXYHOST=proxy.$ZONE
HTTPPROXYPORT=911

NOPROXY=localhost,intel.com
CHEF=http://sivapp002.ir.intel.com/~dmoneil2/onp/downloads/chef-12.1.2-1.el6.x86_64.rpm

LOGFILE=/root/chef_install_log
HOSTNAME=`hostname -f`
DOWNLOADDIR=downloads

#=== FUNCTION =========================================================================
# NAME: preparelog
# DESCRIPTION: prepares log file
#======================================================================================

function preparelog()
{
	if [ ! -f "$LOGFILE" ]; then
		touch $LOGFILE
	fi
	
	echo "Begin" > $LOGFILE
}


#=== FUNCTION =========================================================================
# NAME: log
# DESCRIPTION: logs to file
#======================================================================================

function log()
{
	echo $1 >> $LOGFILE
}


#=== FUNCTION =========================================================================
# NAME: logverbose
# DESCRIPTION: logs to file and prints to screen
#======================================================================================

function logverbose()
{
	echo $1
	log $1
}


#=== FUNCTION =========================================================================
# NAME: configurehttpProxy
# DESCRIPTION: Configures http proxy for curl and wget
#======================================================================================

function configureHttpProxy()
{
	if [ "$USEHTTPPROXY" -eq "1" ]; then
		logverbose "Configuring http proxy..."
		
		export http_proxy=http://$HTTPPROXYHOST:$HTTPPROXYPORT
		export https_proxy=$http_proxy
		export HTTP_PROXY=$http_proxy
		export HTTPS_PROXY=$http_proxy
		export no_proxy=$NOPROXY
		export NO_PROXY=$NOPROXY
	fi
}


#=== FUNCTION =========================================================================
# NAME: download
# DESCRIPTION: downloads files via tool
# PARAMETER 1: file to download
#======================================================================================

function download()
{
	which curl > /dev/null 2>&1
	
	logverbose "Downloading $1..."
	
    if [ -f $DOWNLOADDIR/`basename $1` ]; then
        return 0
    fi

	if [ "$?" -eq "0" ]; then
		curl -o $DOWNLOADDIR/`basename $1` $1 >> $LOGFILE 2>&1
		
		if [ "$?" -eq "0" ]; then
			return 0
		fi
	fi
	
	which wget > /dev/null 2>&1
	
	if [ "$?" -eq "0" ]; then
		wget -O $DOWNLOADDIR/`basename $1` $1 >> $LOGFILE 2>&1
		
		if [ "$?" -eq "0" ]; then
			return 0
		fi
	fi
	
	return 1
}
 
 
#=== FUNCTION =========================================================================
# NAME: installRpm
# DESCRIPTION: installs rpms 
# PARAMETER 1: the rpm file
#======================================================================================

function installRpm()
{
	echo "Installing rpm $DOWNLOADDIR/$1..."
	
	rpm -i $DOWNLOADDIR/$1 >> $LOGFILE 2>&1
		
	return $?
}


#=== FUNCTION =========================================================================
# NAME: install
# DESCRIPTION: installs package via yum 
# PARAMETER 1: the package to install
#======================================================================================

function install()
{
	echo "Installing $1..."
	
	yum -y install $1 >> $LOGFILE 2>&1
		
	return $?
}


#=== FUNCTION =========================================================================
# NAME: configureChef
# DESCRIPTION: Configures chef
#======================================================================================

function configureChef()
{
	echo "Configuring chef for solo runs..."
	
	INSTALLDIR=`pwd`
	
	cd /root
	
    echo -n "Please enter your windows ID:"
    read GITUSER
    
    echo -n "Please enter your intel email address:"
    read GITEMAIL

	git config --global user.name "$GITUSER"
	git config --global user.email "$GITEMAIL"
	
	echo -e "Host github.intel.com\n\tStrictHostKeyChecking no\n" >> ~/.ssh/config
    git clone ssh://$GITUSER@git-amr-1.devtools.intel.com:29418/csig_onp-chef_repo chef-repo >> $LOGFILE 2>&1
		
    cd chef-repo
    mkdir nodes
    touch nodes/$HOSTNAME.json

cat > nodes/$HOSTNAME.json << EOL
{
  "name": "$HOSTNAME",
  "normal": {
    "SystemdNetworkd": {
      "Cookbooks": {
        "FDB": "true",
        "Link": "true",
        "Switchport": "true",
        "UFD": "true",
        "Team": "true"
      },
      "Teams": {
        "team2": {
          "Enabled": "true",
          "Members": [
            "sw0p9",
            "sw0p10"
          ]
        }
      },
      "UFD": {
        "sw0p1": {
          "Enabled": "true",
          "BindCarrier": "sw0p2 sw0p3"
	}
      },
      "Ports": {
        "sw0p5": {
          "Enabled": "true",
          "FDB": [
            [
              "MACAddress",
              "AB:BC:CC:00:01:02",
              "VLAN",
              "2"
            ]
          ],
          "Link": {
            "Link": [
              [
                "BitsPerSecond",
                "10240000"
              ],
              [
                "Duplex",
                "full"
              ]
            ]
          },
          "Attributes": [
            [
              "DefPri",
              "2"
            ],
            [
              "BcastPruning",
              "1"
            ]
          ],
          "Vlans": {
            "lab": {
              "Id": "20",
              "EgressUntagged": "true"
            },
            "office": {
              "Id": "25"
            }
          }
        }
      }
    }
  },
  "run_list": [
    "recipe[systemd_networkd]"
  ]
}
EOL

	echo "Run chef solo now via:"
    echo ""
    echo "    chef-client -N $HOSTNAME -z"
    echo ""
}


#=== FUNCTION =========================================================================
# NAME: main
# DESCRIPTION: main function
#======================================================================================
 
function main()
{
	preparelog
	
	if [ "$(id -u)" != "0" ]; then
		logverbose "Please run this script as root"
		exit 1
	fi 
	
	configureHttpProxy
	
	install git 
	install wget
	install curl
	install socat

    mkdir -vp $DOWNLOADDIR
	download $CHEF
	if [ "$?" -eq "0" ]; then
		rpm=`basename $CHEF`
		installRpm $rpm
        res1=$?
	else
		logverbose "Problem downloading chef workstation"
	fi
	
	if [[ "$res1" -eq "0" && "$res2" -eq "0" ]]; then
		configureChef
	else
		logverbose "Problem installing chef.  Check log: $LOGFILE"
	fi
	
}

main
