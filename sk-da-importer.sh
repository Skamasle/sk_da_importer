#!/bin/bash
# This script is provided whitout any warranty
# Run at your own risk
# Version 0.2
# This script restore backups from DA to VestaCP
# This script can restore Datases, databases user and passwords, mails and domains.
# Contact da_importer@skamasle.com
# Skamasle | Maks Usmanov
# Twitter @skamasle
# Turn this to 1 if you want get domains and paths from apache_owened_list 
# Turn int to 2 if you want to get domains dir "domains" and set public_html as default
sk_get_dom=1
if [ ! -e /usr/bin/rsync ] || [ ! -e /usr/bin/file ] ; then
	echo "#######################################"
	echo "rsync not installed, try install it"
	echo "This script need: rsync, file"
	echo "#######################################"
	if  [ -e /etc/redhat-release ]; then
		echo "Run: yum install rync file"
	else
		echo "Run: apt-get install rsync file"
	fi
	exit 3
fi
# Put this to 0 if you want use bash -x to debug it
sk_debug=1
sk_vesta_package=default
b=backup
d=domains
#
# Only for gen_password but I dont like it, a lot of lt
# maybe will use it for orther functions :)
source /usr/local/vesta/func/main.sh 
sk_file=$1
sk_tmp=sk_tmp
sk_delete_tmp () {
echo "Removing tmp files"
rm -rf /root/${sk_tmp}
}
sk_file_name=$(ls $sk_file)
tput setaf 2
echo "Checking provided file..."
tput sgr0 
if file $sk_file |grep -q -c "gzip compressed data," ; then
	tput setaf 2
	echo "OK - Gziped File"
	tput sgr0 	
	if [ ! -d /root/${sk_tmp} ]; then
		echo "Creating tmp.."
		mkdir /root/${sk_tmp}
	fi
	echo "Extracting backup..."
	if [ "$sk_debug" != 0 ]; then
		tar xzvf $sk_file -C /root/${sk_tmp} 2>&1 |
     		   while read sk_extracted_file; do
       				ex=$((ex+1))
       				echo -en "wait... $ex files extracted\r"
       		   done
		else
			tar xzf $sk_file -C /root/${sk_tmp}
	fi
		if [ $? -eq 0 ];then
			tput setaf 2
			echo "Backup extracted whitout errors..."
			tput sgr0 
		else
			echo "Error on backup extraction, check your file, try extract it manually"
			sk_delete_tmp
			exit 1
		fi
	else
	echo "Error 3 not-gzip - no stantard cpanel backup provided of file not installed ( Try yum install file, or apt-get install file )"
	sk_delete_tmp
	exit 3
fi
cd /root/${sk_tmp}/
sk_importer_in=$(pwd)
echo "Access tmp directory $sk_importer_in"
echo "Get prefix/user..."
sk_da_user=$(grep username backup/user.conf |cut -d "=" -f 2)
sk_da_usermail=$(grep email backup/user.conf |cut -d "=" -f 2 |grep @)
if [ -z $sk_da_usermail ];then
	sk_da_usermail=$(grep domain backup/user.conf |cut -d "=" -f 2 |head -n 1)
fi

if /usr/local/vesta/bin/v-list-users | grep -q -w $sk_da_user ;then
	echo "User alredy exist on your server, maybe on vestacp or in your /etc/passwd"
	echo "**"
	echo "Grep your /etc/passwd"
	grep -q -w $sk_da_user /etc/passwd
	echo "**"
	sk_delete_tmp
	exit 21
else
	echo "Generate random password for $sk_da_user and create Vestacp Account ..."
	sk_password=$(generate_password)
	/usr/local/vesta/bin/v-add-user $sk_da_user $sk_password $sk_da_usermail $sk_vesta_package $sk_da_user $sk_da_user
	if [ $? != 0 ]; then
		tput setaf 2
		echo "Stop Working... Cant create user...if is fresh install of vestacp try reboot or reopen session check bug https://bugs.vestacp.com/issues/138"
		tput sgr0
		sk_delete_tmp
		exit 4
		fi
fi
for sk_ex1 in crontab ticket user
do
	mv backup/${sk_ex1}.conf backup/${sk_ex1}
done
# start whit databases
tput setaf 2
echo "Start Whit Databases"
tput sgr0 
echo "Get local databases"
mysql -e "SHOW DATABASES" > server_dbs
sk_da_db_user_list=$(ls -1 backup/ |grep ".conf")
function sk_run_da_db () {
for sk_da_db_u in $sk_da_db_user_list
do
	userdb=${sk_da_db_u:: -5}
	md5=$(grep $userdb ${b}/${sk_da_db_u} | head -n 1 | tr '&' '\n ' |grep passwd |cut -d "=" -f 2)
	db=$(grep db_collation ${b}/${sk_da_db_u} | tr '&' '\n ' |grep SCHEMA_NAME |cut -d "=" -f 2)
	grep -w $db server_dbs
	if [ $? == "1" ]; then
			tput setaf 2
			echo " Create and restore ${db} "
			tput sgr0 
			mysql -e "CREATE DATABASE $db"
			mysql ${db} < backup/${db}.sql
			echo "Add $db to vestacp"
			echo "DB='$db' DBUSER='$userdb' MD5='$md5' HOST='localhost' TYPE='mysql' CHARSET='UTF8' U_DISK='0' SUSPENDED='no' TIME='$TIME' DATE='$DATE'" >> /usr/local/vesta/data/users/${sk_da_user}/db.conf
	else
			echo "Error: Cant restore database $db alredy exists in mysql server"
	fi
done
echo "Fix passwords and users"
/usr/local/vesta/bin/v-rebuild-databases $sk_da_user
}

