#!/bin/bash
#This script installs OpenLDAP and is included in main script
function backUpConfig(){
	#To record all the logs
	touch logfile

	#To install openLDAP  packages on server and clients 
	yum install openldap-servers openldap-clients -y >> logfile

	#Configuring the ldap sever
	# Backing up the config file
	echo "\n Backing up the  olcDatabase={2}hdb.ldif\n" | tee -a "logfile"
	cp /etc/openldap/slapd.d/cn=config/olcDatabase={2}hdb.ldif /etc/openldap/slapd.d/cn=config/olcDatabase={2}hdb.ldif.backup

	#Configuring LDAP server
	echo "\nConfiguring olcDatabase={2}hdb.ldif file\n" | tee -a "logfile"
	sed -i '/olcSuffix: dc=my-domain,dc=com/c\olcSuffix: dc=CIT470_001-Team5_s1,dc=hh,dc=nku,dc=edu' /etc/openldap/slapd.d/cn=config/olcDatabase={2}hdb.ldif >> logfile
	sed -i '/olcRootDN: cn=Manager,dc=my-domain,dc=com/c\olcRootDN: cn=Manager, dc=CIT470_001-Team5_s1,dc=hh,dc=nku,dc=edu' /etc/openldap/slapd.d/cn=config/olcDatabase={2}hdb.ldif >> logfile

	#Configuring the root password for LDAP
	echo "\nConfiguring the root password for LDAP***\n" | tee -a "logfile"
	echo "olcRootPW: student" >> /etc/openldap/slapd.d/cn=config/olcDatabase={2}hdb.ldif

	#Configuring the LDAP to start on the boot 
	systemctl enable slapd

	#Starting the  LDAP service
	systemctl start slapd.service

	#Configuring the firewall on LDAP Server
	#Adding  the Firewall rules
	echo "\nConfiguring the Firewall for LDAP server***\n" | tee -a "logfile"
}
function firewallsetup(){
	#Adding the Firewall configuration rules to permit incoming packets on LDAP ports
	systemctl start firewalld.service
	firewall-cmd --zone=public --add-port=389/tcp --permanent
	firewall-cmd --zone=public --add-service=ldap --permanent
	firewall-cmd --zone=public --add-port=636/tcp --permanent

	#Reloading firewall services
	firewall-cmd --reload
}

