#!/bin/bash

# checks if run as root:
if ! [ "`whoami`" == "root" ]; then
  echo "`basename $0`: must be root."
  exit 1
fi

# Set variables to default values
EXCLUDE_BOOT=0
EXCLUDE_CONNMAN=0
EXCLUDE_LOST=0
QUIET=0
USER_EXCL=""
S_KERNEL=0
HAS_PORTAGEQ=0
HAS_BZIP2=0
HAS_PBZIP2=0
HAS_GZIP=0
HAS_PIGZ=0
HAS_XZ=0
COMPRESSOR="bzip"
LEVEL=6
VERBOSE=0
ONE_FS=0

# Excludes - newline-delimited list of things to leave out. Put in double-quotes, please
EXCLUDES_LIST=(
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
)

# Excludes portage default paths
EXCLUDES_LIST_PORTAGE=(
"var/db/repos/gentoo/*"
"usr/portage/*"
"var/cache/distfiles/*"
)

# Excludes function - create tar --exclude=foo options
exclude()
{
  ADDEXCLUDE="$(echo "$1" | sed 's/^\///')"
  EXCLUDES+=" --exclude="$TARGET$ADDEXCLUDE""
	echo "excluding "$TARGET$ADDEXCLUDE""
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

HAS_PORTAGEQ=$(checkset portageq)
HAS_GZIP=$(checkset gzip)
HAS_PIGZ=$(checkset pigz)
HAS_BZIP2=$(checkset bzip2)
HAS_PBZIP2=$(checkset pbzip2)
HAS_XZ=$(checkset xz)

USAGE="usage:\n\
`basename $0` [ -q -c -b -G -l -k -o -P -v -X ] [ -s || -t <target-mountpoint> ] [ -e <additional excludes dir*> ] [ -L 0..9 ] [ -f <archive-filename> ]\n\
 -q: quiet mode (no confirmation)\n\
 -b: exclude boot directory\n\
 -c: exclude connman network lists\n\
 -l: exclude lost+found directory\n\
 -o: stay on filesystem, do not traverse other FS. Watch out for /boot!\n\
 -B: compress using pbzip2 or bzip2 (default)\n\
 -X: compress using xz
 -G: compress using pigz or gzip
 -L: compression level between 0 (worst) and 9 (best). Default: 6
 -S: show available compression programs
 -e: an additional excludes directory (one dir one -e)\n\
 -s: makes tarball of current system (same as \"-t /\")\n\
 -k: separately save current kernel modules and src (smaller & save decompression time)\n\
 -t: makes tarball of system located at the <target-mountpoint>\n\
 -v: enables tar verbose output\n\
 -h: displays this help message"

# reads options:
while getopts ':t:e:skqcblovhGBXL:Pf:' flag; do
  case "${flag}" in
    t)
    TARGET="$OPTARG";;
    s)
    TARGET="/";;
    q)
    QUIET=1;;
    f)
    ARCHIVE="$OPTARG";;
    k)
    S_KERNEL=1;;
    c)
    EXCLUDE_CONNMAN=1;;
    b)
    EXCLUDE_BOOT=1;;
    l)
    EXCLUDE_LOST=1;;
    e)
    USER_EXCL+=" --exclude=${OPTARG}";;
    o)
    ONE_FS=1;;
    B)
    COMPRESSOR="bzip";;
    X)
    COMPRESSOR="xz";;
  	G)
  	COMPRESSOR="gzip";;
		L)
		LEVEL="$OPTARG";;
    v)
    VERBOSE=1;;
    h)
    echo -e "$USAGE"
    exit 0;;
    f)
    FILE="$OPTARG";;
    \?)
    echo "Invalid option: -$OPTARG" >&2
    exit 1;;
    :)
    echo "Option -$OPTARG requires an argument." >&2
    exit 1;;
  esac
done

if [ "$TARGET" == "" ]; then
  echo "`basename $0`: no target specified."
  echo -e "$USAGE"
  exit 1
fi

digits='^[0-9]+$'
if ! [[ $LEVEL =~ $digits ]]; then
	echo "Error: compression level is not a number"
	exit 1
fi

# make sure TARGET path ends with slash
if [ "`echo $TARGET | grep -c '\/$'`" -le "0" ]; then
  TARGET="${TARGET}/"
fi

# checks for quiet mode (no confirmation)
if [ ${QUIET} -eq 1 ]; then
  AGREE="yes"
fi

# check and set desired compress program, level and file extension
#bzip and gzip use 1..9, whilst xz can do 0..9
case "$COMPRESSOR" in
	bzip)
	if [ $LEVEL = 0 ]; then
		LEVEL=1
	fi
	EXTENSION=".tar.bz2"
	if [ HAS_PBZIP2 ]; then
		COMPRESSOR="pbzip2"
	elif [ HAS_BZIP2 ];	then
		COMPRESSOR="bzip2"
	else
		echo "Neither pbzip2 nor bzip2 are available, but (p)bzip2 compression was requested, exiting."
		exit 1
	fi
	;;
	gzip)
	if [ $LEVEL = 0 ]; then
		LEVEL=1
	fi
	EXTENSION=".tar.gz"
	if [ HAS_PIGZ ];	then
		COMPRESSOR="pigz"
	elif [ HAS_GZIP ];	then
		COMPRESSOR="gzip"
	else
		echo "Neither pigz nor gzip are available, but pigz or gzip compression was requested, exiting."
		exit 1
	fi
	;;
	xz)
	EXTENSION=".tar.xz"
		if [ HAS_XZ ];	then
		COMPRESSOR="xz -T0"
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
if [ "`echo $ARCHIVE | grep -c '^\/'`" -gt "0" ]; then
  STAGE4_FILENAME="${ARCHIVE}${EXTENSION}"
  KSRC_FILENAME="${ARCHIVE}-ksrc${EXTENSION}"
  KMOD_FILENAME="${ARCHIVE}-kmod${EXTENSION}"
