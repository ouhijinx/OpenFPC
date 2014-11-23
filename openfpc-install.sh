#!/bin/bash 

#########################################################################################
# Copyright (C) 2010 - 2014 Leon Ward 
# install-openfpc.sh - Part of the OpenFPC - (Full Packet Capture) project
#
# Contact: leon@openfpc.org
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
#########################################################################################

# This installer is for users that cannot or will not use the .debs for installation.
# It's goal is to take a system from being OpenFPC-less to one that has OpenFPC operating in a semi-standard setup.
# By semi-standard I refer to similar to how the .deb install leaves the system.
# It should be noted that the .debs have not been updated for 0.6 - 11/06/2011

openfpcver="0.9"
PROG_DIR="/usr/bin"
CONF_DIR="/etc/openfpc"
CONF_FILES="etc/openfpc-default.conf etc/openfpc-example-proxy.conf etc/routes.ofpc"
PROG_FILES="openfpc-client openfpc-queued openfpc-cx2db openfpc openfpc-dbmaint openfpc-password"

#GUI_FILES="css images includes index.php javascript login.php useradd.php"
#WWW_DIR="/usr/share/openfpc/www"

PERL_MODULES="Parse.pm Request.pm CXDB.pm Common.pm Config.pm"
INIT_SCRIPTS="openfpc-daemonlogger openfpc-cx2db openfpc-cxtracker openfpc-queued"
INIT_DIR="/etc/init.d/" 
REQUIRED_BINS="tcpdump date mergecap perl tshark test"
LOCAL_CONFIG="/etc/openfpc/openfpc.conf"
PERL_LIB_DIR="/usr/local/lib/site_perl"
OFPC_LIB_DIR="$PERL_LIB_DIR/OFPC"
CXINSTALLED=0

DEPSOK=0			# Track if known deps are met
DISTRO="AUTO"		# Try to work out what distro we are installing on
# DISTRO="REDHAT"	# Force detection of distribution to RedHat
# DISTRO="Debian" 	# Force to detection of distribution to Debian / Ubuntu

IAM=$(whoami)
DATE=$(date)
PATH=$PATH:/usr/sbin
ACTION=$1
GUI=$2

function die()
{
        echo "$1"
        exit 1
}

function chkroot()
{
	if [ "$IAM" != "root" ]
	then
	       	die "[!] ERROR: Must be root to run this script"
	fi
}

function mkuser(){
	PASSFILE="/etc/openfpc/openfpc.passwd"
	echo "[*] Step 1: Creating a user to access OpenFPC."
	echo "    This user will be able to extract data and interact with the queue-daemon. "
	echo "    The OpenFPC user management is controlled by the application openfpc-passwd. "
	echo "    The default OpenFPC passwd file is $PASSFILE"

	for i in 1 2 3
	do
		openfpc-password -f $PASSFILE -a add && break
	done
}

function mksession(){
	if [ $CXINSTALLED == "1" ]
	then
		echo "[*] Creating OpenFPC Session DB"
		echo "    OpenFPC uses cxtracker to record session data. Session data is much quicker to search through than whole packet data stored in a database."
		echo "    All of the databases used in OpenFPC are controlled by an application called openfpc-dbmaint. "
		echo "    - Note that you will need to enter the credentials of a mysql user that has privileges to creted/drop databases"
		echo "      If you don't know what this is, it's likely root with the password that you were asked for while installing mysql"
		 	sudo openfpc-dbmaint create session /etc/openfpc/openfpc-default.conf && break
	fi
}

function endmessage(){
	echo -e "
--------------------------------------------------------------------------
[*] Installation Complete 

 ************************
 **      IMPORTANT     **
 ************************
 OpenFPC should now be installed and ready for *configuration*.
   
 1) Go configure /etc/openfpc/openfpc-default.conf
 2) Add a user E.g.

    $ sudo openfpc-password -a add -u admin \ 
	-f /etc/openfpc/openfpc.passwd  

 3) Make a database for connection:
    $ sudo openfpc-dbmaint create session /etc/openfpc/openfpc-default.conf
 4) Start OpenFPC
    $ sudo openfpc --action start
 5) Check status (authenticate with user/password set in step 2)
	$ openfpc-client -a status --server localhost --port 4242
 6) Go extract files and search for sessions!
    $ openfpc-client -a search -dpt 53 --last 600
    $ openfpc-client -a  fetch -dpt 53 --last 600
    $ openfpc-client --help
