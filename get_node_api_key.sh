#!/bin/bash

## This script requests an API password from user
## It then does a POST request to the waves node which returns a hash
## The hash can be used to do further POST requests toi the node

## VARS
node=http://localhost
nodeapiport=6869
baseuri=/utils/hash/secure

## DEPS
curl=`type -P curl`

if [[ ! -f $curl ]]; then echo -e "\nMissing binary 'curl'. Please install and restart $0. Exit now\n" && exit; fi



## START MAIN

echo -e "\nSpecify the node API password you want to use : \c" && read apipwd

if [[ $apipwd != '' ]]; then
	
	apihash=`$curl -sd ${apipwd} -H "Accept: application/json" -X POST ${node}:${nodeapiport}/utils/hash/secure | sed 's/.*hash.*://;s/}//;s/\"//g'`

	if [[ $apihash == "" ]]; then
		echo -e "\nCould not retreive api-key-hash from node."
                echo -e "Is the api server running?"
		echo -e "Is the server port (${port}) correct?" 
	else
                echo -e "\nAPI key hash : ${apihash}\n"
	fi
else
	echo -e "\nNo password specified.\n"
fi
