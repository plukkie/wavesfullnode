#!/bin/bash

# this script downloads latest waves blochchain as tar archive
# then extracts in data folder
# this will not verify the blocks, so it should only be used
# from a verified source and not from an untrusted 3rd party location
#

cf=.config
ef=.env
cut=`type -P cut` && if [[ ! -f $cut ]]; then echo -e "\nMissing binary 'cut'. Please install and restart. Exit now\n" && exit; fi
cc='-d '=' -f2'

conf_da='declared-address = '
conf_pwd='password = '
conf_seed='seed = '
conf_name='node-name = '
conf_apikey_hash='api-key-hash = '
wavesuser=`grep "wavesuser=" $cf | $cut $cc`
wavesgroup=`grep "wavesgroup=" $cf | $cut $cc`
wavesservice=`grep "wavesservice=" $cf | $cut $cc`
waveslib=`grep "wavespath=" $ef | $cut $cc`
wavesdata=${waveslib}/data
myhome=`grep "home=" $cf | $cut $cc` && if [[ $myhome == "\$HOME" ]]; then myhome=$HOME; fi
mydownload=`grep "downloadsubpath=" $cf | $cut $cc`
downloadpath=${myhome}${mydownload}
blockchainfile=`grep "blockchainfile=" $cf | $cut $cc`
hashextension=`grep "hashextension=" $cf | $cut $cc`
blockchainhashfile=${blockchainfile}${hashextension}
wavesdomain=`grep "wavesdomain=" $cf | $cut $cc`
blockchain=${wavesdomain}/${blockchainfile}
blockchainhash=${wavesdomain}/${blockchainhashfile}
myhashfile=${blockchainfile}.my${hashextension}
wavesdockerimage=`grep "wavesdockerimage=" $ef | $cut $cc`
wavesconfpath=`grep "wavesconfpath=" $ef | $cut $cc`
wavesconffile=`grep "wavesconffile=" $cf | $cut $cc`
walletfile=`grep "walletfile=" $cf | $cut $cc`
imagetag=`grep "wavesimagetag=" $ef | $cut $cc`
wavesconf=$wavesconfpath/$wavesconffile
wavesgitpath=`grep "wavesgitpath=" $cf | $cut $cc`
apiport=`grep "apiport=" $ef | $cut $cc`
continued=false
statefullimport=false
keepconfig=true
installtype=unknown
apipwd=

#dependencies
tar=`type -P tar`
who=`type -P who`
sha1sum=`type -P sha1sum`
cat=`type -P cat`
cut=`type -P cut`
docker=`type -P docker`
service=`type -P service`
dc=`type -P docker-compose`
grep=`type -P grep`
dpkg=`type -P dpkg`
apt=`type -P apt`
au="`type -P apt-get` -y"
sc=`type -P systemctl`
cp=`type -P cp`
rm=`type -P rm`
mv=`type -P mv`
chown=`type -P chown`
chmod=`type -P chmod`
base58=`type -P base58`
useradd=`type -P useradd`
groupadd=`type -P groupadd`
usermod=`type -P usermod`
curl=`type -P curl`
sed=`type -P sed`
pwd=`type -P pwd`

if [[ ! -f $tar ]]; then echo -e "\nMissing binary 'tar'. Please install and restart. Exit now\n" && exit; fi
if [[ ! -f $base58 ]]; then echo -e "\nMissing binary 'base58'. Please install and restart. Exit now\n" && exit; fi
if [[ ! -f $sha1sum ]]; then echo -e "\nMissing binary 'sha1sum'. Please install and restart. Exit now\n" && exit; fi
if [[ ! -f $cat ]]; then echo -e "\nMissing binary 'cat'. Please install and restart. Exit now\n" && exit; fi
if [[ ! -f $cut ]]; then echo -e "\nMissing binary 'cut'. Please install and restart. Exit now\n" && exit; fi
if [[ ! -f $service ]]; then echo -e "\nMissing binary 'service'. Please install and restart. Exit now\n" && exit; fi
if [[ ! -f $grep ]]; then echo -e "\nMissing binary 'grep'. Please install and restart. Exit now\n" && exit; fi
if [[ ! -f $dpkg ]]; then echo -e "\nMissing binary 'dpkg'. Please install and restart. Exit now\n" && exit; fi
if [[ ! -f $curl ]]; then echo -e "\nMissing binary 'curl'. Please install and restart. Exit now\n" && exit; fi