"

}

function easymessage(){
	echo "[*] Starting OpenFPC"
	sudo openfpc -a start

	echo "

	[*] Simple installation complete. 

    Here are a couple of tips to get started.

	$ openfpc-client -a status --server localhost --port 4242
    $ openfpc-client -a  fetch -dpt 53 --last 600
    $ openfpc-client -a search -dpt 53 --last 600
    $ openfpc-client --help
    "
}

function checkdeps()
{
	missdeps=""
	if [ "$DISTRO" == "DEBIAN" ] 
	then
		DEPS="daemonlogger tcpdump tshark libdatetime-perl libprivileges-drop-perl libarchive-zip-perl libfilesys-df-perl mysql-server libdbi-perl libterm-readkey-perl libdate-simple-perl libdigest-sha-perl libjson-pp-perl libdatetime-perl libswitch-perl libdatetime-format-strptime-perl" 

		# Check if some obvious dependencies are met	
		for dep in $DEPS
		do
			echo -e "[-] Checking for $dep ..."
			if  dpkg --status $dep > /dev/null 2>&1
			then
				echo -e "    $dep Okay"
			else
				DEPSOK=1
				echo -e "    ERROR: Package $dep is not installed."
				missdeps="$missdeps $dep"
			fi
		done	

	elif [ "$DISTRO" == "REDHAT" ] 
	then
		DEPS="httpd perl-Archive-Zip perl-DateTime perl-Filesys-Df perl-DateTime-Format-DateParse perl-TermReadKey perl-Date-Simple tcpdump wireshark"
		echo -e "[-] Checking status on RedHat"

		# Check if some obvious dependencies are met	
		for dep in $DEPS
		do
			echo -e "[-] Checking for $dep ..."
			if  rpm -q $dep > /dev/null 2>&1
			then
				echo -e "    $dep Okay
"			else
				DEPSOK=1
				echo -e "[!] ERROR: Package $dep is not installed."
				missdeps="$missdeps $dep"
			fi
		done	
	else
		echo -e "Package checking only supported on Debian/Redhat OSs"
		echo "Use --force to skip package checks, and fix any problems by hand"
	fi


	if [ "$DEPSOK" != 0 ]
	then
		echo -e "[-] --------------------------------"
		echo -e "Problem with above dependencies, please install them before continuing"
		if [ "$DISTRO" == "DEBIAN" ] 
		then
			echo -e "As you're running a distro based on Debian..."
			echo -e "Hint: sudo apt-get install the stuff that's missing above\n"
			echo -e " apt-get install $missdeps\n"
		else 
			echo -e "As you're running a distro based on RedHat..."
			echo -e "Hine 1) Enable rpmforge"
			echo -e "Hint 2) sudo yum install httpd perl-Archive-Zip"
			echo -e "Hint 3) sudo yum --enablerepo=rpmforge install perl-DateTime perl-Filesys-Df "	
		fi

		exit 1
	fi

	# Extra warning for cxtracker as it's not included in either of the distros we work with
	# 
	if which cxtracker
	then
		echo "[*] Found cxtracker in your \$PATH (good)"
		CXINSTALLED=1
	else
		echo -e "
###########################################################
# WARNING: No cxtracker found in path!
###########################################################
# Don't Panic! 
# This may be Okay if you expect it not to be found.
# cxtracker likely isn't included as part of your Operating System's
# package manager. Go grab it from www.openfpc.org/downloads.
# Without cxtracker OpenFPC will function, but you loose 
# the ability to search flow/connection data.
#
# All full packet capture and extraction capabilities will 
# still function without cxtracker.
# -Leon
###########################################################
"
	fi 
}

