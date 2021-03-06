#!/usr/bin/env bash
#set -x
: '
This script is used by the Linux QA Team to run everyday tasks.
	Usage: agent_install [options] <argv>

		-h 			Show help options.
		-clean   	Perfrom unsinstall of the rr-agent and suggested packages. For this option repo package also will be removed.
		-install 	<Version>, <Repo file> You will need to specify version of the branch to install the newest available package or you can specify dedicated repo file to be installed.
					<Repo file> - if this argv is used, please, make sure that repo file is executable. To make file executable, please do the next: "chmod +x file".

	Example: 
		agent_install -h
		agent_install -logs
		agent_install -clean
		agent_install -install 7.0.0
		agent_install -install rapidrecovery-repo-6.0.0.10286-rhel7-x86_64.rpm
'

FILEPATH=`realpath $0`
command=$1
build=$2


if [[ "$command" != "-h" && "$command" != "-clean" && "$command" != "-install" && "$command" != "-logs" && -z "$build" ]]; then
	sed -n '4,17p' $FILEPATH
	exit 1
fi

if [[ "$command" == "-h" ]]; then
	sed -n '4,17p' $FILEPATH
	exit 0
fi



package_name=rapidrecovery-agent
rr_config=/usr/bin/rapidrecovery-config


function repo_cleaner {
echo "Repository cleaner"
if [ -f /etc/lsb-release ] || [ -f /etc/debian_version ]
then
operator="apt-get"
package="dpkg"
installed="dpkg -l"
fi

if [ -f /etc/redhat-release ] || [ -f /etc/centos-release ]
then
operator="yum"
package="rpm"
installed="rpm -qa"
fi

if [ -f /etc/SuSE-release ]
then
operator="zypper"
package="rpm"
installed="rpm -qa"
fi

echo $operator

/etc/init.d/rapidrecovery-agent stop 1>&2 2>/dev/null
systemctl stop repidrecovery-agent 1>&2 2>/dev/null
rmmod rapidrecovery-vss 1>&2 2>/dev/null

if [ "$operator" = "zypper" ]
then
	$operator remove -y rapidrecovery-agent
	$operator remove -y rapidrecovery-mono
	$operator remove -y dkms
	$operator remove -y rapidrecovery-repo
	$operator remove -y nbd
	rmmod rapidrecovery-vss
	$operator clean
else
	$operator -y remove rapidrecovery-agent
	$operator -y remove rapidrecovery-mono
	$operator -y remove dkms
	$operator -y remove rapidrecovery-vss
	$operator -y remove rapidrecovery-repo
	rmmod rapidrecovery-vss
	$operator clean all
fi

not_removed=`$installed | grep rapid | awk '{print $2}'`
if [ -z $not_removed ]
then 
	tput setaf 2; echo "All RR packages were removed"; tput sgr0
		else 
			echo $not_removed package is not REMOVED. Will try to remove it with configuration files.
			$operator -y purge $not_removed
			if [ -z `$installed | grep $not_removed | awk '{print $2}'` ]
			then 
		 		tput setaf 3; echo $not_removed package has been removed with configuration files; tput sgr0
				return 0	
					else 
						tput setaf 1; echo "Package has not been removed even using configuration option. PLEASE INVESTIGATE THIS FACT."; tput sgr0
						return 1
			fi
fi

}

echo $build

if [ "$command" = "-clean" ]
then
	repo_cleaner
	exit 0	
fi

echo "Agent Installer Script"
if [ -f /etc/lsb-release ] || [ -f /etc/debian_version ]
then
operator="apt-get"
list="dpkg -l"
install="dpkg -i"
os="debian"
	if [[ `cat /etc/os-release | grep VERSION_ID | awk -F '["/.]' '{print $2}'` -eq "17"  || `cat /etc/os-release | grep VERSION_ID | awk -F '["/.]' '{print $2}'` -eq "16"  || `cat /etc/os-release | grep VERSION_ID | awk -F '["/.]' '{print $2}'` -eq "15" || `cat /etc/os-release | grep VERSION_ID | awk -F '["/.]' '{print $2}'` -eq "9" || `cat /etc/os-release | grep VERSION_ID | awk -F '["/.]' '{print $2}'` -eq "8" ]]; then
	version="8"
	fi
	
	if [[ `cat /etc/os-release | grep VERSION_ID | awk -F '["/.]' '{print $2}'` -eq "12"  || `cat /etc/os-release | grep VERSION_ID | awk -F '["/.]' '{print $2}'` -eq "14" || `cat /etc/os-release | grep VERSION_ID | awk -F '["/.]' '{print $2}'` -eq "7" ]]; then
	version="7"
	fi

