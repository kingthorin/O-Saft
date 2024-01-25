#!/bin/sh
#?
#? NAME
#?       $0 - generate o-saft_standalone.pl
#?
#? SYNOPSIS
#?       $0
#?       $0 [OPTIONS] [output-file]
#?
#? OPTIONS
#?       --h     got it
#?       --n     do not execute, just show what would be done
#?       --t     do not check if all files are commited to repository
#?       --s     silent, do not print informations (for usage with Makefile)
#?       --v     be a bit verbose
#?       --exe=PL  use  PL  as Script; default: o-saft.pl
#?
#? DESCRIPTION
#?       Generate script, which contains (all) modules for O-Saft.
#?       Prints on STDOUT if no [output-file] was specified.
#?
#?       NOTE: this will not generate a bulletproof stand-alone script!
#?
#? VERSION
#?       @(#) "�[ 3.1 24/01/23 11:42:25
#?
#? AUTHOR
#?      02-apr-16 Achim Hoffmann
#?
# -----------------------------------------------------------------------------

dst=/dev/stdout # default STDOUT
src=o-saft.pl ; [ -f $src ] || src=../$src
try=
sid=1
info=1

while [ $# -gt 0 ]; do
	case "$1" in
	 '-h' | '--h' | '--help')
		ich=${0##*/}
		\sed -ne "s/\$0/$ich/g" -e '/^#?/s/#?//p' $0
		exit 0
		;;
	 '-n' | '--n') try=echo; ;;
	 '-t' | '--t') sid=0   ; ;;
	 '-s' | '--s') info=0  ; ;;
	 '-v' | '--v') set -x  ; ;;
	 '-x' | '--x') set -x  ; ;;
         --exe=*)      src="`expr "$1" ':' '--exe=\(.*\)'`" ; ;;
	 *)            dst="$1"; ;;
	esac
	shift
done

if [ ! -e "$src" ]; then
  	\echo "**ERROR: '$src' does not exist; exit"
	[ "echo" = "$try" ] || exit 2
fi

# make e-SRC.pm
_osaft_lib="
	lib/OCfg.pm
	lib/Ciphers.pm
	lib/error_handler.pm
	lib/SSLhello.pm
	lib/SSLinfo.pm
	lib/OData.pm
	lib/ODoc.pm
	lib/OMan.pm
	lib/OText.pm
	lib/OTrace.pm
	lib/OUsr.pm
"

o_saft=""
for f in $_osaft_lib ; do
	[ -f $f ] || f=../$f    # quick&dirty if called in sub-directory
	o_saft="$o_saft $f"
done

# make e-O-SRC.txt
_osaft_doc="
	lib/Doc/coding.txt
	lib/Doc/glossary.txt
	lib/Doc/help.txt
	lib/Doc/links.txt
	lib/Doc/rfc.txt
	lib/Doc/tools.txt
"
#	lib/Doc/devel.txt
#	lib/Doc/misc.txt \
#	lib/Doc/openssl.txt
osaft_doc=""
for f in $_osaft_doc ; do
	[ -f $f ] || f=../$f    # quick&dirty if called in sub-directory
	osaft_doc="$osaft_doc $f"
done


if [ $sid -eq 1 ]; then
	for f in $o_saft ; do
		# NOTE contribution to SCCS:  %I''%
		\egrep -q 'SID.*%I''%' $f \
	  	&& \echo "**ERROR: '$f' changes not commited; exit" \
	  	&& exit 2
	done
fi

if [ $info -eq 1 ]; then
	if [ "/dev/stdout" = "$dst" ]; then
		\echo "# generate file standalone.pl ..."
	else
		\echo "# generate $dst ..."
	fi
	\echo ""
fi

[ "/dev/stdout" != "$dst" ] && $try \rm -rf $dst

[ "$try" = "echo" ] && dst=/dev/stdout

# general workflow and hints how to include:
#
# 1.  extract from o-saft.pl anything before line
## PACKAGES
#
# 2. add o-saft.pl POD
#
# 3. add $osaft_standalone
#
# 4. include all own modules
# .. include text from module file enclosed in  ## PACKAGE  scope  from all modules
#
# 5. add rest of o-saft.pl
#
# 6. include cipher definitions from lib/Ciphers.pm
#
# 7. add separator line for POD; do some more replacements

all_src=`\echo "$src $_osaft_lib" | \perl -pe 's/^\s+//; s/\n/ /msg'`
    # convert multi-line string to one line; s/\n\s*/ /msg does not work