function doinstall()
{

	chkroot
	# Setup install for distro type
	if [ "$DISTRO" == "DEBIAN" ]
	then
		PERL_LIB_DIR="/usr/local/lib/site_perl"
    	OFPC_LIB_DIR="$PERL_LIB_DIR/OFPC"
	elif [ "$DISTRO" == "REDHAT" ]
	then
		PERL_LIB_DIR="/usr/local/share/perl5"
    	OFPC_LIB_DIR="$PERL_LIB_DIR/OFPC"
	fi

	# Unbuntu apparmor prevents tcpdump from reading and writing to files outside of $HOME.
	# this breaks openfpc.
	echo "[*] Disabling apparmor profile for tcpdump"
	sudo ln -s /etc/apparmor.d/usr.sbin.tcpdump /etc/apparmor.d/disable/
	sudo /etc/init.d/apparmor restart

	##################################
	# Check for Dirs
	# Check for, and create if required a /etc/openfpc dir
    if [ -d $CONF_DIR ] 
	then
		echo -e " -  Found existing config dir $CONF_DIR "
	else
		mkdir $CONF_DIR || die "[!] Unable to mkdir $CONF_DIR"
	fi

	# Check the perl_lib_dir is in the Perl path
	if  perl -V | grep "$PERL_LIB_DIR" > /dev/null
	then
		echo " -  Installing modules to $PERL_LIB_DIR"
	else
		die "[!] Perl include path problem. Cant find $PERL_LIB_DIR in Perl's @INC (perl -V to check)"
	fi	

	# Check four our include dir	
    if [ -d $OFPC_LIB_DIR ] 
	then
		echo -e " -  $OFPC_LIB_DIR exists"
	else
		mkdir --parent $OFPC_LIB_DIR || die "[!] Unable to mkdir $OFPC_LIB_DIR"
	fi

	# Check for init dir
	[ -d $INIT_DIR ] || die "[!] Cannot find init.d directory $INIT_DIR. Something bad must have happened."

	# Splitting GUI apart from main program
	#if [ -d $WWW_DIR ] 
	#then
	#	echo -e " *  Found $WWW_DIR"
	#else
	#	mkdir --parent $WWW_DIR || die "[!] Unable to mkdir $WWW_DIR"
	#fi


	####################################
	# Install files

	######## Modules ###########

	for file in $PERL_MODULES
	do
		echo -e " -  Installing PERL module $file"
		cp OFPC/$file $OFPC_LIB_DIR/$file
	done

	###### Programs ######

	for file in $PROG_FILES
	do
		echo -e " -  Installing OpenFPC Application: $file"
		cp $file $PROG_DIR
	done

	###### Config files ######

	for file in $CONF_FILES
	do
		basefile=$(basename $file)
		if [ -f $CONF_DIR/$basefile ] 
		then
			echo -e " -  Skipping Config file $CONF_DIR/$basefile already exists!"
		else
			echo -e " -  Installing OpenFPC conf: $file"
			cp $file $CONF_DIR
		fi
	done

	###### WWW files #####
	# I'm separating the GUI out from the main program.
	# 
	# for file in $GUI_FILES
	# do
	#	echo -e " -  Installing $file"
	#	cp -r www/$file $WWW_DIR/$file
	# done

	###### init #######

    for file in $INIT_SCRIPTS
    do
		echo -e " -  Installing $INIT_DIR/$file"
		cp etc/init.d/$file $INIT_DIR/$file
    done


	##### Distribution specific post installation stuff

	if [ "$DISTRO" == "DEBIAN" ]
	then

		#################################
		# Init scripts
		echo "[*] Updating init config with update-rc.d"

		for file in $INIT_SCRIPTS
		do
		 	update-rc.d $file defaults 

			if ! getent passwd openfpc >/dev/null
			then
				echo -e "[*] Adding user openfpc"
  				adduser --quiet --system --group --no-create-home --shell /usr/sbin/nologin openfpc
			fi
		done

	elif [ "$DISTRO" == "REDHAT" ]
	then
		echo "[*] Performing a RedHat Install"
		echo "[-] RedHat install is un-tested by me, I don't use use: Your millage may vary."
		PERL_LIB_DIR="/usr/local/share/perl5"


	fi

	
}

