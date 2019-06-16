#!/usr/bin/env bash

###
# Installs minio as systemd service
# Tested on Ububntu 18.04
# MinIO project : https://github.com/minio
###

#check if root
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root" 
   exit 1
fi

echo "Install minio as systemd service. use --help for more info"


#params
MINIO_URL="https://dl.minio.io/server/minio/release/linux-amd64/minio"
MC_URL="https://dl.min.io/client/mc/release/linux-amd64/mc"
SYSTEMD_NAME="minio.service"
SYSTEMD_PATH="/etc/systemd/system/$SYSTEMD_NAME"

#defaults
USER="www-data"
INSTALL_PATH="/opt/minio"
DATA_PATH="/minio-data"
INSTALL_MC="no"


print_help ()
{
	printf '%s\n' "The general help msg"
	printf 'Usage: %s [-u|--user <arg>] [-p|--install-path <arg>] [-d|--data-path <arg>] [--install-mc] [-h|--help]\n' "$0"
	printf '\t%s\n' "-u,--user: user owner files and process. Will be created if not exists (nologin) (default: 'www-data')"
	printf '\t%s\n' "-p,--install-path: minio binary install path (default: '/opt/minio')"
	printf '\t%s\n' "-d,--data-path: minio data path (default: '/minio-data')"
	printf '\t%s\n' "--install-mc: install mc tool"
	printf '\t%s\n' "-h,--help: Prints help"
}
die()
{
	local _ret=$2
	test -n "$_ret" || _ret=1
	test "$_PRINT_HELP" = yes && print_help >&2
	echo "$1" >&2
	exit ${_ret}
}
parse_commandline ()
{
	while test $# -gt 0
	do
		_key="$1"
		case "$_key" in
			-u|--user)
				test $# -lt 2 && die "Missing value for the optional argument '$_key'." 
				USER="$2"
				shift
				;;
			--user=*)
				USER="${_key##--user=}"
				;;
			-u*)
				USER="${_key##-u}"
				;;
			-p|--install-path)
				test $# -lt 2 && die "Missing value for the optional argument '$_key'." 
				INSTALL_PATH="$2"
				shift
				;;
			--install-path=*)
				INSTALL_PATH="${_key##--install-path=}"
				;;
			-p*)
				INSTALL_PATH="${_key##-p}"
				;;
			-d|--data-path)
				test $# -lt 2 && die "Missing value for the optional argument '$_key'." 
				DATA_PATH="$2"
				shift
				;;
			--data-path=*)
				DATA_PATH="${_key##--data-path=}"
				;;
			-d*)
				DATA_PATH="${_key##-d}"
				;;
			--install-mc)
				INSTALL_MC="yes"
        ;;
			-h|--help)
				print_help
				exit 0
				;;
			-h*)
				print_help
				exit 0
				;;
			*)
				_PRINT_HELP=yes die "FATAL ERROR: Got an unexpected argument '$1'" 
				;;
		esac
		shift
	done
}


setup_and_download ()
{
    # Check if $USER exists
  if ! id -u $USER > /dev/null 2>&1; then
      echo "The user does not exist, creating..."
      useradd --system minio-user --shell /sbin/nologin || die "error creating user"
  fi

  [[ "${INSTALL_PATH}" == */ ]] && INSTALL_PATH="${INSTALL_PATH: : -1}"
  [[ "${DATA_PATH}" == */ ]] && DATA_PATH="${DATA_PATH: : -1}"

  #Check if the folder $INSTALL_PATH exist
  if [ ! -d $INSTALL_PATH ]; then
    echo "The folder $INSTALL_PATH doesn't exist. creating..."
    mkdir -p $INSTALL_PATH || die "error creating install path"
  fi
  chown $USER:$USER $INSTALL_PATH

  #Check if the folder $DATA_PATH exist
  if [ ! -d $DATA_PATH ]; then
    echo "The folder $DATA_PATH doesn't exist. creating..."
    mkdir -p $DATA_PATH || die "error creating install path"
  fi
  chown $USER:$USER $DATA_PATH


  #download minio
  wget -P $INSTALL_PATH $MINIO_URL || die "error downloadin minio binary"
  chmod 755 $INSTALL_PATH/minio
  chown $USER:$USER $INSTALL_PATH/minio

  #download mc
  if [ $INSTALL_MC = "yes" ]; then
    wget -P $INSTALL_PATH $MC_URL || die "error downloadin mc binary"
    chmod 755 $INSTALL_PATH/mc
    chown $USER:$USER $INSTALL_PATH/mc
    ln -s $INSTALL_PATH/mc /usr/local/bin/mc
  fi

}


install_systemd ()
{
  echo "creating systemd servie $SYSTEMD_PATH"
  SERVICE_CONTENT="[Unit]
  Description=MinIO
  Documentation=https://docs.min.io
  Wants=network-online.target
  After=network-online.target

  [Service]
  WorkingDirectory=$INSTALL_PATH
  User=$USER
  Group=$USER
  ExecStart=$INSTALL_PATH/minio server $DATA_PATH
  Restart=always
  LimitNOFILE=65536

  TimeoutStopSec=infinity
  SendSIGKILL=no

  [Install]
  WantedBy=multi-user.target
  "
  echo "$SERVICE_CONTENT" > $SYSTEMD_PATH

  echo "starting servie $SYSTEMD_NAME"
  systemctl daemon-reload || die "systemctl daemon-reload error"
  systemctl enable $SYSTEMD_NAME || die "systemctl enable error"
  systemctl start $SYSTEMD_NAME || die "systemctl start error"
}


parse_commandline "$@"



echo ""
echo "Install params: "
echo "User: $USER"
echo "Install path: $INSTALL_PATH"
echo "Data path: $DATA_PATH"
echo "Install mc: $INSTALL_MC"
echo ""

read -p "Start install? (y/n): " confirm  && [[ $confirm == [yY] || $confirm == [yY][eE][sS] ]] || die "break"



setup_and_download
install_systemd



echo "complete!";
