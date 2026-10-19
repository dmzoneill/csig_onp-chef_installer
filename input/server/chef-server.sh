#!/bin/bash

PIP="http://sivapp002.ir.intel.com/~dmoneil2/onp/downloads/python-pip-1.3.1-4.el6.noarch.rpm"
CHEF="http://sivapp002.ir.intel.com/~dmoneil2/onp/downloads/chef-12.1.2-1.el6.x86_64.rpm"
CHEFSERVER="http://sivapp002.ir.intel.com/~dmoneil2/onp/downloads/chef-server-core-12.0.6-1.el6.x86_64.rpm"

CHEFSERVERHOSTNAME=$(hostname -f)

CHEFUSER=tester
CHEFPASS=tester
CHEFORG=intel

# Shared helpers are copied beside this script when the makeself payload is built.
_chef_script_dir=$(CDPATH='' cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
_chef_common="${_chef_script_dir}/chef-common.sh"
[ -f "${_chef_common}" ] || _chef_common="${_chef_script_dir}/../common/chef-common.sh"
# shellcheck source=../common/chef-common.sh
source "${_chef_common}" || exit 1
unset _chef_script_dir _chef_common

#=== FUNCTION =========================================================================
# NAME: install_critic
# DESCRIPTION: installs rvm and foodcritic
#======================================================================================
install_critic() {
	echo "Installing rvm and foodcritic..."

	{
		gpg --keyserver hkp://keys.gnupg.net --recv-keys 409B6B1796C275462A1703113804BB82D39DC0E3
		curl -sSL https://get.rvm.io | bash -s stable
		rvm install ruby-1.9.3
		rvm use 1.9.3
		gem install foodcritic
	} >>"${LOGFILE}" 2>&1
}

#=== FUNCTION =========================================================================
# NAME: cleanup_previous_install
# DESCRIPTION: Configures chef
#======================================================================================
cleanup_previous_install() {
	echo "Clearing any previous configurations"

	{
		chef-server-ctl stop
		killall -u opscode
		rm -rvf /etc/chef
		rm -rvf /opt/opscode
		rm -rvf /var/opt/opscode
		rm -rvf /opt/chef
		rm -rvf /etc/opscode
	} >>"${LOGFILE}" 2>&1

	uninstall git
	uninstall wget
	uninstall curl
	uninstall socat
	uninstall expect
	uninstall httpd
	uninstall chef
	uninstall chef-server-core
	uninstall python-pip

	{
		rm -rvf /etc/httpd
		rm -rvf chef-repo
	} >>"${LOGFILE}" 2>&1
}

#=== FUNCTION =========================================================================
# NAME: configureChef
# DESCRIPTION: Configures chef
#======================================================================================
configureChef() {
	echo "Git clone chef repo..."

	INSTALLDIR=$(pwd)

	cd /root || true

	{
		cp -fv "${INSTALLDIR}/id_rsa" /root/.ssh/
		cp -fv "${INSTALLDIR}/id_rsa.pub" /root/.ssh/
		chmod 600 /root/.ssh/*
	} >>"${LOGFILE}" 2>&1

	prompt_git_identity_and_clone

	echo "Configuring chef server.."

	cd chef-repo || true

	EXPECT=$(which expect)
	CHEFREPO=$(pwd)
	mkdir -vp .chef >>"${LOGFILE}" 2>&1

	chef-server-ctl reconfigure >>"${LOGFILE}" 2>&1

	chef-server-ctl user-create "${CHEFUSER}" "${CHEFUSER}" "${CHEFUSER}" "${CHEFUSER}@intel.com" "${CHEFPASS}" --filename ".chef/${CHEFUSER}.pem"
	chef-server-ctl org-create "${CHEFORG}" "${CHEFORG}" --association_user "${CHEFUSER}" --filename .chef/chef-validator.pem

	echo "Configuring knife..."
	echo ""
	sed -i "s:EXPECT:${EXPECT}:g" "${INSTALLDIR}/knife-setup"
	sed -i "s:CHEFREPO:${CHEFREPO}:g" "${INSTALLDIR}/knife-setup"
	sed -i "s:CHEFSERVERHOSTNAME:${CHEFSERVERHOSTNAME}:g" "${INSTALLDIR}/knife-setup"
	sed -i "s:CHEFUSER:${CHEFUSER}:g" "${INSTALLDIR}/knife-setup"
	sed -i "s:CHEFPASS:${CHEFPASS}:g" "${INSTALLDIR}/knife-setup"
	sed -i "s:CHEFORG:${CHEFORG}:g" "${INSTALLDIR}/knife-setup"

	{
		"${INSTALLDIR}/knife-setup"
		knife ssl fetch
		cp "${CHEFREPO}/.chef/knife.rb" "${CHEFREPO}/.chef/knife-proxy.rb"
	} >>"${LOGFILE}" 2>&1

	{
		echo "local_mode                                true                   "
		echo "http_proxy               \"http://${HTTPPROXYHOST}:${HTTPPROXYPORT}\""
		echo "https_proxy              \"http://${HTTPPROXYHOST}:${HTTPPROXYPORT}\""
		echo "Ohai::Config[:disabled_plugins] = [:Passwd]                      "
	} >>"${CHEFREPO}/.chef/knife-proxy.rb"

	sed -i "s:CHEFSERVERHOSTNAME:${CHEFSERVERHOSTNAME}:g" "${CHEFREPO}/.chef/bootstrap/nosclient.erb"
	CLIENT=$(basename "${CHEF}")
	sed -i "s:CHEFCLIENT:${CLIENT}:g" "${CHEFREPO}/.chef/bootstrap/nosclient.erb"
	sed -i "s:CHEFORG:${CHEFORG}:g" "${CHEFREPO}/.chef/bootstrap/nosclient.erb"
	entries=(*)
	knife upload "${entries[@]}" >>"${LOGFILE}" 2>&1

	echo "Bootstrap client via:"
	echo ""
	echo "    knife bootstrap IP --distro \"nosclient\" --environment \"sie_lab|or_lab\""
	echo ""
	echo "Install packages from supermarket:"
	echo ""
	echo "    knife cookbook site install PKG -c ./.chef/knife-proxy.rb"
	echo ""
}

#=== FUNCTION =========================================================================
# NAME: main
# DESCRIPTION: main function
#======================================================================================
main() {
	prepare_and_require_root

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

	mkdir -vp "${DOWNLOADDIR}"

	res1=""
	res2=""

	if download "${CHEFSERVER}"; then
		rpm=$(basename "${CHEFSERVER}")
		installRpm "${rpm}"
		res2=$?
	else
		logverbose "Problem downloading chef server"
	fi

	if download "${CHEF}"; then
		rpm=$(basename "${CHEF}")
		installRpm "${rpm}"
		res1=$?
		cp -rv "${DOWNLOADDIR}/${rpm}" /var/www/html/ >>"${LOGFILE}" 2>&1
		chmod 666 "/var/www/html/${rpm}"
		chown apache:apache "/var/www/html/${rpm}"
	else
		logverbose "Problem downloading chef workstation"
	fi

	if download "${PIP}"; then
		rpm=$(basename "${PIP}")
		installRpm "${rpm}"
		pip install --proxy "http://${HTTPPROXYHOST}:${HTTPPROXYPORT}" git-review >>"${LOGFILE}" 2>&1
	else
		logverbose "Problem downloading chef server"
	fi

	install_foodcritic

	if [[ "${res1}" -eq "0" && "${res2}" -eq "0" ]]; then
		configureChef
	else
		logverbose "Problem installing server/workstation.  Check log: ${LOGFILE}"
	fi
}

main
