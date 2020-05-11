# mkstage4
This is a fork of the mkstage4 script maintained by Christian Horea (TheChymera).
It contains some improvements which I was missing.
All of this could be included in the original overlay, but it is not for my poor github-foo.
So feel free to take whatever you please from here; but be aware that there's no warranty for anything.

## History
This is a Bash script to create stage 4 tarballs either for the running system, or a system at a specified mount point.
The script is a fork taken from TheChymera (https://github.com/TheChymera/mkstage4) which itself is a new edition of an earlier [mkstage4 script](https://github.com/gregf/bin/blob/master/mkstage4) by Greg Fitzgerald (unmaintained as of 2012) which is itself a revamped edition of the [original mkstage4](http://blinkeye.ch/dokuwiki/doku.php/projects/mkstage4) by Reto Glauser (unmaintaied as of 2009). 
 
## Installation

The script can be run directly from its containing folder (and thus, is installed simply by downloading or cloning it from here - and adding run permissions):

```bash
git clone https://github.com/TheChymera/mkstage4.git /your/mkstage4/directory
cd /your/mkstage4/directory
chmod +x mkstage4.sh
```

## Usage

*If you are running the script from the containing folder (first install method) please make sure you use the `./mkstage4.sh` command instead of just `mkstage4`!*

Archive your current system (mounted at /):

```bash
mkstage4 -s -f archive_name
```

Archive system located at a custom mount point:

```bash
mkstage4 -t /custom/mount/point -f archive_name
```

Command line arguments:

```
mkstage4 [ -q -c -b -G -l -k -o -P -v -X ] [ -s || -t <target-mountpoint> ] [ -e <additional excludes dir*> ] [ -L 0..9 ] [ -f <archive-filename> ]
 -q: quiet mode (no confirmation)
 -b: exclude boot directory
 -c: exclude connman network lists
 -l: exclude lost+found directory
 -o: stay on filesystem, do not traverse other FS. Watch out for /boot!
 -B: compress using pbzip2 or bzip2 (default)
 -X: compress using xz
 -G: compress using pigz or gzip
 -L: compression level between 0 (worst) and 9 (best). Default: 6
 -S: show available compression programs
 -e: an additional excludes directory (one dir one -e)
 -s: makes tarball of current system (same as "-t /")
 -k: separately save current kernel modules and src (smaller & save decompression time)
 -t: makes tarball of system located at the <target-mountpoint>
 -v: enables tar verbose output
 -h: displays this help message
```

## Extract Tarball

Tarballs created with mkstage4 can be extracted with:

```bash
tar xvpf archive_name.tar.bz2
```

If you use -k option, extract src & modules separately

```bash
tar xvpf archive_name-ksrc.tar.bz2
tar xvpf archive_name-kmod.tar.bz2
```
## Dependencies

* **[Bash](https://en.wikipedia.org/wiki/Bash_(Unix_shell))** - in [Portage](http://en.wikipedia.org/wiki/Portage_(software)) as **app-shells/bash**
* **[tar](https://en.wikipedia.org/wiki/Tar_(computing))** - in Portage as **app-arch/tar**
**One-or-many-of:**
* **[gzip](https://www.gnu.org/software/gzip/)** - in Portage as **app-arch/gzip**
* **[pigz](https://www.zlib.net/pigz/)** (optional, if it is installed the archive can be compressed using multiple parallel threads) - in Portage as
**app-arch/pigz**
* **[bzip2](https://en.wikipedia.org/wiki/Bzip2)** - in Portage as
**app-arch/bzip2**
* **[pbzip2](https://launchpad.net/pbzip2)** (optional, if it is installed the archive can be compressed using multiple parallel threads) - in Portage as
**app-arch/pbzip2**


*Please note that most of these are very basic dependencies and should already be included in any Linux system,
the parallel versions will be used if available, otherwise we fall back to a single compression thread.*

---
Released under the GPLv3 license.
Project forked from TheChymera