(
  # 1.
  #$try \perl -ne 'print if (m()..m(## PACKAGES ))' $src
  $try \perl -ne 'print if (m()..m(## [{]))' $src
  \echo "## generated by "�[ 3.1, using:"
  \echo "## $all_src"
  \echo ''
  \echo "no warnings 'redefine'; # contribution to single file"
  \echo ''
  $try \perl -ne 'print if (m(## [}])..m(## PACKAGES ))' $src
  \echo ''

  # 2.
  \echo '##____________________________________________________________________________'
  \echo '##____________________________________________________ public documentation __|'
  $try $src --no-warning --no-rc --help=pod

  # 3.
  \echo ''
  \echo 'our $osaft_standalone = 1; # inserted by "�[ 3.1'

  # need to escape keyword use; see final substitution below
  \echo ""
  \echo "MYuse warnings;"
  \echo "MYuse utf8;"
  \echo "MYuse Carp;"
  \echo "MYuse Encode;"
  \echo "MYuse Socket;"
  \echo "MYuse IO::Socket::INET;"
  \echo "MYuse IO::Socket::SSL;"
  \echo "MYuse Net::SSLeay;"
  \echo "MYuse Net::DNS;"
  \echo "MYuse Time::Local;"
  \echo "MYuse autouse 'Data::Dumper' => qw(Dumper);"
# use Exporter qw(import);
# use base qw(Exporter);
  \echo ''

  # 4.
  # our modules without brackets
  \echo '##____________________________________________________________________________'
  \echo '##_________________________________________________ include private modules __|'

  for module in $_osaft_lib; do
	f=$module ; [ -f $f ] || f=../$f
	\echo "{ # $f"
	$try \perl -ne 'print if (m(## PACKAGE [{])..m(## PACKAGE }))' $f
	\echo "} # $f"
	\echo ''

  done

  # 5.
  \echo '##____________________________________________________________________________'
  \echo '##_______________________________________________________________ main code __|'
  \echo 'package main;'
  \echo ''
  $try \perl -ne 'print if (m(## PACKAGES )..m(=pod))' $src

  # 6.
  f=lib/Ciphers.pm ; [ -f $f ] || f=../$f
  \echo '##____________________________________________________________________________'
  \echo '##_____________________________________________________ ciphers definitions __|'
  \echo "## $f DATA .. END"
  $try \perl -ne 'print if (m(## CIPHERS [{])..m(## CIPHERS }))' $f
  #$try \perl -ne 'print if (m(^__DATA__)..m(__END__))' $f
  \echo ""

  # 7.
) \
  | $try \perl -pe '/^=head1 (NAME|Annotation)/ && do{print "=head1 "."_"x77 ."\n\n";};' \
  | $try \sed  -e  's/#\s*OSAFT_STANDALONE\s*//' \
               -e  's/^use strict;//'       \
               -e  's/^\(use .*\);/# &/'    \
               -e  's/^MYuse /use /'        \
               -e  's/$STR/$OText::STR/'    \
               -e  's/^\s*our\(\s*@EXPORT\s*=\)/my \1/g'  \
> $dst


lsopt=  # tweak output if used from make
[ -z "$OSAFT_MAKE" ] && lsopt="-la"

[ "/dev/stdout" != "$dst" ] && $try \chmod 555 $dst
[ $info -eq 0 ] && exit

[ "/dev/stdout" != "$dst" ] && $try \ls $lsopt $dst

# Writing on /dev/stdout is scary on some systems (i.e Linux). If code above
# was written on /dev/stdout, the buffer may not yet flushed. Then following
# echo and cat commands,  which write on the tty's STDOUT, my overwrite what
# is already there. Some kind of race condition ...
# As the shell has no build-in posibility to flush STDOUT,  following output
# is written to /dev/stdout directly to avoid overwriting, ugly but seems to
# work ...

\cat << EoDescription >> /dev/stdout
# $dst generated

	The generated stand-alone script misses following functionality:
	* Commands
		+cipherall
		+cipher-dh
	* Options
		--exit*
		--starttls
	Use of any of these commands or options will result in Perl compile
	errors like (unsorted):
		Use of uninitialized value ...
		Undefined subroutine ...
		Subroutine XXXX redefined at ...
		"our" variable XXXX redeclared at ...

	Note that  --help and --help=*  will only work if following files
	exist or are located in the same directory as  $dst :
	$osaft_doc

	"perldoc $dst"  contains all POD of all included (module) files
	in unsorted order.

	For more details for a stand-alone script, please see:
		o-saft.pl --help=INSTALL

EoDescription

exit
