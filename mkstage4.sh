#!/bin/bash

# checks if run as root:
if ! [ "`whoami`" == "root" ]; then
  echo "`basename $0`: must be root."
  exit 1
fi

# Set variables to default values
compressor="bzip"
exclude_boot=0
exclude_connman=0
exclude_lost=0
excludes=()
excludes_list=()
has_portageq=0
has_bzip2=0
has_pbzip2=0
has_gzip=0
has_pigz=0
has_xz=0
kmod_includes=()
level=6
one_fs=0
user_excl=""
s_kernel=0
quiet=0
verbose=0

# Include paths for kernel modules
kmod_includes_list=(
"/lib64/modules/"
"/lib/modules/"
)

# Excludes - newline-delimited list of things to leave out. Put in double-quotes, please
excludes_list=(
"*/.bash_history"
"*/.lesshst"
"dev/*"
"var/tmp/*"
"media/*"
"mnt/*"
"proc/*"
"run/*"
"sys/*"
"tmp/*"
"var/lock/*"
"var/log/*"
"var/run/*"
"var/lib/docker/*"
"home/misc/portage-reiserfs.img"
"home/misc/ccache-reiserfs.img"
)

# Excludes portage default paths
excludes_list_portage=(
"var/db/repos/gentoo/*"
"usr/portage/*"
"var/cache/distfiles/*"
)

# Excludes function - create tar --exclude=foo options
exclude()
{
  addexclude="$(echo "$1" | sed 's/^\///')"
  excludes+=" --exclude="${target}${addexclude}""
}

# Kmod include function - add to tar included paths
kmodinclude()
{
  addinclude="$(echo "$1" | sed 's/^\///')"
  kmod_includes+="${target}${addinclude}"
}

# Check if program is available function
checkset()
{
	if [ `which "$1" 2> /dev/null` ]; then
		echo 1
	else
		echo 0
	fi
}

has_portageq=$(checkset portageq)
has_gzip=$(checkset gzip)
has_pigz=$(checkset pigz)
has_bzip2=$(checkset bzip2)
has_pbzip2=$(checkset pbzip2)
has_xz=$(checkset xz)

usage="usage:\n\
`basename $0` [ -q -c -b -G -l -k -o -P -v -X ] [ -s || -t <target-mountpoint> ] [ -e <additional excludes dir*> ] [ -L 0..9 ] [ -f <archive-filename> ]\n\
 -s: makes tarball of current system (same as \"-t /\")\n\
 -t: makes tarball of system located at the <target-mountpoint>\n\
 -k: separately save current kernel modules and src (smaller & save decompression time)\n\
 -q: quiet mode (no confirmation)\n\
 -o: stay on filesystem, do not traverse other FS. Watch out for /boot!\n\
 -b: exclude boot directory\n\
 -c: exclude connman network lists\n\
 -l: exclude lost+found directory\n\
 -e: an additional excludes directory (one dir one -e)\n\
 -B: compress using pbzip2 or bzip2 (default)\n\
 -G: compress using pigz or gzip
 -X: compress using xz
 -L: compression level between 0 (worst) and 9 (best). Default: 6
 -S: show available compression programs
 -v: enables tar verbose output\n\
 -h: displays this help message"

# reads options:
while getopts ':t:e:skqcblovhGBXL:Pf:' flag; do
  case "${flag}" in
    b)
    exclude_boot=1;;
    B)
    compressor="bzip";;
    c)
    exclude_connman=1;;
    e)
    user_excl+=" --exclude=${OPTARG}";;
    f)
    archive="$OPTARG";;
  	G)
  	compressor="gzip";;
    h)
    echo -e "$usage"
    exit 0;;
    k)
    s_kernel=1;;
    l)
    exclude_lost=1;;
		L)
		level="$OPTARG";;
    o)
    one_fs=1;;
    q)
    quiet=1;;
    s)
    target="/";;
    t)
    target="$OPTARG";;
    v)
    verbose=1;;
    X)
    compressor="xz";;
    \?)
    echo "Invalid option: -$OPTARG" >&2
    exit 1;;
    :)
    echo "Option -$OPTARG requires an argument." >&2
    exit 1;;
  esac
done

if [ "$target" == "" ]; then
  echo "`basename $0`: no target specified."
  echo -e "$usage"
  exit 1
fi

digits='^[0-9]+$'
if ! [[ $level =~ $digits ]]; then
	echo "Error: compression level is not a number"
	exit 1
fi

# make sure target path ends with slash
if [ "`echo $target | grep -c '\/$'`" -le "0" ]; then
  target="${target}/"
fi

# checks for quiet mode (no confirmation)
if [ "$quiet" -eq 1 ]; then
  agree="yes"
fi

