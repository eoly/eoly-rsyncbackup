#!/bin/bash

# Author: Eric Olsen - eric@ericolsen.net

# Command Line Options
# command: rsyncbackup.sh 
# opt 1  : '--destination-dir | -d "destination directory"'
# opt 2  : '--file-list | -f "files from list"'
# opt 3  : '--source-name | -s "backup source name | remote hostname"'
# opt 4  : '--rshell | -r "use ssh"'
# opt 5  : '--ssh-user | -U "[ssh username (default rsync-backup)]"'
# opt 6  : '--ssh-port | -P "[ssh port (default 22)]"'

_MINOPTS=3
_RSYNC=`/usr/bin/which rsync`
_RSYNCOPTS='-avR --delete'
_RSHELL="no"
_RSYNCSSHUSER="rsync-backup"
_RSYNCSSHPORT=22
_SSHIDENTITY=""
_RSYNCSSH="ssh -i $_SSHIDENTITY -p $_RSYNCSSHPORT -l $_RSYNCSSHUSER"
_RSYNCSSHOPTS="--rsync-path='sudo rsync'" 
_LOGFILE=/var/log/backups/backups.log
_LOGDATE='date -u'

remote_host=
destination_dir=
backup_source=
file_list=

log_message () {
	echo `eval $_LOGDATE` "$1" >> $_LOGFILE
}

parse_options () {
	if [[ "$#" -lt "$_MINOPTS" ]]; then
		echo "usage"
		echo '--destination-dir | -d "destination directory"'
		echo '--file-list | -f "files from list"'
		echo '--source-name | -s "backup source name | remote hostname"'
		echo '--rshell | -r "use ssh"'
		echo '--ssh-user | -U "[ssh username (default rsync-backup)]"'
		echo '--ssh-port | -P "[ssh port (default 22)]"'
		log_message "Improper usage detected."
        exit 1
	else
		until [ -z "$1" ]
		do
			case "$1" in
				--destination-dir|-d)
					# Does backup destination dir exist?
					if [[ -d $2 ]]; then
						log_message "Destination directory exists."
						destination_dir=$2
					else
						log_message "Destination directory does not exist. Exiting."
						exit 1
					fi
				;;
				--file-list|-f)
					# Is there a backup file list provided? (Needs Improvement)
					if [[ ! -z $2 ]]; then
						IFS=","
                        x=0
						for item in $2; do
                            if [[ "$x" -gt 0 ]]; then
							    file_list="$file_list $item"
                            else
                                file_list="$file_list$item"
                            fi
                            let x++
						done
						unset IFS
						log_message "Backup source file list exists."
					else
						log_message "Backup source file list does not exist. Exiting"
						exit 1
					fi
				;;
				--source-name|-s)
					# Is there a directory for the backup source in destination dir?
					if [[ -d $destination_dir/$2 ]]; then
						backup_source=$2
						log_message "Backup source directory exists in desitination directory."
					else
						backup_source=$2
						mkdir -p $destination_dir/$backup_source
						log_message "Backup source directory did not exist.  Created new directory."
					fi

				;;
				--rshell|-r)
					# Use SSH for remote shell rsync backup
					_RSHELL="yes"
					remote_host=$backup_source
					log_message "Rsync over SSH enabled."
				;;
				--ssh-user|-U)
					_RSYNCSSHUSER=$2
					_RSYNCSSH="ssh -p $_RSYNCSSHPORT -l $_RSYNCSSHUSER" 
					_RSYNCSSH="ssh -i $_SSHIDENTITY -p $_RSYNCSSHPORT -l $_RSYNCSSHUSER"
					log_message "Rsync SSH user passed."
				;;
				--ssh-port|-P)
					_RSYNCSSHPORT=$2
					_RSYNCSSH="ssh -i $_SSHIDENTITY -p $_RSYNCSSHPORT -l $_RSYNCSSHUSER"
					log_message "Rsync SSH port passed."
				;;
			esac
			shift
		done
	fi
}

debugging () {
	echo $_MINOPTS
	echo $_RSYNC
	echo $_RSYNCOPTS
	echo $_RSHELL
	echo $_RSYNCSSHUSER
	echo $_RSYNCSSHPORT
	echo $_RSYNCSSH
	echo $_LOGFILE
	echo $destination_dir
	echo $backup_source
	echo $file_list
}

rotate_backup () {

    rotate_date=$(date +'%Y-%m-%d_%H-%M-%S')

	local current_directory="$destination_dir/$backup_source/current"
	local rotated_directory="$destination_dir/$backup_source/$rotate_date"

    echo $rotate_date
    cp -al $current_directory $rotated_directory

}

run_backup () {

	local current_directory="$destination_dir/$backup_source/current"
	local rsync_command="$_RSYNC $_RSYNCOPTS"
	
	log_message "Starting backup."

	if [[ ! -d $current_directory ]]; then
		log_message "Creating current directory: $current_directory"
		mkdir $current_directory
	fi

	if [[ "$_RSHELL" == "yes" ]]; then
		rsync_command="$rsync_command -e \"$_RSYNCSSH\" $_RSYNCSSHOPTS $remote_host:\"$file_list\" $current_directory/."
    else
        rsync_command="$rsync_command $file_list $current_directory/."
	fi

	echo $rsync_command
	eval $rsync_command
    rotate_backup

}

parse_options $*
#debugging
run_backup
