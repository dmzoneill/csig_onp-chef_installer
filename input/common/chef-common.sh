#!/bin/bash
#
# Shared helpers for the chef server and chef solo installers.
# create-server-installer.sh and create-standalone-installer.sh copy this
# file next to the payload script before makeself packs that directory.
# The installers source the copy relative to their own directory.

ZONE=$(hostname -d)
USEHTTPPROXY=1
HTTPPROXYHOST="proxy.${ZONE}"
HTTPPROXYPORT=911
NOPROXY="localhost,intel.com"

LOGFILE=/root/chef_install_log
DOWNLOADDIR=downloads

#=== FUNCTION =========================================================================
# NAME: preparelog
# DESCRIPTION: prepares log file
#======================================================================================
preparelog() {
	if [ ! -f "${LOGFILE}" ]; then
		touch "${LOGFILE}"
	fi

	echo "Begin" >"${LOGFILE}"
}

#=== FUNCTION =========================================================================
# NAME: log
# DESCRIPTION: logs to file
#======================================================================================
log() {
	local -a words
	# Field-split like the original unquoted echo, without globbing the message.
	read -r -a words <<<"${1}"
	echo "${words[*]}" >>"${LOGFILE}"
}

#=== FUNCTION =========================================================================
# NAME: logverbose
# DESCRIPTION: logs to file and prints to screen
#======================================================================================
logverbose() {
	local -a words
	# Field-split like the original unquoted echo, without globbing the message.
	read -r -a words <<<"${1}"
	echo "${words[*]}"
	# The original call was unquoted, so the log file kept only the first field.
	if [ "${#words[@]}" -gt 0 ]; then
		log "${words[0]}"
	else
		log ""
	fi
}

#=== FUNCTION =========================================================================
# NAME: configureHttpProxy
# DESCRIPTION: Configures http proxy for curl and wget
#======================================================================================
configureHttpProxy() {
	if [ "${USEHTTPPROXY}" -eq "1" ]; then
		logverbose "Configuring http proxy..."

		export http_proxy="http://${HTTPPROXYHOST}:${HTTPPROXYPORT}"
		export https_proxy="${http_proxy}"
		export HTTP_PROXY="${http_proxy}"
		export HTTPS_PROXY="${http_proxy}"
		export no_proxy="${NOPROXY}"
		export NO_PROXY="${NOPROXY}"
	fi
}

#=== FUNCTION =========================================================================
# NAME: download
# DESCRIPTION: downloads files via tool
# PARAMETER 1: file to download
#======================================================================================
download() {
	which curl >/dev/null 2>&1

	logverbose "Downloading ${1}..."

	local cached
	cached="${DOWNLOADDIR}/$(basename "${1}")"
	if [ -f "${cached}" ]; then
		return 0
	fi

	# A failed `if` test still leaves status 0, which is what the original
	# scripts checked before invoking curl. Try curl, then wget.
	if curl -o "${cached}" "${1}" >>"${LOGFILE}" 2>&1; then
		return 0
	fi

	if which wget >/dev/null 2>&1; then
		if wget -O "${cached}" "${1}" >>"${LOGFILE}" 2>&1; then
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
installRpm() {
	echo "Installing rpm ${DOWNLOADDIR}/${1}..."
	rpm -i "${DOWNLOADDIR}/${1}" >>"${LOGFILE}" 2>&1
}

#=== FUNCTION =========================================================================
# NAME: install
# DESCRIPTION: installs package via yum
# PARAMETER 1: the package to install
#======================================================================================
install() {
	echo "Installing ${1}..."
	yum -y install "${1}" >>"${LOGFILE}" 2>&1
}

#=== FUNCTION =========================================================================
# NAME: uninstall
# DESCRIPTION: removes package via yum
# PARAMETER 1: the package to remove
#======================================================================================
uninstall() {
	echo "Removing ${1}..."
	yum -y remove "${1}" >>"${LOGFILE}" 2>&1
}

#=== FUNCTION =========================================================================
# NAME: prompt_git_identity_and_clone
# DESCRIPTION: asks for git identity and clones the chef repo into the cwd
#======================================================================================
prompt_git_identity_and_clone() {
	echo -n "Please enter your windows ID:"
	read -r GITUSER

	echo -n "Please enter your intel email address:"
	read -r GITEMAIL

	git config --global user.name "${GITUSER}"
	git config --global user.email "${GITEMAIL}"

	echo -e "Host github.intel.com\n\tStrictHostKeyChecking no\n" >>"${HOME}/.ssh/config"
	git clone "ssh://${GITUSER}@git-amr-1.devtools.intel.com:29418/csig_onp-chef_repo" chef-repo >>"${LOGFILE}" 2>&1
}

#=== FUNCTION =========================================================================
# NAME: prepare_and_require_root
# DESCRIPTION: starts the log and exits unless the current user is root
#======================================================================================
prepare_and_require_root() {
	preparelog

	if [ "$(id -u)" != "0" ]; then
		logverbose "Please run this script as root"
		exit 1
	fi
}
