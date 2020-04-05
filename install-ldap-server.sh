#!/bin/bash

#Project Group 3
#CIT 470, Project 2

#Initiate help command option for ./install-ldap-server
if [ "$1" == "-h" ]; then echo "Usage: `basename $0` [Install LDAP Server. Script is invoked using the following command: ./install-ldap-server]" ; exit 0 ; fi
#Yum installs required
yum -y install openldap-servers openldap-clients >> ldap-server.log
#Wget needed database files for ldap from a hosted apache server.
#wget -O /etc/openldap/db.ldif https://raw.githubusercontent.com/Thomaso54/Group3Project2/master/db.ldif
wget -O /etc/openldap/base.ldif https://raw.githubusercontent.com/Thomaso54/Group3Project2/master/base.ldif
#Set hashed password for Root
#hash=$(slappasswd -s RootGroup3 -n) >> ldap-server.log
#sed -i "s/olcRootPW:/olcRootPW: $hash/g" /etc/openldap/db.ldif >> ldap-server.log
hash=$(slappasswd -s RootGroup3 -n) >> ldap-server.log
sed -i "s/olcRootPW:/olcRootPW: $hash/g" /etc/openldap/slapd.d/cn=config/olcDatabase={2}hdb.ldif >> ldap-server.log
echo "olcAccess: {0}to attrs=userPassword, by self write by anonymous auth by * none" >> /etc/openldap/slapd.d/cn=config/olcDatabase={2}hdb.ldif
echo "olcAccess: {1} to * by self write by * read" >> /etc/openldap/slapd.d/cn=config/olcDatabase={2}hdb.ldif
#Enable slapd and start it
systemctl enable slapd.service && systemctl start slapd >> ldap-server.log
#Set firewall rules
firewall-cmd --zone=public --add-port=389/tcp --permanent >> ldap-server.log
firewall-cmd --zone=public --add-port=636/tcp --permanent >> ldap-server.log
firewall-cmd --reload >> ldap-server.log
#Add required LDAP Schemas
ldapadd -Y EXTERNAL -H ldapi:/// -f /etc/openldap/schema/core.ldif >> ldap-server.log
ldapadd -Y EXTERNAL -H ldapi:/// -f /etc/openldap/schema/cosine.ldif >> ldap-server.log
ldapadd -Y EXTERNAL -H ldapi:/// -f /etc/openldap/schema/nis.ldif >> ldap-server.log
ldapadd -Y EXTERNAL -H ldapi:/// -f /etc/openldap/schema/inetorgperson.ldif >> ldap-server.log
#Import the domains information to olcDatabase{2} using ldapmodify for no CRC errors
#ldapmodify -Q -Y EXTERNAL -H ldapi:/// -f /etc/openldap/db.ldif >> ldap-server.log
#ldapadd -x -w RootGroup3 -D cn=Manager,dc=cit470,dc=nku,dc=edu -H ldap:/// -f /etc/openldap/base.ldif >> ldap-server.log
#Restart slapd.service to enfore the changes
systemctl restart slapd >> ldap-server.log
#Get diradm
wget --directory-prefix=/usr/local/ http://www.hits.at/diradm/diradm-1.3.tar.gz >> ldap-server.log
#Unzip diradm directory
tar zxvf /usr/local/diradm-1.3.tar.gz -C /usr/local/ >> ldap-server.log
#Create the diradm.conf file using printf
printf "# Begin /etc/diradm.conf\n# LDAP specific options\n# ---------------------\nLDAPURI="ldap://10.2.7.15:389/"\nBINDDN="cn=Manager,dc=cit470,dc=nku,dc=edu"\n# Be extremely careful with read rights\n# of this file if you set this value!!!\n# BINDPASS="secret"\nUSERBASE="ou=People,dc=cit470,dc=nku,dc=edu"\nGROUPBASE="ou=Group,dc=cit470,dc=nku,dc=edu"\n# Options for user accounts\n# ---------------------------------\nUIDNUMBERMIN="1000"\nUIDNUMBERMAX="60000"\nUSERGROUPS="yes"\nHOMEBASE="/home"\nHOMEPERM="0750"/nSKEL="/etc/skel"\nDEFAULT_GIDNUMBER="100"\nDEFAULT_LOGINSHELL="/bin/bash"\nDEFAULT_SHADOWINACTIVE="7"\nDEFAULT_SHADOWEXPIRE="-1"\nSHADOWMIN="0"\nSHADOWMAX="99999"\nSHADOWWARNING="7"\nSHADOWFLAG="0"\n# Options for group accounts\n# ----------------------------------\nGIDNUMBERMIN="1000"\nGIDNUMBERMAX="60000"\n# End /etc/diradm.conf" >> diradm.conf
#Move and overwrite  diradm.conf with the one created
mv -f diradm.conf /usr/local/diradm-1.3/ >> ldap-server.log
cd /usr/local/diradm-1.3
./diradm useradd -c "LDAP Test Account" -s /bin/bash -m -p "Test Account" ldap_test_acc
