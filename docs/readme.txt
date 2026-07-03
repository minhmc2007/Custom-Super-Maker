repacksuper
===========
Copyleft uluruman 2021-2024

(for LINUX/WSL only)

This is the minimalistic set of tools + a script for Linux for the automated
ground-up repacking and flashing of the Samsung Galaxy super.img, replacing
the stock Android system with something much less intrusive and obtrusive
(e.g. LineageOS). Or just some other GSI (Generic System Image).

Additional included scripts (since v1.1) simplify flashing of stock firmware or
separate image files under Linux using Heimdall.

Theoretically should work for any Samsung A-series phones, and may be even for
some others. Tested on SM-A127F/DSN made in India and Vietnam and SM-A325F/DS
made in India, on Debian Linux 11 x64. There are reports of successful flashing
of SM-A127M, SM-A032M and SM-A226B.

Why this method?
----------------
Repacking of super.img is the only method which allows changing of the phone's
operating system without screwing up the Verified Boot (VB) protection
mechanism. Keeping the VB allows you to be sure that everything besides the
platform was indeed compiled by Samsung and wasn't tampered with, no matter from
where you downloaded your stock firmware.

The other reason is that although there are alternative methods of changing the
OS, for phones with dynamic partitioning and no working version of TWRP
available they may be even more complicated than repacking of super.img
externally by this script.

Changelog
---------
0.9: Initial release
0.91: Non-sparse new system is now correctly moved into the super dir
0.91a: Bug in the new system file format checking fixed
0.91b: Better support for spaces in paths
0.92: Added checking for system requirements and an optional parameter for
      setting of the final tar archive name.
0.92a: Fixed file ownership issues inside the tar distribution archive
0.93: Added support for SM-A325F. Several minor improvements.
0.94: Added support for gzip-packed GSI images. Packing into .tar is now done
      without question if the command line parameter is given. Tar parameter
      now can include the full path. Without the full path the default tar
      location is now the same as the GSI. Several other minor changes.
1.0: Finally added working native Linux flashing using Heimdall (HUGE thanks
     to amo13 and Benjamin Dobell). Two new options: using empty product.img
     and silent (non-interactive) mode. Colored text. Bugfixes and minor
     changes.
1.01: Option to specify the SUPER partition name manually (needed for flashing
      SM-A127F with Heimdall). Now it is possible to place output .img and .tar
      files in any directory and give them any name. Text terminology a bit
      clarified, help text expanded. Done many internal optimizations,
      additional sanity checks and minor changes.
1.02: Support for SM-A032F/M and similar firmwares with non-packed super.img.
      Support for firmwares with/without additional partitions. Support for
      arbitrary partition group names. Lots of minor fixes.
1.03: Multiple .img files are now supported in GSI archive files (one of them
      should be system.img in that case), e.g. Android AOSP zip files are now
      supported directly. The logic of flashing with Heimdall now includes more
      complex cases, such as flashing in two steps with a reboot. Unnecessary
      code in GZ unpacking removed.
1.1: New scripts heimdall_flash_stock.sh and heimdall_flash.sh added.
     Lots of refactoring in repacksuper.sh (because of that there may be some
     bugs left), improved and clarified UI logic, changes in where the files are
     now placed (see help for details), direct work with stock Zip firmware
     files, lots of minor changes.
1.11: Colored text now should be correctly displayed in almost any shell that
      supports it except if it's explicitly disabled with NO_COLOR.
1.11.1: heimdall_flash.sh now can flash Super partitions unconditionally in one
        step when using both the -s parameter and manually specifying parition
        name (e.g. SUPER for SM-A127F).
