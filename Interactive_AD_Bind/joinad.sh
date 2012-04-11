################################################################
# Interactive script to join Macs to Active Directory
# 
# Written by Vaughn Miller
# Version 1.1  December 7, 2011
#
# In this sample the the FQDN is ad.comapny.com and the NetBios
# name is COMAPNY  You should change these values and the OU values
# to match your environment
################################################################

#!/bin/bash

RunAsRoot()
{
        ##  Pass in the full path to the executable as $1
        if [[ "${USER}" != "root" ]] ; then
                echo
                echo "***  This application must be run as root.  Please authenticate below.  ***"
                echo
                sudo "${1}" && exit 0
        fi
}

RunAsRoot "${0}"

# If machine is already bound, exit the script
check4AD=`/usr/bin/dscl localhost -list . | grep "Active Directory"`
if [ "${check4AD}" = "Active Directory" ]; then
	echo "Computer is already bound to Active Directory.. \n Exiting script... "; exit 1
fi


read -p "Enter computer name : " compName

echo "Select OU for computer : "
select ou in "OU=Laptops,OU=Office Computers,DC=ad,DC=company,DC=com" "OU=Office Computers,DC=ad,DC=company,DC=com"; do
        break
done

# Bind the machine to AD
read -p "Enter account name  : " acctName
dsconfigad -add ad.company.com -computer $compName -username $acctName -ou "$ou"

# If the machine is not bound to AD, then there's no purpose going any further. 
check4AD=`/usr/bin/dscl localhost -list . | grep "Active Directory"`
if [ "${check4AD}" != "Active Directory" ]; then
	echo "Bind to Active Directory failed! \n Exiting script... "; exit 1
fi

# set host names to match 
scutil --set HostName $compName
scutil --set ComputerName $compName
scutil --set LocalHostName $compName

# Configure login options
dsconfigad -mobile enable
dsconfigad -mobileconfirm disable
dsconfigad -useuncpath disable

# If running Lion, configure the search paths.
# The Search Paths show up different depending on what update is installed
majorSysver=`sw_vers -productVersion | cut -c 1-4`
minorSysver=`sw_vers -productVersion | cut -c 6`
if [ $majorSysver = 10.7 ]; then
   if [ $minorSysver -gt 1 ]; then
      dscl /Search -delete / CSPSearchPath "/Active Directory/COMPANY/All Domains"
      dscl /Search -append / CSPSearchPath "/Active Directory/COMPANY"
      dscl /Search -append / CSPSearchPath "/Active Directory/COMPANY/All Domains"
   else
      dscl /Search -delete / CSPSearchPath "/Active Directory/AD/All Domains"
      dscl /Search -append / CSPSearchPath "/Active Directory/AD"
      dscl /Search -append / CSPSearchPath "/Active Directory/AD/All Domains"
   fi
fi

# Set login options to be more user friendly
defaults write /Library/Preferences/com.apple.loginwindow SHOWFULLNAME -bool TRUE
chmod o+w /Library/Preferences
defaults write "/Library/Preferences/com.apple.NetworkAuthorization" UseDefaultName -bool NO
defaults write "/Library/Preferences/com.apple.NetworkAuthorization" UseShortName -bool YES
chmod o-w /Library/Preferences

###########################################################################
# Add Mobile Accounts
###########################################################################

echo "Do you wish to setup mobile accounts now?"
select i in "Yes" "No"; do
	break
done

while [ $i = "Yes" ]; do
	read -p "Enter user name : " userName
	/System/Library/CoreServices/ManagedClient.app/Contents/Resources/createmobileaccount -n $userName

	# Check to see if the account was created and then prompt to see
	# if user should be made an administrator

	if [ -d "/Users/$userName" ]; then
		echo "Make user administrator ? "
		select yn in "Yes" "No"; do
	   	     break
		done
		if [ $yn == "Yes" ]; then
			dscl . -append /Groups/admin GroupMembership $userName
		fi
	fi
	echo "Another user?"
	select i in "Yes" "No"; do
		break
	done
done
