#!/usr/bin/env bash

#Variable definitions:

	# Grabs password for openssl file from test.keychain
		PASS=$(security 2>&1 >/dev/null find-generic-password -ga opensslUser -l openssl $HOME/Library/Keychains/test.keychain | grep 'password:' | sed -E 's/password:.+"(.+)"$/\1/')
	#Keychain path
		KP=""
	#Encrypted file path
		EP=""
	#Decrypted file path
		DP=""
	#Collated keychain-dump output.
		OUT=""
	#List of account-id names parsed from $OUT
		nameList=""
	#Array built from nameList
		nameArray=""
	#List of accounts parsed from $OUT
		accountList=""
	#Array built from accountList
		accountArray=""
	#List of passwords parsed from $OUT
		passwordList=""
	#Array built from passwordList
		passwordArray=""


#Subroutines:

	#Displays help output.
		help()
			{
				echo
				printf "\t\e[4m%s\e[0m\n" "Keychain Export Script"
				echo -e "\t\tCreator:  James White"
				echo -e "\t\tYear: 2013"
				echo -e "\t\tPlease contact at jwhite007@comcast.net, if you have any questions."
				echo
				echo
				echo -e "\tUsage:"
				echo -e "\t\tExport Keychain Passwords to an Encrypted tsv file."
				echo -e "\t\tDecrypt that file to terminal or to a plain-text tsv file."
				echo
				echo -e "\tOptions:"
				echo -e "\t\t-e  = Export Keychain Passwords"
				echo -e "\t\t\texample:  kc.sh -e (~/Library/Keychain/test.keychain will be used and Output will be to current directory)"
				echo -e "\t\t\texample:  kc.sh -e /Path/To/Keychain (Output will be to current directory)"
				echo -e "\t\t\texample:  kc.sh -e /Path/To/Keychain /Desired/Path/To/Directory/For/Encrypted/File/"
				echo
				echo -e "\t\t-dt = Decrypt to Terminal"
				echo -e "\t\t\texample:  kc.sh -dt (When encrypted file is in current directory)"
				echo -e "\t\t\texample:  kc.sh -dt /Path/To/Directory/Of/Encrypted/File/"
				echo
				echo -e "\t\t-df = Decrypt to TSV file"
				echo -e "\t\t\texample:  kc.sh -df (When encrypted file is in current directory and output will be to current directory)"
				echo -e "\t\t\texample:  kc.sh -df /Path/To/Directory/Of/Encrypted/File/ (Output will be to current directory)"
				echo -e "\t\t\texample:  kc.sh -df /Path/To/Directory/Of/Encrypted/File/ /Desired/Path/ToDirectory/For/Plain-Text/TSV/"
				echo
				echo -e "\t\t-h  = Help output"
			}

	#Parses out arrays to tab-delimited format.
		arrayParser()
			{
				echo -e "Name:\tAccount:\tPassword:"
				nameArrayLength=`echo ${#nameArray[@]}`
				d=$(($nameArrayLength-1))
				c=0
				while [[ "$c" -le "$d" ]]; do
					for i in ${nameArrayLength[*]}; do
						echo -e "${nameArray[$c]}\t${accountArray[$c]}\t${passwordArray[$c]}"
						c=$(($c+1))
					done
				done
			}

case "$1" in
	"" )
		echo
		echo -e "\t<<<  PLEASE SUPPLY AT LEAST ONE OPTION  >>>"
		echo
		help
		;;

	-e )
		if [[ ! "$3" ]]; then
			if [[ ! "$2" ]]; then
				KP=$HOME/Library/Keychains/test.keychain
				EP=""
			else
				KP="$2"
			fi
		else
			KP="$2"
			EP="$3"
		fi

		# Collates keychain dump and isolates those blocks with or without certain attributes:
		OUT=$(security dump-keychain -d "$KP" | sed -E $'s/(keychain:)/\\\r\\\n\\1/g' | awk 'BEGIN { RS="\r"; } {if (/inet|genp/ && /data:/ && !/token/\
		&& !/"svce"<blob>="ids"/ && !/"svce"<blob>="AirPort Base Station"/ && !/"svce"<blob>="Apple Persistent State Encryption"/ && !/"svce"<blob>="com.apple.iAdIDRecords"/\
		&& !/"svce"<blob>="PersonalFormsAutoFillDatabase"/ && !/"type"<uint32>="note"/) { print RS $0; }}')

		# Scans collated blocks and extracts data into various arrays:
		# The echo of "$OUT" could initially be piped directly into an array; however, elements with spaces are entered into the array as separate elements delimited by
		#	those spaces.  Escape of those spaces using either awk or sed did not solve the problem.  Reading echo "OUT" into an array works much better.
		nameList=$(echo "$OUT" | awk '/attributes:/{getline;print}' | sed -E 's/.+"(.+)"$/\1/')
		while read line; do
			nameArray+=("$line")
		done <<< "$nameList"

		accountList=$(echo "$OUT" | grep acct | sed -E 's/"acct".+"(.+)"$/\1/')
		while read line; do
			accountArray+=("$line")
		done <<< "$accountList"

		passwordList=$(echo "$OUT" | awk '/data:/{if (getline <=0 || $0 == "") print "+++++"; else print;}' | sed -E 's/"(.+)"$/\1/')
		while read line; do
			passwordArray+=("$line")
		done <<< "$passwordList"

		# Checks to see if each array has same length.  If not, then exits with message.
		if [[ ("${#nameArray[@]}" = "${#accountArray[@]}") && ("${#accountArray[@]}" = "${#passwordArray[@]}") ]]; then
			:
		else
			echo "There was a problem with the export.  Please contact support:  jwhite007@comcast.net"
			exit 1
		fi

		#Assigns arrayParser output to a variable
		TEXT=$(arrayParser)

		#Pipes output to encrypted openssl file
		echo "$TEXT" | openssl enc -aes-256-cbc -salt -pass pass:"$PASS" -out "$EP"passwords.tsv.enc
		;;

	-dt )
		if [[ -z "$2" ]]; then
			EP=""
		else
			EP="$2"
		fi

		# Decrypts openssl file to screen
		TEXT=$(openssl enc -aes-256-cbc -d -pass pass:$PASS -in "$EP"passwords.tsv.enc)
		echo "$TEXT" | awk 'BEGIN { FS = "\t" } ; { printf "%-30s %-30s %-30s\n", $1, $2, $3 }'
		;;

	-df )
		if [[ -z "$3" ]]; then
			if [[ -z "$2" ]]; then
				EP=""
				DP=""
			else
				EP="$2"
			fi
		else
			EP="$2"
			DP="$3"
		fi
		EP=$2
		DP=$3

		# Decrypts openssl file to plain-text tsv file
		openssl enc -aes-256-cbc -d -pass pass:"$PASS" -in "$EP"passwords.tsv.enc -out "$DP"passwords.tsv
		;;

	-h )
		help
		;;
esac