else
  STAGE4_FILENAME="`pwd`/${ARCHIVE}${EXTENSION}"
  KSRC_FILENAME="`pwd`/${ARCHIVE}-ksrc${EXTENSION}"
  KMOD_FILENAME="`pwd`/${ARCHIVE}-kmod${EXTENSION}"
fi

if [ ${S_KERNEL} -eq 1 ]; then
  EXCLUDES_LIST+=("usr/src"/*)
  EXCLUDES_LIST+=("lib64/modules"/*)
  EXCLUDES_LIST+=("lib/modules/"*)
  EXCLUDES_LIST+=("$KSRC_FILENAME")
  EXCLUDES_LIST+=("$KMOD_FILENAME")
fi

EXCLUDES+=$USER_EXCL

# Exclude backup archive file name
# Exclude portage repository and distfiles by portageq info
# Revert to default, if portageq is not available or backup source is not host system
if [ "$TARGET" == "/" ]; then
  EXCLUDES_LIST+=("${STAGE4_FILENAME}")
  if [ ${HAS_PORTAGEQ} == 1 ]; then
    EXCLUDES_LIST+=($(portageq get_repo_path / gentoo)"/")
    EXCLUDES_LIST+=($(portageq distdir)"/")
  else
    EXCLUDES_LIST+=("${EXCLUDES_LIST_PORTAGE[@]}")
  fi
else
  EXCLUDES_LIST+=("${EXCLUDES_LIST_PORTAGE[@]}")
fi

if [ ${EXCLUDE_CONNMAN} -eq 1 ]; then
  EXCLUDES_LIST+=("var/lib/connman/*")
fi

if [ ${EXCLUDE_BOOT} -eq 1 ]; then
  EXCLUDES_LIST+=("boot/*")
fi

if [ ${EXCLUDE_LOST} -eq 1 ]; then
  EXCLUDES_LIST+=("lost+found")
fi

# Generic tar options:
TAR_OPTIONS="--create --preserve-permissions --absolute-names --ignore-failed-read --xattrs-include='*.*' --numeric-owner --sparse --exclude-backups --exclude-caches --sort=name"

if [ ${VERBOSE} -eq 1 ]; then
  TAR_OPTIONS+=" --verbose"
fi

if [ ${ONE_FS} -eq 1 ]; then
  TAR_OPTIONS+=" --one-file-system"
fi

# Loop through the final excludes list, before starting
for i in "${EXCLUDES_LIST[@]}"; do
  exclude "$i"
done

# if not in quiet mode, this message will be displayed:
if [ "$AGREE" != "yes" ]; then
  echo -e "Are you sure that you want to make a stage 4 tarball${normal} of the system
  \rlocated under the following directory: $TARGET ?
  \n\rWARNING: All data is saved by default, you should exclude every security- or privacy-related file,
  \rnot already excluded by mkstage4 options (such as -c), manually per cmdline.
  \rexample: \$ `basename $0` -s /my-backup --exclude=/etc/ssh/ssh_host*\n
  \n\rCOMMAND LINE PREVIEW:
  \r###SYSTEM###
  \rtar $TAR_OPTIONS $EXCLUDES $OPTIONS -f - ${TARGET}* | ${COMPRESSOR} -$LEVEL -c > $STAGE4_FILENAME"

if [ ${S_KERNEL} -eq 1 ]; then
  echo -e "
  \r###KERNEL SOURCE###
  \rtar $TAR_OPTIONS -f - ${TARGET}usr/src/linux* | ${COMPRESSOR} -$LEVEL -c > $KSRC_FILENAME

  \r###KERNEL MODULES###
  \rtar $TAR_OPTIONS -f - ${TARGET}lib64/modules/* ${TARGET}lib/modules/* | ${COMPRESSOR} -$LEVEL -c >	$KMOD_FILENAME"
fi
	echo -e "Compression level: $LEVEL"
  echo -ne "\n
  \rType \"yes\" to continue or anything else to quit: "
  read AGREE
fi

# start stage4 creation:
if [ "$AGREE" == "yes" ]; then
	tar $TAR_OPTIONS $EXCLUDES $OPTIONS -f - ${TARGET}* | ${COMPRESSOR} -"$LEVEL" -c > "$STAGE4_FILENAME"
  if [ ${S_KERNEL} -eq 1 ]; then
		tar $TAR_OPTIONS -f - ${TARGET}usr/src/linux* | ${COMPRESSOR} -"$LEVEL" -c > "$KSRC_FILENAME"
    tar $TAR_OPTIONS -f - ${TARGET}lib64/modules/* ${TARGET}lib/modules/* | ${COMPRESSOR} -"$LEVEL" -c > "$KMOD_FILENAME"
  fi
fi

exit 0
