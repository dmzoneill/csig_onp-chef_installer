#!/bin/bash

ZONE=`hostname -d`
USEHTTPPROXY=1
HTTPPROXYHOST=proxy.$ZONE
HTTPPROXYPORT=911

NOPROXY=localhost,intel.com

PIP=http://sivapp002.ir.intel.com/~dmoneil2/onp/downloads/python-pip-1.3.1-4.el6.noarch.rpm
CHEF=http://sivapp002.ir.intel.com/~dmoneil2/onp/downloads/chef-12.1.2-1.el6.x86_64.rpm
CHEFSERVER=http://sivapp002.ir.intel.com/~dmoneil2/onp/downloads/chef-server-core-12.0.6-1.el6.x86_64.rpm

LOGFILE=/root/chef_install_log
CHEFSERVERHOSTNAME=`hostname -f`
DOWNLOADDIR=downloads

CHEFUSER=tester
CHEFPASS=tester
CHEFORG=intel

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
# NAME: install
# DESCRIPTION: installs package via yum 
# PARAMETER 1: the package to install
#======================================================================================

function uninstall()
{
	echo "Removing $1..."
	
	yum -y remove $1 >> $LOGFILE 2>&1
		
	return $?
}


#=== FUNCTION =========================================================================
# NAME: install_foodcritic
# DESCRIPTION: installs rvm and footcritic 
#======================================================================================

function install_critic()
{
	echo "Installing rvm and foodcritic..."
	
	gpg --keyserver hkp://keys.gnupg.net --recv-keys 409B6B1796C275462A1703113804BB82D39DC0E3 >> $LOGFILE 2>&1
	curl -sSL https://get.rvm.io | bash -s stable >> $LOGFILE 2>&1
    rvm install ruby-1.9.3 >> $LOGFILE 2>&1
    rvm use 1.9.3 >> $LOGFILE 2>&1
    gem install foodcritic >> $LOGFILE 2>&1

	return $?
}


#=== FUNCTION =========================================================================
# NAME: configureChef
# DESCRIPTION: Configures chef
#======================================================================================

function cleanup_previous_install()
{
    echo "Clearing any previous configurations"

    chef-server-ctl stop >> $LOGFILE 2>&1
    killall -u opscode >> $LOGFILE 2>&1
    rm -rvf /etc/chef >> $LOGFILE 2>&1
    rm -rvf /opt/opscode >> $LOGFILE 2>&1
    rm -rvf /var/opt/opscode >> $LOGFILE 2>&1
    rm -rvf /opt/chef >> $LOGFILE 2>&1
    rm -rvf /etc/opscode >> $LOGFILE 2>&1

	uninstall git 
	uninstall wget
	uninstall curl
	uninstall socat
    uninstall expect
    uninstall httpd
    uninstall chef
    uninstall chef-server-core
    uninstall python-pip

    rm -rvf /etc/httpd >> $LOGFILE 2>&1
    rm -rvf chef-repo >> $LOGFILE 2>&1 
}


#=== FUNCTION =========================================================================
# NAME: configureChef
# DESCRIPTION: Configures chef
#======================================================================================