#Deleting The Old LDAP Database And Install nss_ldap packages
function cleanAndInstall(){
	#Deleting The Old LDAP Database
	echo "\nDeleting the old LDAP database***\n" | tee -a "logfile"
	rm -R /var/lib/ldap/*

	#Creating DB_CONFIG file
	echo "\nCreating the DB_CONFIG file and changing the permissions for the file***\n" | tee -a "logfile"
	cp /usr/share/openldap-servers/DB_CONFIG.example /var/lib/ldap/DB_CONFIG
	chown -R ldap:ldap /var/lib/ldap

	#Installing nss_ldap packages
	echo "\nInstalling nss_ldap packages***\n" | tee -a "logfile"
	yum install nss_ldap -y >> logfile
}

#MIGRATE ACCOUNT/ GROUP DATA
function migrateData(){

	#Installing the  migration tools
	echo "\nInstalling the Migration tools***\n" | tee -a "logfile"
	yum install migrationtools -y >> logfile

	#Taking the backup of migration file
	echo "\nTaking the backup of migrate_common.ph file***\n" | tee -a "logfile"
	cp /usr/share/migrationtools/migrate_common.ph /usr/share/migrationtools/migrate_common.ph.backup

	#Editing migrate_common.ph file
	echo "\nEditing migrate_common.ph file***\n" | tee -a "logfile"
	sed -i '/$DEFAULT_MAIL_DOMAIN = "padl.com";/c\$DEFAULT_MAIL_DOMAIN = "CIT470_001-Team5_s1.hh.nku.edu";' /usr/share/migrationtools/migrate_common.ph >> logfile
	sed -i '/$DEFAULT_BASE = "dc=padl,dc=com";/c\$DEFAULT_BASE = "dc=CIT470_001-Team5_s1,dc=hh,dc=nku,dc=edu";' /usr/share/migrationtools/migrate_common.ph >> logfile

	#Creating the base.ldif file
	echo "\nCreating base.ldif file***\n" | tee -a "logfile"
	wget -P /usr/share/migrationtools http://10.2.7.15/base.ldif >> logfile

	#Add the schemas to support  the object classes and the attributes
	echo "\nStarting the LDAP services**\n" | tee -a "logfile"
	systemctl restart slapd.service

	echo "\nAdding the Schemas****\n" | tee -a "logfile"
	ldapadd -Y EXTERNAL -H ldapi:/// -f /etc/openldap/schema/core.ldif
	ldapadd -Y EXTERNAL -H ldapi:/// -f /etc/openldap/schema/cosine.ldif
	ldapadd -Y EXTERNAL -H ldapi:/// -f /etc/openldap/schema/nis.ldif
	ldapadd -Y EXTERNAL -H ldapi:/// -f /etc/openldap/schema/inetorgperson.ldif

	echo "\nStopping the LDAP services and fixing the ownership of the files***\n" | tee -a "logfile"
	systemctl stop slapd.services
	chown -R ldap:ldap /var/lib/ldap

	echo "\nAdding the Base Data....\n" | tee -a "logfile"
	slapadd -v -l /usr/share/migrationtools/base.ldif | tee -a "logfile"

}

function migrateData2(){

	current_path="$(pwd)"

	cd /usr/share/migrationtools

	echo "\nMigrating and adding local password database***\n" | tee -a "${current_path}/logfile"
	./migrate_passwd.pl /etc/passwd > passwd.ldif | tee -a "${current_path}/logfile"
	slapadd -v -l passwd.ldif | tee -a "${current_path}/logfile"

	echo "\nMigrating and adding the group database****\n" | tee -a "${current_path}/logfile"
	./migrate_group.pl /etc/group > group.ldif | tee -a "${current_path}/logfile"
	slapadd -v -l group.ldif | tee -a "${current_path}/logfile"

	cd ${current_path}

	printf "\nChanging ownership of all files under /var/lib/ldap....\n" | tee -a "logfile"
	chown -R ldap.ldap /var/lib/ldap

	printf "\nStarting the LDAP server***\n" | tee -a "logfile"
	systemctl start slapd.service
}

#CONFIGURING THE ACL
function configAcl(){

	echo "\nConfiguring olcDatabase={2}hdb.ldif file\n" | tee -a "logfile"
	echo "olcAccess: {0}to attrs=userPassword, by self write by anonymous auth by * none" >> /etc/openldap/slapd.d/cn=config/olcDatabase={2}hdb.ldif
	echo "\nolcAccess: {1} to * by self write by * read" >> /etc/openldap/slapd.d/cn=config/olcDatabase={2}hdb.ldif

	echo "\nRestarting the  slapd service....\n" | tee -a "logfile"
	systemctl restart slapd.service >> logfile

}
#DIRADMIN : LDAP USER CREATION /MODIFICATION TOOL IN /USR/LOCAL
function createUser(){
	echo "\nDownloading the  diradm....\n" | tee -a "logfile"
	wget -P /usr/local http://www.hits.at/diradm/diradm-1.3.tar.gz >> logfile
	tar zxvf /usr/local/diradm-1.3.tar.gz -C /usr/local >> logfile

	echo "\nConfiguring diradm.conf file***\n" | tee -a "logfile"
	sed -i '/BINDDN="cn=Admin,o=System"/c\BINDDN="cn=Manager,dc=CIT470_001-Team5_s1,dc=hh,dc=nku,dc=edu"' /usr/local/diradm-1.3/diradm.conf >> logfile
	sed -i '/USERBASE="ou=Users,ou=Accounts,o=System"/c\USERBASE="ou=People,dc=CIT470_001-Team5_s1,dc=hh,dc=nku,dc=edu"' /usr/local/diradm-1.3/diradm.conf >> logfile
	sed -i '/GROUPBASE="ou=Groups,ou=Accounts,o=System"/c\GROUPBASE="ou=Group,dc=CIT470_001-Team5_s1,dc=hh,dc=nku,dc=edu"' /usr/local/diradm-1.3/diradm.conf >> logfile
        ./diradm useradd -c "LDAP Test Team5" -s /bin/bash -m -p "student" team5
		
	
}



backUpConfig
firewallsetup
cleanAndInstall
migrateData
migrateData2
configAcl
createUser
