####################################################
# Bind to Active Directory script
#
# written by Nick Cobb, 2012.
# 
#
# Based on script by Vaughn Miller
# https://github.com/vmiller/vmiller_scripts/tree/master/Interactive_AD_Bind
#
# Reference man dsconfigad for additional parameters
####################################################

#!/bin/bash

RunAsRoot()
{
        ## Pass in the full path to the executable as $1
        if [[ "${USER}" != "root" ]] ; then
echo
echo "*** This application must be run as root. Please authenticate below. ***"
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

# Set machine to use AD domain for network time
echo Setting Network Time...
systemsetup -setusingnetworktime on
read -p "Enter network time server address : " timeServ
systemsetup -setnetworktimeserver $timeServ

# Get user input for machine name
read -p "Enter computer name : " compName

# Bind the machine to AD
read -p "Enter AD domain : " domainAddy
read -p "Enter OU location (ie., OU=Apple,dc=your,dc=domain,dc=here,dc=com) : " ou
read -p "Enter AD admin account name : " acctName
echo
echo Binding...this process may take a minute or two...
echo Please enter your password below...
sleep 1
dsconfigad -force -add $domainAddy -computer $compName -username $acctName -ou $ou

# If the machine is not bound to AD, then there's no purpose going any further.
check4AD=`/usr/bin/dscl localhost -list . | grep "Active Directory"`
if [ "${check4AD}" != "Active Directory" ]; then
echo "Bind to Active Directory failed! \n Exiting script... "; exit 1
fi

# set host names to match
echo Setting Computer Name...
sleep 2
scutil --set HostName $compName
scutil --set ComputerName $compName
scutil --set LocalHostName $compName
sleep 1

# Configure login options
# These settings correspond to the User Experience tab in Directory Utility
echo Configuring Login Settings...
sleep 1
dsconfigad -mobile enable
dsconfigad -mobileconfirm disable
dsconfigad -localhome enable
dsconfigad -useuncpath enable
dsconfigad -protocol smb
sleep 1

# Configure administrator options
# These settings correspond to the Administrative tab in Directory Utility
read -r -p "Enter administrative domain groups (separate with commas, ie., DOMAIN\Domain Admins,DOMAIN\Support Group Admin) : " groupName
echo Configuring Administrative Settings...
sleep 1
dsconfigad -groups "$groupName"
dsconfigad -alldomains enable
sleep 1

# Configure security options
echo Configuring Security Settings...
sleep 1
dsconfigad -packetencrypt ssl
sleep 1
 
# Set AD Search Policy
echo Configuring Search Policy...
dscl /Search -create / SearchPolicy CSPSearchPath
dscl /Search -append / CSPSearchPath "/Active Directory/CORP/All Domains"
dscl /Search/Contacts -create / SearchPolicy CSPSearchPath
dscl /Search/Contacts -append / CSPSearchPath "/Active Directory/CORP/All Domains"

###########################################################################
# Add Mobile Accounts
###########################################################################

echo "Do you wish to setup AD user accounts now?"
select i in "Yes" "No"; do
break
done

while [ $i = "Yes" ]; do
read -p "Enter AD user account : " userName
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