function configureChef()
{
	echo "Git clone chef repo..."
	
	INSTALLDIR=`pwd`
	
	cd /root
	
	cp -fv $INSTALLDIR/id_rsa /root/.ssh/ >> $LOGFILE 2>&1
	cp -fv $INSTALLDIR/id_rsa.pub /root/.ssh/ >> $LOGFILE 2>&1
	
	chmod 600 /root/.ssh/* >> $LOGFILE 2>&1

    echo -n "Please enter your windows ID:"
    read GITUSER
    
    echo -n "Please enter your intel email address:"
    read GITEMAIL

	git config --global user.name "$GITUSER"
	git config --global user.email "$GITEMAIL"
	
	echo -e "Host github.intel.com\n\tStrictHostKeyChecking no\n" >> ~/.ssh/config
    git clone ssh://$GITUSER@git-amr-1.devtools.intel.com:29418/csig_onp-chef_repo chef-repo >> $LOGFILE 2>&1
	
    echo "Configuring chef server.."

    cd chef-repo

	EXPECT=`which expect`
    CHEFREPO=`pwd`
    mkdir -vp .chef >> $LOGFILE 2>&1

	chef-server-ctl reconfigure >> $LOGFILE 2>&1

    chef-server-ctl user-create $CHEFUSER $CHEFUSER $CHEFUSER $CHEFUSER@intel.com $CHEFPASS --filename .chef/$CHEFUSER.pem
    chef-server-ctl org-create $CHEFORG $CHEFORG --association_user $CHEFUSER --filename .chef/chef-validator.pem

	echo "Configuring knife..."
	echo ""
	sed -i s:EXPECT:$EXPECT:g $INSTALLDIR/knife-setup
	sed -i s:CHEFREPO:$CHEFREPO:g $INSTALLDIR/knife-setup
	sed -i s:CHEFSERVERHOSTNAME:$CHEFSERVERHOSTNAME:g $INSTALLDIR/knife-setup
	sed -i s:CHEFUSER:$CHEFUSER:g $INSTALLDIR/knife-setup
	sed -i s:CHEFPASS:$CHEFPASS:g $INSTALLDIR/knife-setup
    sed -i s:CHEFORG:$CHEFORG:g $INSTALLDIR/knife-setup
	
    $INSTALLDIR/knife-setup >> $LOGFILE 2>&1

    knife ssl fetch >> $LOGFILE 2>&1

    cp $CHEFREPO/.chef/knife.rb $CHEFREPO/.chef/knife-proxy.rb >> $LOGFILE 2>&1

    echo "local_mode                                true                   " >> $CHEFREPO/.chef/knife-proxy.rb
    echo "http_proxy               \"http://$HTTPPROXYHOST:$HTTPPROXYPORT\"" >> $CHEFREPO/.chef/knife-proxy.rb
    echo "https_proxy              \"http://$HTTPPROXYHOST:$HTTPPROXYPORT\"" >> $CHEFREPO/.chef/knife-proxy.rb
    echo "Ohai::Config[:disabled_plugins] = [:Passwd]                      " >> $CHEFREPO/.chef/knife-proxy.rb
    
    sed -i s:CHEFSERVERHOSTNAME:$CHEFSERVERHOSTNAME:g $CHEFREPO/.chef/bootstrap/nosclient.erb
    CLIENT=`basename $CHEF`
    sed -i s:CHEFCLIENT:$CLIENT:g $CHEFREPO/.chef/bootstrap/nosclient.erb
    sed -i s:CHEFORG:$CHEFORG:g $CHEFREPO/.chef/bootstrap/nosclient.erb
    knife upload * >> $LOGFILE 2>&1

	echo "Bootstrap client via:"
    echo ""
    echo "    knife bootstrap IP --distro \"nosclient\" --environment \"sie_lab|or_lab\""
    echo ""
    echo "Install packages from supermarket:";
    echo ""
    echo "    knife cookbook site install PKG -c ./.chef/knife-proxy.rb"
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
	
    cleanup_previous_install
	configureHttpProxy
	
	install git 
	install wget
	install curl
	install socat
    install expect
    install httpd

    sed -i 's:Listen 80.*$:Listen 8080:g' /etc/httpd/conf/httpd.conf
    chkconfig httpd on
    /etc/init.d/httpd restart

    mkdir -vp $DOWNLOADDIR

	download $CHEFSERVER
	if [ "$?" -eq "0" ]; then
		rpm=`basename $CHEFSERVER`
		installRpm $rpm
		res2=$?
	else
		logverbose "Problem downloading chef server"
	fi
	
	download $CHEF
	if [ "$?" -eq "0" ]; then
		rpm=`basename $CHEF`
		installRpm $rpm
        res1=$?
        cp -rv $DOWNLOADDIR/$rpm /var/www/html/ >> $LOGFILE 2>&1
        chmod 666 /var/www/html/$rpm
        chown apache:apache /var/www/html/$rpm
	else
		logverbose "Problem downloading chef workstation"
	fi
	
	download $PIP
	if [ "$?" -eq "0" ]; then
		rpm=`basename $PIP`
		installRpm $rpm
		res3=$?
		pip install --proxy http://$HTTPPROXYHOST:$HTTPPROXYPORT git-review >> $LOGFILE 2>&1
	else
		logverbose "Problem downloading chef server"
	fi

    install_foodcritic
	
	if [[ "$res1" -eq "0" && "$res2" -eq "0" ]]; then
		configureChef
	else
		logverbose "Problem installing server/workstation.  Check log: $LOGFILE"
	fi
	
}

main
