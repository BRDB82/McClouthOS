#!/bin/bash

#*****************************************************************************
#* emblancher: McClouth OS Installation program                              *
#* Copyright (C) 2025 McClouth Incorporated                                  *
#* BRDB82                                                                    *
#*****************************************************************************

# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU Lesser General Public License as published
# by the Free Software Foundation; either version 2.1 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Lesser General Public License for more details.
#
# You should have received a copy of the GNU Lesser General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

if [ "$1" == "--update" ]; then
	curl -fsSL "https://raw.githubusercontent.com/BRDB82/McClouthOS/main/RHEL/emblancher.sh" -o "/usr/bin/emblancher.new" || {
		echo "update failed"
	    rm "/usr/bin/emblancer.new"
	    exit 1
	}
	chmod +x "/usr/bin/emblancher.new"
	mv -f "/usr/bin/emblancher.new" "/usr/bin/emblancher"
	exit 0
fi

#main
#----

if [[ $UID -ne 0 ]]; then
  echo "emblancher must be run as root"
  exit 1
fi

echo "Starting installer, one moment..."

#001