1.12: The heimdall_flash_stock.sh script was significantly upgraded with lots of
      new features. Now it theoretically allows upgrading of stock firmware
      without erasing user data, keeping the GSI and custom recovery, etc.
      (although it's not that straightforward, read the help for details).
      A couple of fixes in the other scripts.
1.12.1: changed unlz4 to lz4 -d, as some distros don't have the needed symlink
1.13: In repacksuper.sh support added for the Vendor DLKM and ODM DLKM
      partitions, as well as the experimental -v option to add or replace Vendor
      DLKM with a custom image. A couple of minor fixes.
1.14: Greatly improved logic of heimdall_flash.sh, now it's possible to specify
      both or either custom partition name and custom file name, and acquiring
      PIT from device is done only when it's needed. Versioning scheme of the
      scripts was unified: the script that was updated receives the updated
      version number of the whole pack, the rest retain the old numbers.
1.15: up_param_tool.sh script was added: it allows altering of the boot
      sequence images (logo, "not official" warning, etc.), as well as the
      Recovery and Download internal graphics. Happy hacking, but please pay
      attention to the warning displayed after extracting the JPEG files.
      A couple of minor fixes in the other scripts.
1.15.1: Bug with failing LZ4 uncompression fixed in repacksuper.sh and
        heimdall_flash_stock.sh.
1.15.2: Added the Ctrl+C trap in heimdall_flash_stock.sh, so now the temporarily
        renamed files are correctly renamed back in case of flashing being
        aborted with Ctrl+C. Upgraded Heimdall with the git pull requests, but
        it seems those still do not cure the relatively rare issue when flashing
        specific files gets completely stuck at some point.
1.15.3: The "file" tool used to identify PIT files was replaced with direct
        reading of the file header as the first method proved to be unreliable.
1.15.4: Fixed a bug in heimdall_flash.sh (missing g flag in sed)
1.15.5: Fixed the compatibility issue with the older LZ4 compressors
1.15.6: Fixed compatibility issues with systems where /bin/sh is Bash, such as
        ArchLinux
1.15.7: repacksuper.sh: fixed using the existing "repacksuper" dir as source,
        also in this mode you can now specify "-" as new system image to reuse
        everything inside the "super" subdir. New experimental -w parameter.
        All scripts: the Ctrl+C trap now switched on and off the correct way.
        Several other fixes.
1.15.8: Fixed using the heimdall_flash_stock dirs as source for repacksuper.sh.
        A couple of other fixes.
1.15.9: heimdall_flash_stock.sh: fixed skipping of duplicate partitions (e.g.
        vbmeta) for some shells; fixed upgrade-flashing of Galaxy A32 (default
        behavior).
1.16.0: Fixed bug with unpacking GZ-packed GSI images. Refactored support for
        dir/file names with spaces. A couple or minor fixes. Fixed the message
        about disconnecting the USB cable.
1.16.1: Updated lpunpack_and_lpmake to the amackpro's fork with support for
        Android 15. Updated Heimdall to the casey-riley's fork with (hopefully)
        better support for the latest devices.

Requirements
------------
Install the following tools from the official repositories of your Linux distro:
simg2img xz-utils lz4 unzip gzip jq file

Basic instructions
------------------
repacksuper.sh: main script for changing your phone's operating system
heimdall_flash_stock.sh: script for flashing stock firmware under Linux
heimdall_flash.sh: script for flashing any custom image file under Linux
Just run a script without any arguments to see help.

Extra tools used (x64 binaries and sources included)
----------------------------------------------------
https://github.com/amackpro/lpunpack_and_lpmake
https://github.com/casey-riley/Heimdall-libusb-updates

Additional notes
----------------
The included binaries for the lpunpack, lpmake and Heimdall were compiled for
the x86_64 architecture. If your PC architecture is different (e.g. x86 32-bit
or ARM) you have to compile these tools yourself. The full source code is
included (or otherwise available on GitHub).

Known issues (not solvable by the script)
-----------------------------------------
During the script run you can see several "Invalid sparse file format at header
magic" warnings, just ignore them.

For some firmware files Heimdall may not work at all (freeze indefinitely or
exit with an error), in that case you have to resort to Odin. In many cases
Heimdall freezes when uploading files for some time, but that does not mean it
is completely frozen, just be patient.

In LineageOS, Dot OS and some other GSIs I tried on SM-127F the touch screen
remains not responsive for about 6 seconds after waking up. The problem is not
present at least with SM-127F/DSN phones made in India, but present at least in
those made in Vietnam, which means it is not caused by the OS installation
approach but rather by the quirks of the phone hardware itself. Solution should
require tweaking of the kernel behavior but it's beyond my capabilities.

In the most, if not all, GSIs USB file transfer does not work (at least on
Linux) because of the "wrong" (Samsung's instead of Google's) default MPT driver
used by the kernel. Again fixing this requires patching and rebuilding the
kernel from sources and repacking of the boot image, which is still a bit beyond
my capabilities, although there were reports of success from other people.
Alternative solutions include using apps such as Warpinator, Syncthing or ftpd.

Food for thought
----------------
When choosing a GSI to install I really don't recommend using ones which include
GApps and therefore use any of the Google services. Don't let corporations
gather your data. You bought the phone and from now on it should be all yours,
with all of its data, like a PC in the good old days. You own your device, and
nobody has the right to stick their nose into how you use your phone, gather any
statistics and push you any ads. You always have a choice to turn down
privacy-unfriendly stuff, the price of that "inconvenience" is actually
ridiculous. From my point of view, there is simply no point in using non-stock
systems if they are still littered with the privacy-unfriendly bloatware.