function remove()
{
	echo -e "[*] Stopping Services..."
	chkroot
	#for file in $INIT_SCRIPTS
	#do
	#	if [ -f $INIT_DIR/$file ] 
	#	then 
	#		echo -e "Stopping $file"
	#		$INIT_DIR/$file stop || echo -e " -  $file didn't stop, removing anyway"
	#	else
	#		echo -e " -  $INIT_DIR/$file doesn't exist - Won't try to stop"
	#	fi
	#done

	sudo openfpc -a stop

	echo -e "[*] Disabling OpenFPC GUI"
	if [ -f /etc/apache2/sites-available/openfpc.apache2.site ]
	then	
		a2dissite openfpc.cgi.apache2.conf
		service apache2 reload
	fi
	[ -f /etc/apache2/sites-available/openfpc.cgi.apache2.conf ] && rm /etc/apache2/sites-available/openfpc.cgi.apache2.conf


	echo -e "[*] Removing openfpc-progs ..."

	for file in $PROG_FILES
	do
		if [ -f $PROG_DIR/$file ] 
		then
			echo -e "    Removed   $PROG_DIR/$file"
			rm $PROG_DIR/$file || echo -e "unable to delete $PROG_DIR/$file"
		else
			echo -e "    Cant Find $PROG_DIR/$file"	
		fi
	done
	
	echo -e "[*] Removing PERL modules"
	for file in $PERL_MODULES
	do
		if [ -f $OFPC_LIB_DIR/$file ]
		then	
			rm $OFPC_LIB_DIR/$file  || echo -e "[!] Unable to delete $file"
		else
			echo -e "    Cant Find $OFPC_LIB_DIR/$file"
		fi
	done

	echo -e "[*] Removing WWW files"
	for file in $WWW_FILES
	do
		if [ -f $WWW_DIR/$file ]
		then	
			rm $WWW_DIR/$file  || echo -e "[!] Unable to delete $WWW_DIR/$file"
		else
			echo -e "    Cant Find $WWW_DIR/$file"
		fi
	done
	echo -e "[*] Removing CGI files"
	for file in $CGI_FILES
	do
		if [ -f $CGI_DIR/$file ]
		then	
			rm $CGI_DIR/$file  || echo -e "[!] Unable to delete $CGI_DIR/$file"
		else
			echo -e "    Cant Find $CGI_DIR/$file"
		fi
	done

	# Remove the password file if it has been created
	#[ -f $CONF_DIR/apache2.passwd ] && rm $CONF_DIR/apache2.passwd

	#echo -e "[*] Removing openfpc wwwroot"
	#if [ -d $WWW_DIR ] 
	#then
	#	rm -r $WWW_DIR  || echo -e "[!] Unable to delete $WWW_DIR"
	#	echo -e " -  Removed $WWW_DIR"
	#fi

	echo -e "[-] Updating init sciprts"
        if [ "$DISTRO" == "DEBIAN" ]
        then
                for file in $INIT_SCRIPTS
                do
			update-rc.d -f $file remove
                done
	
		if getent passwd openfpc >/dev/null
		then
			echo "[*] Removing user openfpc"
			deluser openfpc  > /dev/null
		fi
	
        elif [ "$DISTRO" == "REDHAT" ]
	then
		echo NOT DONE	
	fi
	echo -e "[-] -----------------------------------------------"

        for file in $INIT_SCRIPTS
        do
		if [ -f $INIT_DIR/$file ] 
		then
			echo -e " -  Removing $INIT_DIR/$file"
			rm $INIT_DIR/$file
		fi
        done

	echo -e "[*] Removal process complete"
}

