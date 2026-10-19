#!/bin/bash

CHEF="http://sivapp002.ir.intel.com/~dmoneil2/onp/downloads/chef-12.1.2-1.el6.x86_64.rpm"
HOSTNAME=$(hostname -f)

# Shared helpers are copied beside this script when the makeself payload is built.
_chef_script_dir=$(CDPATH='' cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
_chef_common="${_chef_script_dir}/chef-common.sh"
[ -f "${_chef_common}" ] || _chef_common="${_chef_script_dir}/../common/chef-common.sh"
# shellcheck source=../common/chef-common.sh
source "${_chef_common}" || exit 1
unset _chef_script_dir _chef_common

#=== FUNCTION =========================================================================
# NAME: configureChef
# DESCRIPTION: Configures chef
#======================================================================================
configureChef() {
	echo "Configuring chef for solo runs..."

	cd /root || true

	prompt_git_identity_and_clone

	cd chef-repo || true
	mkdir nodes
	touch "nodes/${HOSTNAME}.json"

	cat >"nodes/${HOSTNAME}.json" <<EOL
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
	echo "    chef-client -N ${HOSTNAME} -z"
	echo ""
}

#=== FUNCTION =========================================================================
# NAME: main
# DESCRIPTION: main function
#======================================================================================
main() {
	prepare_and_require_root

	configureHttpProxy

	install git
	install wget
	install curl
	install socat

	mkdir -vp "${DOWNLOADDIR}"

	# res2 is never set by the solo installer. The original combined check
	# therefore does not succeed; keep that comparison.
	res1=""
	res2=""
	if download "${CHEF}"; then
		rpm=$(basename "${CHEF}")
		installRpm "${rpm}"
		res1=$?
	else
		logverbose "Problem downloading chef workstation"
	fi

	if [[ "${res1}" -eq "0" && "${res2}" -eq "0" ]]; then
		configureChef
	else
		logverbose "Problem installing chef.  Check log: ${LOGFILE}"
	fi
}

main