# check and set desired compress program, level and file extension
#bzip and gzip use 1..9, whilst xz can do 0..9
case "$compressor" in
	bzip)
	if [ "$level" = 0 ]; then
		level=1
	fi
	extension=".tar.bz2"
	if [ has_pbzip2 ]; then
		compressor="pbzip2"
	elif [ has_bzip2 ];	then
		compressor="bzip2"
	else
		echo "Neither pbzip2 nor bzip2 are available, but (p)bzip2 compression was requested, exiting."
		exit 1
	fi
	;;
	gzip)
	if [ $level = 0 ]; then
		level=1
	fi
	extension=".tar.gz"
	if [ has_pigz ];	then
		compressor="pigz"
	elif [ has_gzip ];	then
		compressor="gzip"
	else
		echo "Neither pigz nor gzip are available, but pigz or gzip compression was requested, exiting."
		exit 1
	fi
	;;
	xz)
	extension=".tar.xz"
		if [ has_xz ];	then
		compressor="xz -T0"
	else
		echo "XZ is not available, but xz compression was requested, exiting."
		exit 1
	fi
	;;
	?)
	echo "No compression program requested, this should not even be possible, exiting."
	exit 1
	;;
esac

# determines if filename was given with relative or absolute path
if [ "`echo $archive | grep -c '^\/'`" -gt "0" ]; then
  stage4_filename="${archive}${extension}"
  ksrc_filename="${archive}-ksrc${extension}"
  kmod_filename="${archive}-kmod${extension}"
else
  stage4_filename="`pwd`/${archive}${extension}"
  ksrc_filename="`pwd`/${archive}-ksrc${extension}"
  kmod_filename="`pwd`/${archive}-kmod${extension}"
fi

if [ ${s_kernel} -eq 1 ]; then
  excludes_list+=("usr/src/*")
  excludes_list+=("lib64/modules/*")
  excludes_list+=("lib/modules/*")
  excludes_list+=("$ksrc_filename")
  excludes_list+=("$kmod_filename")
fi

excludes+=$user_excl

# Exclude backup archive file name
# Exclude portage repository and distfiles by portageq info
# Revert to default, if portageq is not available or backup source is not host system
if [ "$target" == "/" ]; then
  excludes_list+=("${stage4_filename}")
  if [ ${has_portageq} == 1 ]; then
    excludes_list+=($(portageq get_repo_path / gentoo)"/")
    excludes_list+=($(portageq distdir)"/")
  else
    excludes_list+=("${excludes_list_portage[@]}")
  fi
else
  excludes_list+=("${excludes_list_portage[@]}")
fi

if [ ${exclude_connman} -eq 1 ]; then
  excludes_list+=("var/lib/connman/*")
fi

if [ ${exclude_boot} -eq 1 ]; then
  excludes_list+=("boot/*")
fi

if [ ${exclude_lost} -eq 1 ]; then
  excludes_list+=("lost+found")
fi

# Generic tar options:
tar_options="--create --preserve-permissions --absolute-names --ignore-failed-read --xattrs-include='*.*' --numeric-owner --sparse --exclude-backups --exclude-caches --sort=name"

if [ ${verbose} -eq 1 ]; then
  tar_options+=" --verbose"
fi

if [ ${one_fs} -eq 1 ]; then
  tar_options+=" --one-file-system"
fi

# Loop through the includes list, before starting
for i in "${kmod_includes_list[@]}"; do
	if [ -e "${target}/${i}" ]; then
		kmodinclude "$i"
	fi
done

# Loop through the final excludes list, before starting
for i in "${excludes_list[@]}"; do
  exclude "$i"
done

# if not in quiet mode, this message will be displayed:
if [ "$agree" != "yes" ]; then
  echo -e "Are you sure that you want to make a stage 4 tarball${normal} of the system
  \rlocated under the following directory: $target ?
  \n\rWARNING: All data is saved by default, you should exclude every security- or privacy-related file,
  \rnot already excluded by mkstage4 options (such as -c), manually per cmdline.
  \rexample: \$ `basename $0` -s /my-backup --exclude=/etc/ssh/ssh_host*\n
  \n\rCOMMAND LINE PREVIEW:
  \r###SYSTEM###
  \rtar $excludes $tar_options -f - ${target}* | ${compressor} -$level -c > $stage4_filename"

if [ ${s_kernel} -eq 1 ]; then
  echo -e "
  \r###KERNEL SOURCE###
  \rtar ${tar_options} -f - ${target}usr/src/linux* | ${compressor} -${level} -c > $ksrc_filename

  \r###KERNEL MODULES###
  \rtar ${tar_options} -f - ${kmod_includes} | ${compressor} -${level} -c > $kmod_filename"
fi
	echo -e "Compression level: $level"
  echo -ne "\n
  \rType \"yes\" to continue or anything else to quit: "
  read agree
fi

# start stage4 creation:
if [ "$agree" == "yes" ]; then
	tar ${excludes} ${tar_options} -f - ${target}* | ${compressor} -${level} -c > "$stage4_filename"
  if [ ${s_kernel} -eq 1 ]; then
		tar ${tar_options} -f - ${target}usr/src/linux* | ${compressor} -${level} -c > "$ksrc_filename"
    tar ${tar_options} -f - ${kmod_includes} | ${compressor} -${level} -c > "$kmod_filename"
  fi
fi

exit 0