function installstatus()
{
	SUCCESS=1

	echo -e "* Status"
	if [ -d $PROG_DIR ] 
	then
		echo -e "  Yes Target install dir $PROG_DIR Exists"	
	else
		echo -e "  No  Target install dir $PROG_DIR does not exist"
		SUCCESS=0

	fi

	echo "- Init scripts"
	for file in $INIT_SCRIPTS
	do
		if [ -f $INIT_DIR/$file ]
		then
			echo -e "  Yes $INIT_DIR/$file Exists"
		else
			echo -e "  No  $INIT_DIR/$file does not exist"
			SUCCESS=0
		fi	
	done

	echo -e "- Perl modules"	
	for file in $PERL_MODULES
	do
		if [ -f $OFPC_LIB_DIR/$file ]
		then
			echo -e "  Yes $OFPC_LIB_DIR/$file Exists"
		else
			echo -e "  No  $OFPC_LIB_DIR/$file does not exist"
			SUCCESS=0
		fi	
	done
	echo -e "- Program Files"
	for file in $PROG_FILES
	do
		if [ -f $PROG_DIR/$file ]
		then
			echo -e "  Yes $PROG_DIR/$file Exists"
		else
			echo -e "  No  $PROG_DIR/$file does not exist"
			SUCCESS=0
		fi	
	done

	echo -e "- Dependencies "
	for file in $REQUIRED_BINS
	do
		which $file > /dev/null
		if [ $? -ne 0 ] 
		then
			echo -e "  No  Application $file is not installed"
			SUCCESS=0
		else
			echo -e "  Yes Application $file is installed"
		fi	
	done

	echo 
	if [ $SUCCESS == 1 ] 
	then
	
		echo -e "  Installation looks Okay"
	else
		echo -e "  OpenFPC is not installed correctly. Check the above for missing things."
	fi
	echo
}

echo -e "
 *************************************************************************
 *  OpenFPC installer - Leon Ward (leon@openfpc.org) v$openfpcver
 *  A set if scripts to help manage and find data in a large network traffic
 *  archive. 

 *  http://www.openfpc.org 
"
	


if  [ "$DISTRO" == "AUTO" ]
then
	[ -f /etc/debian_version ]  && DISTRO="DEBIAN"
	[ -f /etc/redhat-release ] && DISTRO="REDHAT"

	if [ "$DISTRO" == "AUTO" ] 
	then
		die "[*] Unable to detect distribution. Please set it manually in the install script. Variable: DISTRO=<>"
	fi

	echo -e "[*] Detected distribution as $DISTRO\n"
fi

case $1 in  
    install)
		checkdeps
        doinstall
        endmessage
    ;;
    forceinstall)
    	doinstall
    	endmessage
    ;;
    remove)
    	remove
    ;;
    status)
    	installstatus
    ;;
	reinstall)
		echo [*] Running reinstall remove
		remove
		echo [*] Running reinstall install
		checkdeps
		doinstall
		endmessage
	;;
	easyinstall)
		echo [*] Performing an easyinstall
		checkdeps
		doinstall
		mkuser
		mksession
		easymessage
	;;
     *)
        echo -e "
[*] openfpc-install usage:
    $ openfpc-install <action> <gui>

    Where <action> is one of the below: 
    easyinstall   - Install and auto-configure. Good for first time users
    install       - Install OpenFPC, no configuration
    forceinstall  - Install OpenFPC without checking for dependencies
    remove        - Uninstall OpenFPC 
    status        - Check installation status
    reinstall     - Re-install OpenFPC (remove then install in one command)

[*] Examples: 
    Easy Install: Get OpenFPC running for the 1st time, many defaults are 
    selected for you. Just answer a couple of questions.

    $ sudo ./openfpc-install easyinstall

    Install OpenFPC without asking questions. You'll have to configure it afterwards
    $ sudo ./openfpc-install gui

    Remove OpenFPC
    $ sudo ./openfpc-install remove
"	
    ;;
esac