arg1=$1
arg2=$2
arg3=$3


function startup_mode {

	if [[ $arg1 == '' ]] || [[ $arg1 == help ]]; then
		
		echo -e "\n Welcome to waves installer. Your tool to install, upgrade and statefull ledger import."
		echo -e " usage : $0 <option>\n"
		echo -e " <option> :\n ----------\n"
		echo -e " install native <version>	: Installs debian package for specified version from mainnet"
		echo -e "                                  i.e.: $0 install native 1.2.17"
		echo -e "                                  A previous version will be uninstalled automatically."
		echo -e "                                  You can choose to keep the current waves config or"
		echo -e "				  overwrite it with a new one."
		echo -e "				  If there is already a ledger db, you can also choose to keep"
		echo -e "				  it or overwrite it with the latest."
		echo -e "				  You will be asked for the required settings.\n"
		echo -e " install container <version>	: Installs docker container <version> from mainnet."
		echo -e "				  If no version specified, the latest is used."
		echo -e "                                  You can choose to keep the current waves config or"
		echo -e "				  overwrite it with a new one."
		echo -e "				  If there is already a ledger db, you can also choose to keep"
		echo -e "				  it or overwrite it with the latest."
		echo -e "				  You will be asked for the required settings.\n"
		echo -e " statefull import		: Imports a statefull copy of the ledger."
		echo -e "                                  This can take couple of hours.\n"
		exit

	elif [[ $arg1 == "install" ]] && [[ $arg2 == "native" ]] && [[ $arg3 != '' ]]; then

		installtype=native

		dependency_check native

		echo -e "\nStarting native waves installation for version $arg3\n" && sleep 1
		local result=`$dpkg -l $wavesservice`

		if [[ ${#result} != 0 ]]; then  ##Old version was already in stalled
		
			echo -e "Previous installation of $wavesservice found. Uninstalling...\n" && sleep 1
			sudo $service $wavesservice stop && sleep 1
			sudo $dpkg -r $wavesservice && sleep 1

		else  ##No old waves version found
			echo -e "No old version of the $wavesservice was found on the system...\n" && sleep 2
		fi
		
		check_waves_conf_exists
		check_waves_data_exists

		local version=v${arg3}
		local debianpackage=${wavesservice}_${arg3}_all.deb
		local url=${wavesgitpath}${version}/${debianpackage}

		make_path ${downloadpath}  ## Create folders if needed
		get_file ${url} ${downloadpath}/${debianpackage}
		sudo $dpkg -i ${downloadpath}/${debianpackage}
		if [[ $? != 0 ]]; then echo -e "Failure installing $debianpackage. Exit.\n" && exit; fi
		sudo $sc enable $wavesservice.service

	elif [[ $arg1 == "install" ]] && [[ $arg2 == "container" ]]; then  ##install container

		if [[ $arg3 == '' ]]; then arg3=latest; fi
	
		if [[ ${#docker} == 0 ]]; then ## Docker is not installed
			echo
			echo "Docker seems not installed on system."
			echo "Also docker-compose is needed."
			echo "Please install first and then run script again."
			echo "Here are the ubuntu pages for docker : https://docs.docker.com/engine/install/ubuntu/"
			echo "Here are the pages for docker-compose : https://docs.docker.com/compose/install/"
			echo
			exit
		fi

		dependency_check container

		local currenttag=$imagetag  ##value from .env file
		
		if [[ $currenttag != $arg3 ]]; then ##edit .env file with new container version
			echo -e "Change current container version $currenttag into requested version $arg3 in $ef...\n"
			sed -i "s/wavesimagetag=${currenttag}/wavesimagetag=${arg3}/" $ef && sleep 2
		fi

		local currentuser=`$who am i|awk '{print$1}'`
		sudo $groupadd docker >/dev/null 2>&1
		sudo $usermod -aGdocker $currentuser
		echo -e "\nUser '$currentuser' added to docker group. This ensures you do not have to be root to start the container :-)"
		echo -e "It can be that you need to logout/login as user '$currentuser' when the installation finished.\n" && sleep 2
		echo
	
		if [[ $arg3 == latest ]]; then echo "Pulling latest image..." && $dc pull; fi  ## always check for latest version

		installtype=container
		keepconfig=true

		check_waves_user
		check_waves_conf_exists
		check_waves_data_exists

	elif  [[ $arg1 == "statefull" ]] && [[ $arg2 == "import" ]]; then
		
		echo -e "\n Are you sure you want to import the full waves blockchain from tar archive?"
		echo -e " This can take some hours, depending on your node cpu power.\n"
		echo -e " The following actions will be performed:"
		echo -e "  - download ${blockchain}"
		echo -e "  - download ${blockchainhash} verification file"
		echo -e "  - verify blockchain archive integrity"
		echo -e "  - stop Waves service"
		echo -e "  - keep a backup of your current waves/data folder -> ${wavesdata}.old"
		echo -e "  - empty ${wavesdata} folder"
		echo -e "  - extract blockchain archive to ${wavesdata}"
		echo -e "  - start Waves service"
		echo -e "  - delete the downloaded archive"
		echo -e "  - delete the backup waves/data folder -> rm ${wavesdata}.old"
		echo " -----------------------------------------------------------------------------"
		echo -e " Proceed with statefull ledger import [y/n]? \c" && read choice

		if [[ $choice == [Yy]* ]]; then

			installtype=unknown
			statefullimport=true
			keepconfig=true

			echo -e "\nStarting the ststefull ledger import...\n"
			sleep 1
		else
			echo -e "\nOk, exit...\n"
			exit 0
		fi
	else
		exit
	fi
}


## Function that checks if required software dependencies are installed
## call as: dependency_check <install_type>
## args:
## - install_type: container or native, which reads key value from .config
function dependency_check {

	local arg1=$1
	## Cut after '=' sign, strip '(' and ')', replace all spaces with one space '// / /'
	local dep_array=`grep "deps_$arg1=" $cf | $cut $cc | sed 's/(//' | sed 's/)//'` && dep_array=(${dep_array// / })
	local elements=${#dep_array[@]}  ##How many software dependencies found

        if [[ $elements > 0 ]]; then

		echo -e "\nChecking software dependencies needed..." && sleep 1
                echo -e "Running apt-get update..." && sleep 1
                sudo $au update

                for softpackage in "${dep_array[@]}"
			do
                        local result=`$dpkg -l $softpackage`

                        if [[ ${#result} == 0 ]]; then
                        	echo -e "$softpackage missing. Installing...\n" && sleep 1
                                sudo $au install $softpackage
                                echo
                        else
                                echo -e "$softpackage is installed...OK\n" && sleep 1
                        fi
                done
	fi
}


function show_post_install_comments {
	
	if [[ $installtype == native ]]; then

		echo -e "\n------------------------------------------------------------"
		echo " $wavesservice is installed as native service."
		echo
		echo " start waves service          : service $wavesservice start"
		echo " stop waves service           : service $wavesservice stop"
		echo " restart waves service        : service $wavesservice restart"
		echo " show waves status            : service $wavesservice status"
		echo
		echo " package used                 : ${wavesservice}_${arg3}_all.deb"
		if [[ $keepconfig == true ]]; then echo " waves configfile             : $wavesconf [ reused old configfile ]"; fi
		if [[ $keepconfig == false ]]; then echo " waves configfile             : $wavesconf [ new configfile ]"; fi
		echo " waves lib path               : $waveslib"
		if [[ $statefullimport == true ]]; then echo " waves data path              : $wavesdata [ new ledger imported ]"; fi
		if [[ $statefullimport == false ]]; then echo " waves data path              : $wavesdata [ reused current ledger ]"; fi
		echo
		echo " To upgrade to a new version  : $0 $arg1 $arg2 <new version>"
		echo

	elif [[ $installtype == container ]]; then
		
		local dc
		echo
		echo -e "\n------------------------------------------------------------"
		echo " $wavesservice is installed as docker container service."
		echo " docker-compose is used to manage the service."
		echo " Always start from the waves installation path."
		echo " Currently this is path : `$pwd`"
		echo
		echo " start waves service          : docker-compose up -d"
		echo " stop waves service           : docker-compose down"
		echo " restart waves service        : docker-compose restart"
		echo " show waves container status  : docker-compose ps"
		echo " show container logs          : docker-compose logs"
		echo " show docker-compose help     : docker-compose --help"
		echo " show docker-compose config   : docker-compose config"
		echo " show docker images           : docker-compose images"
		echo
		echo " docker image used            : $wavesdockerimage [ tag: $imagetag ]"
		echo " docker-compose .env file     : $ef [ edit to change container key/values ]"
		echo " docker-compose yml file      : docker-compose.yml [ edit for composer services ]"
		echo " waves installer configfile   : .config [ edit for installer behaviour ]"
		if [[ $keepconfig == true ]]; then echo " waves configfile             : $wavesconf [ reused old configfile ]"; fi
		if [[ $keepconfig == false ]]; then echo " waves configfile             : $wavesconf [ new configfile ]"; fi
		echo " waves lib path               : $waveslib"
		if [[ $statefullimport == true ]]; then echo " waves data path              : $wavesdata [ new ledger imported ]"; fi
		if [[ $statefullimport == false ]]; then echo " waves data path              : $wavesdata [ reused current ledger ]"; fi
		echo
		echo " To upgrade to a new version  : $0 $arg1 $arg2 <new version>"
		echo


	fi

}


function check_waves_conf_exists {

		if [[ -f $wavesconf ]]; then  ##Found waves config file
			local loop=true
			echo -e "\nFound $wavesservice config file '$wavesconf'."
			while [[ $loop == true ]];
				do
		        		echo -e "Do you want to [u]se this one, [o]verwrite with a default or [e]xit [e/o/e]? \c" && read choice

                			if [[ $choice == [uU]* ]]; then
                        			echo -e "Keeping current config file\n"
                        			sleep 2
						loop=false
					elif [[ $choice == [oO]* ]]; then ##Use default config
                        			echo -e "\nCreating backup copy of $wavesconf to $wavesconf.bak.\n"
                        			sudo $mv $wavesconf $wavesconf.bak
						echo -e "Copy default config file to $wavesconf.\n"
						sudo $cp waves.conf $wavesconf && sudo $chown $wavesuser.$wavesgroup $wavesconf && $chmod o-rwx $wavesconf
						sleep 2
						keepconfig=false
						loop=false
					elif [[ $choice == [eE]* ]]; then
						echo -e "\nOK...exit\n"
						exit
					else
						loop=true
					fi
				done
		else  ##No waves configfile found
			
			keepconfig=false
			
			if [[ ! -d $wavesconfpath ]]; then
				make_path $wavesconfpath
				sudo $chown $wavesuser.$wavesgroup $wavesconfpath
			fi

			echo -e "Copy default config file to $wavesconf.\n"
                        sudo $cp waves.conf $wavesconf && sudo $chown $wavesuser.$wavesgroup $wavesconf && $chmod o-rwx $wavesconf && sleep 2
		fi
}

function check_waves_data_exists {

		if [[ -d $wavesdata ]]; then  ##found already a data folder
			
			local loop=true
			echo -e "\nFound $wavesservice data folder : $wavesdata\n"
			
			while [[ $loop == true ]];
				do
					echo -e "[O]verwrite current data folder, [u]se this one or [e]xit [o/u/e]? \c" && read choice

					if [[ $choice == [Oo]* ]]; then
						sudo $rm -rdf $wavesdata
						statefullimport=true
						loop=false
					elif [[ $choice == [uU]* ]]; then
						echo -e "Ok, will keep current data folder." && sleep 2
						statefullimport=false
						if [[ $keepconfig == false ]]; then  ##Default config was copied, need to delete wallet.dat
							[ -f $waveslib/wallet/$walletfile ] && sudo $rm $waveslib/wallet/$walletfile
						fi
						loop=false
					elif [[ $choice == [eE]* ]]; then
                                                echo -e "\nOK...exit\n"
                                                exit
					else
						loop=true
					fi
				done
		else
			statefullimport=true
		fi
}


function check_waves_user {
	local u=`$grep $wavesuser /etc/passwd`
	if [[ $u == "" ]]; then
		$groupadd -f -g 143 $wavesgroup
		$useradd -M -u 143 -g 143 $wavesuser
	fi	
}

## This function retreives the api key from the local api server
## The node api server should be up and reachable
## The password was requested by user input
## The return from the server is an encoded hash
function set_api_hash {

	if [[ $apipwd != "" ]]; then
		echo -e "\nWaiting 20 seconds for API server start..." && sleep 20

		apihash=`$curl -sd ${apipwd} -H "Accept: application/json" -X POST http://localhost:${apiport}/utils/hash/secure | sed 's/.*hash.*://;s/}//;s/\"//g'`
		
		if [[ $apihash == "" ]]; then
			echo -e "\nCould not retreive api-key-hash from node."
			echo -e "Is the api server running?"
			echo -e "Run the POST call manually to the server with command:"
			echo -e "curl -d \"<your passsword>\" -X POST http://localhost:${apiport}/utils/hash/secure\n"
			echo -e "then add the retreived hash to $wavesconf : ${conf_apikey_hash} \"<keyhash>\n"
		else
			sed -i "s/${conf_apikey_hash}\"\"/${conf_apikey_hash}\"${apihash}\"/" $wavesconf
			echo -e "\nAdded api key hash to $wavesconf\n" && sleep 1
		fi
	fi
}


## This function collects all key values for the node configuration
## Then edit waves.conf file
function collect_config_values {
	
	local ETH_INT=`ip addr show | grep -i UP | grep -iv docker | grep -iv loop | grep -iv master | grep -iv br- | cut -d':' -f2` && ETH_INT=${ETH_INT%%[[:space:]] *}
	local IP=`ifconfig ${ETH_INT} | grep -i inet.*netmask | awk '/inet/{print $2}'`
	local da ## declared-address
	local wp ## wallet password
	local wh ## wallet seed hash
	local nn ## node name
	local stext='declaredaddress='
	local fullenvline=`grep -i $stext $ef`  ##what is the configured declared-address for container version
	apipwd=""

	echo -e "\nThe node needs some values for the configuration.\n"
	echo -e " Node name you want to use : \c" && read nn
	echo -e " Public IP address to use <Enter for $IP> : \c" && read da
	
	if [[ $da == "" ]]; then
		sed -i "s/${fullenvline}/${stext}$IP/" $ef  ##add node ip to .env file
		da=$IP:6868
	else
		sed -i "s/${fullenvline}/${stext}$da/" $ef  ##add node ip to .env file
		da=$da:6868
	fi

	echo -e " Wallet password to use : \c" && read wp
	echo -e " Wallet seed, will be hashed to base58 string : \c" && read ws
	
	if [[ $ws != "" ]]; then  ##was not left empty
		local IFS=':' ## Delimiter to split the returnen base58 hash from the python app
		local array
		read -ra array <<< `python3 encodebase58.py $ws` > /dev/null 2>&1 && wh=${array[1]//[[:space:]]} ## base58 string returned from python
		local IFS=' '
	fi
	
	echo -e " API server password for POST access, will be set hashed in config : \c" && read apipwd

	## Edit configfile
	if [[ -f $wavesconf ]]; then

		echo -e "\nAdding values to $wavesconf...\n"

		if [[ $nn != "" ]]; then echo " - add ${conf_name}..." && sed -i "s/${conf_name}\"\"/${conf_name}\"$nn\"/" $wavesconf && sleep 1; fi
		if [[ $da != "" ]]; then echo " - add ${conf_da}..." && sed -i "s/${conf_da}\"\"/${conf_da}\"$da\"/" $wavesconf && sleep 1; fi
		if [[ $wp != "" ]]; then echo " - add ${conf_pwd}..." && sed -i "s/${conf_pwd}\"\"/${conf_pwd}\"${wp}\"/" $wavesconf && sleep 1; fi
		if [[ $ws != "" ]]; then echo " - add ${conf_seed}..." && sed -i "s/${conf_seed}\"\"/${conf_seed}\"${wh}\"/" $wavesconf && sleep 1; fi	

		echo -e "\nValues are added succesfully to $wavesconf\n" && sleep 2
	else
		echo -e \n"Warning. The configuration file '$wavesconf' was not found."
		echo -e "Start script again and the file will be created\n"
		exit
	fi
}


function make_path {
	local path=$1
	local patharray=(${path//\// }) #create array, replace '/' with space
	local pathcount=${#patharray[@]}
	local dir

	for i in "${patharray[@]}"
	  do
	    dir=${dir}/${i}
	    if [[ ! -d ${dir} ]]; then #folder doesn't exist
		echo "creating folder ${dir}..." && sleep 1 && sudo mkdir ${dir}
		exitcode=$?
        	if [ $exitcode != 0 ]; then
                	echo -e "Could not create dir ${dir}. Are you root? Exit..\n" && sleep 1
                	exit ${exitcode}
		fi
	    fi
	done
}

function get_file {
	local src=$1
	local dst=$2

	echo -e "Starting download for $src to $dst...\n" && sleep 1

	if [[ -f $dst ]]; then
		echo -e "\n$dst exists. Will try to resume...\n" && sleep 1
		wget -c -O $dst $src
	else
		wget -O $dst $src
	fi

	exitcode=$?
	sleep 1
	
	if [[ $exitcode != 0 ]]; then
		echo -e "Failures getting file $src. Exit...\n" && sleep 1
		exit
	fi
}

## This function will guess if we run waves native or as container
## Then set variables accordingly
function get_installation_type {
	echo -e "\nChecking if we run the node as container or native..." && sleep 1

	sudo $service $wavesservice status &>/dev/null
	
	local result=`sudo $dpkg -l $wavesservice`

	if [[ ${#result} != 0 ]]; then ##found native waves service
		echo -e "Detected native $wavesservice service installation type..." && sleep 1
		echo -e "OK\n"
		
		installtype=native

	elif [[ -f $docker ]]; then
		echo -e "Could not detect native installation of $wavesservice." && sleep 1
		echo -e "Detected docker on system. Checking for $wavesservice container image..." && sleep 1

		image=`$docker images $wavesdockerimage -q`
		
		if [[ ${#image} == 0 ]]; then
			echo -e "Could not find a waves docker image. Install waves first."
			echo -e "Hint: is the var 'wavesdockerimage' pointing to correct docker image?\n"
			exit
		else
			echo -e "Detected container installation type of $wavesservice..." && sleep 1
			echo -e "OK\n"

			echo -e "Checking if docker-compose is available..." && sleep 1
			if [[ ! -f $dc ]]; then
				echo "Missing docker-compose. Please install and restart." 
				echo "refer to https://docs.docker.com/compose/install/ for intructions."
				echo "For linux this is the command to install:"
				echo "sudo curl -L "https://github.com/docker/compose/releases/download/1.28.4/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose"
				echo -e "\nExit now\n"
				exit
			fi

			installtype=container
		fi
	else
		echo -e "Not able to detect how waves was installed."
		echo -e "Please install first waves from image or as container, then run this script again."
		sleep 1 && echo -e "Exit.\n"
		exit
	fi
}

##### Start Main Program #####

startup_mode

if [[ $installtype == unknown ]]; then get_installation_type; fi
if [[ $keepconfig == false ]]; then collect_config_values; fi

## Create folders if needed
make_path ${waveslib}

## Check folder user.group is waves
if [[ $(stat -c '%U' ${waveslib}) != ${wavesuser} ]]; then
	echo "Change ${waveslib} to user/group ${wavesuser}.${wavesgroup}..." && sleep 1
	sudo chown -R ${wavesuser}.${wavesgroup} ${waveslib}
fi

if [[ -d $wavesdata ]]; then

	if [[ $(stat -c '%U' ${wavesdata}) != ${wavesuser} ]]; then
        	echo "Change ${wavesdata} to user/group ${wavesuser}.${wavesgroup}..." && sleep 1
        	sudo chown -R ${wavesuser}.${wavesgroup} ${wavesdata}
	fi
fi

## Create folders if needed
make_path ${downloadpath}

if [[ $statefullimport == true ]]; then  ## Begin if statefullimport=true

	## download blockchain files
	get_file $blockchain $downloadpath/$blockchainfile
	get_file $blockchainhash $downloadpath/$blockchainhashfile

	## Link downloaded blockchain file in the hashfile and validate hash
	if [[ -f $downloadpath/$myhashfile.OK ]]; then
		echo -e "\nFound hash verification file $downloadpath/$myhashfile.OK" && sleep 1
		echo -e "No need to verify again.\n" && sleep 1
	else
		sha1hashline="`$cat $downloadpath/$blockchainhashfile | cut -f1 -d" "` $downloadpath/$blockchainfile"
		echo "$sha1hashline" > $downloadpath/$myhashfile
		echo -e "Validating hash for $blockchainfile...\nPlease be patient, this can take some time.\n"
		$sha1sum -c $downloadpath/$myhashfile
		if [[ $? != 0 ]]; then
			echo -e "Sha1sum did not match. Please download blockchain files again. Exit..\n"
			exit
		else
			touch $downloadpath/$myhashfile.OK
			echo -e "Validation check is OK.\n" && sleep 1
		fi
	fi

	## STOP Waves service
	if [[ $installtype == native ]]; then sudo $service $wavesservice stop; fi
	if [[ $installtype == container ]]; then sudo $dc down; fi

	# keep old data folder as backup
	if [[ -d ${wavesdata}.old ]]; then  ##Found old datafolder
	
		if [[ -d ${wavesdata} ]]; then  ##Found current data folder
			echo "Found old ${wavesdata}.old folder, delete..." && sleep 2
			sudo $rm -rdf ${wavesdata}.old
			echo "Backup data folder : mv ${wavesdata} -> ${wavesdata}.old" && sleep 2
			sudo $mv ${wavesdata} ${wavesdata}.old
		fi
	
	else  ##No old data folder found
		if [[ -d ${wavesdata} ]];  then
			echo "Backup data folder : mv ${wavesdata} -> ${wavesdata}.old" && sleep 2
			sudo $mv ${wavesdata} ${wavesdata}.old
		fi
	fi

	## Extract blockchain archive
	echo -e "\nExtract blockchain to folder $waveslib...\n" && sleep 1
	sudo $tar -xvf $downloadpath/$blockchainfile -C $waveslib
	echo "Change ${wavesdata} to user/group ${wavesuser}.${wavesgroup}..." && sleep 1
	sudo chown -R ${wavesuser}.${wavesgroup} ${wavesdata}
	echo "Finished extracting statefull copy to data folder." && sleep 2

fi  ## End if statefullimport=true

# START waves service
if [[ $installtype == native ]]; then echo -e "\nStart $wavesservice service.." && sudo $service $wavesservice start; fi
if [[ $installtype == container ]]; then echo -e "\nStart $wavesservice container.." && sudo $dc down && sudo $dc up -d; fi

if [[ $keepconfig == false ]]; then set_api_hash; fi

# delete blockchain binary
if [ -f "${downloadpath}/${blockchainfile}" ]; then
	echo "Deleting blockchain file: ${downloadpath}/${blockchainfile}*..."
	sudo $rm -f ${downloadpath}/${blockchainfile}*
fi

# delete old data folder, only if new data folder found
if [[ -d ${wavesdata} ]]; then

	if [ -d ${wavesdata}.old ]; then
		echo "Deleting old blockchain data: ${wavesdata}.old..." && sleep 2
		sudo $rm -rdf ${wavesdata}.old
	fi
fi

echo -e "\nDone :-)\n"

show_post_install_comments