if [[ -z $sk_da_db_user_list ]]; then
	echo "No database found"
else
sk_run_da_db
fi

# Start whit domains
tput setaf 2
echo "Start Whit Domains"
tput sgr0 
if [ "$sk_get_dom" = 1 ];then
	sk_da_domain_list=$(grep "=G" ${b}/apache_owned_files.list |grep -v public_html |grep -v private_html)
else
	sk_da_domain_list=$(ls -1 domains/)
fi
for sk_da_dom in $sk_da_domain_list
	do
		if [ "$sk_get_dom" = 1 ];then
			sk_da_dom=${sk_da_dom:: -2}
		fi			
		tput setaf 2
		echo "Add $sk_da_dom if not exists"
		tput sgr0 
		/usr/local/vesta/bin/v-add-domain ${sk_da_user} $sk_da_dom 
		if [ "$?" = "4" ]; then
			tput setaf 4
			echo "Domain $sk_da_dom alredy added in some account, skip..."
			tput sgr0 
		elif [ -d /home/${sk_da_user}/web/${sk_da_dom} ];then
			echo "Domain $sk_da_dom added, restoring files"
			echo $sk_da_dom >> sk_restored_domains
			#some paths maybe change, I dont know yet so we get it.
			if [ "$sk_get_dom" = 1 ];then
				sk_da_do_path=$(grep -w $sk_da_dom ${b}/apache_owned_files.list |grep -v "${sk_da_dom}=G" |grep -v "private_html")
				sk_da_do_path=${sk_da_do_path:: -2}
			else
				sk_da_do_path=${sk_da_dom}/public_html
			fi
			if [ "$sk_debug" != 0 ]; then
				rm -f /home/${sk_da_user}/web/${sk_da_dom}/public_html/index.html
				rsync -av ${d}/${sk_da_do_path}/ /home/${sk_da_user}/web/${sk_da_dom}/public_html 2>&1 | 
    			while read sk_file_dm; do
       			 	sk_sync=$((sk_sync+1))
       			 	echo -en "-- $sk_sync restored files\r"
				done
				echo " "
			else
				rm -f /home/${sk_da_user}/web/${sk_da_dom}/public_html/index.html
				rsync ${d}/${sk_da_do_path}/ /home/${sk_da_user}/web/${sk_da_dom}/public_html
			fi
			chown ${sk_da_user}:${sk_da_user} -R /home/${sk_da_user}/web/${sk_da_dom}/public_html
			chmod 751 /home/${sk_da_user}/web/${sk_da_dom}/public_html
		else
			echo "Ups.. cant restore or add domain: $sk_da_dom"
		fi
done
echo " "
echo "Domains restored!"
tput setaf 2
echo "Start restoring mails"
tput sgr0 
function sk_da_restore_imap_pass () {
if [ -d /etc/exim ]; then
	EXIM=/etc/exim
else
	EXIM=/etc/exim4
fi
sk_actual_pass=$(grep -w $1 ${EXIM}/domains/$2/passwd |tr '}' ' ' | tr ':' ' ' | cut -d " " -f 3)
sk_da_orig_pass=$(grep -w $1 ${b}/$2/email/passwd |tr ':' ' ' |cut -d " " -f2)
replace "${sk_actual_pass}" "${sk_da_orig_pass}" -- ${EXIM}/domains/$2/passwd
echo "Password for $1@$2 restored"
#################
# fix vesta needed
}
if [ -e sk_restored_domains ]; then
cat sk_restored_domains | while read sk_da_mail_domain
	do	
		if [ "$(ls -A ${b}/${sk_da_mail_domain}/email/data/imap/)" ]; then
			tput setaf 2
			echo "Found Imap for ${sk_da_mail_domain}"
			tput sgr0
				ls -1 ${b}/${sk_da_mail_domain}/email/data/imap/ | while read sk_da_imap
					do
						/usr/local/vesta/bin/v-add-mail-account $sk_da_user $sk_da_mail_domain $sk_da_imap temp
						if [ "$sk_debug" != 0 ]; then
							rsync -av ${b}/${sk_da_mail_domain}/email/data/imap/${sk_da_imap}/Maildir/ /home/${sk_da_user}/mail/${sk_da_mail_domain}/${sk_da_imap} 2>&1 | 
    						while read sk_file_dm
							do
       			 				sk_sync=$((sk_sync+1))
       			 				echo -en "-- $sk_sync restored files\r"
							done
							echo " "
						else
							rsync ${b}/${sk_da_mail_domain}/email/data/imap/${sk_da_imap}/Maildir/ /home/${sk_da_user}/mail/${sk_da_mail_domain}/${sk_da_imap}
						fi
						chown ${sk_da_user}:mail -R /home/${sk_da_user}/mail/${sk_da_mail_domain}/${sk_da_imap}
				sk_da_restore_imap_pass $sk_da_imap $sk_da_mail_domain
					done

		fi
	done
fi
sk_delete_tmp
echo "Account $sk_da_user restored"
echo "REport eny errores in skamasle.com or in vesta forum ( official forum thread ) "
echo "Or in twitter @skamasle"
echo "This was powered by skamasle.com | Maks Usmanov"