arch=$(arch)
if [ "$arch" == "i686" ]; then
	arch="x86_32"
fi
package="deb"
fi

if [ -f /etc/redhat-release ]
then
operator="yum"
list="rpm -qa"
install="rpm -i"
os=rhel
version=$(cat /etc/os-release | grep -w VERSION_ID= | awk -F '["/.]' '{print $2}')
if [ -z $version ]; then
        version=$(cat /etc/centos-release | awk '{print$3}'| awk -F '["/.]' '{print $1}')
fi
arch=$(arch)
if [ "$arch" == "i686" ]; then
        arch="x86_32"
fi
package="rpm"
fi

if [ -f /etc/SuSE-release ]
then
operator="zypper"
list="rpm -qa"
install="rpm -i"
os=sles
version=$(cat /etc/SuSE-release | grep VERSION | awk '{print $3}')
arch=$(arch)
if [ "$arch" == "i686" ]; then
        arch="x86_32"
fi
package="rpm"
fi

echo $operator

echo "List of the packages before installation"
$list | grep 'rapid\|nbd\|dkms'




function install_repo {
echo ${#build}
if [ "${#build}" -gt "5" ]
then 
	$install $build
	if [ $? -ne "0" ]
	then
		echo "$build is not available for installation."
		exit 1
	fi
else
	wget "https://s3.amazonaws.com/repolinux/$build/repo-packages/rapidrecovery-repo-$os$version-$arch.$package" -O "repo.file"

	if [ $? -ne "0" ]
	then
		echo "$build is not available for installation"
		exit 1
	fi
	chmod +x repo.file
	$install repo.file 
		
fi
}




function installation {
if [ $operator = "zypper" ]
then
$operator clean --all
        if [ "$version" -lt "12" ]
        then
        $operator install -y $package_name
                if [ "$?" -eq "1" ]
                then
                echo "Errors occurred during packages downloading"
                exit 1
                fi
        else
        $operator --no-gpg-check install -y $package_name
                if [ "$?" -eq "1" ]
                then
                echo "Errors occurred during packages downloading"
                exit 1
                fi
        fi
else
        $operator clean all
        echo "n" | $operator update >> /dev/null
        $operator install "-y" $package_name
        if [ "$?" -eq "1" ]
        then
        echo "Errors occurred during packages downloading"
        exit 1
        fi

fi
$list | grep 'rapid\|nbd\|dkms'



}



function update {
echo "update"
}




function configuration {
user=rr
password=123asdQ
port=8006
useradd $user
groupadd $user
useradd -G $user $user
#echo "1 $port" | $rr_config # configure default port for transfering
echo $user:$password | chpasswd
echo "2 $user" | $rr_config # add new user to allow to use it for protection
echo "4 all" | $rr_config # install rapidrecovery-vss into all available system kernels
echo "5" | $rr_config # allow to start agent immediately
firewall=$($rr_config -f list | awk -F'[_/]' '{print $1}')
echo "3 $firewall" | $rr_config # use first available option to configure firewall.
}


function details {
IP=$(ifconfig | grep inet | head -1 | awk '{print $2}')

echo "$IP"
echo "$user::$password"
echo "$(uname -r)"
 
}


function get_logs {
log_dir=/home/$user/Logs
mkdir $log_dir
cp -R /var/log/apprecovery $log_dir
cp /var/log/messages $log_dir >> /dev/null
cp /var/log/syslog $log_dir >> /dev/null
tar -zcvf Logs-$IP-$(date | awk {'print $5'}) $log_dir
}

if [[ "$command" == "-logs" ]]; then
	get_logs
	exit 0
fi


#function 


install_repo
installation # we run installation process
configuration # user added; rapidrecovery-vss is built for all available kernels; agent started;
details # details are provided for further protection
