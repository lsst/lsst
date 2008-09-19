#! /bin/bash
#
# functions for building LSST packages
#

#@
#  return 1 if eups is setup
#
function eups_not_setup {
    
    if [ -z "$EUPS_DIR" ]; then
        echo "$prog: EUPS is apparently not setup; EUPS_DIR not set"
        return 0
    fi

    eupscmd=`/usr/bin/which eups`
    if [ -z "$eupscmd" ]; then
        echo "$prog: eups command not found (is EUPS setup?)"
        return 0
    fi  

    eupsver=`eups --version` 
    if [ "$?" -ne 0 ]; then
        echo $prog: Problem running eups $eupsver
        return 0
    fi

    return 1
}

#@ 
#  return 0 if the current user is root
#
function user_is_root {
    if [ $USER = root -o `whoami` = root ]; then
        echo "$prog: It's too dangerous to install packages as root"
        echo "Aborting"
        return 0
    fi
    return 1
}

#@ 
#  exit with an erro as a result of a keyboard interrupt.  This function is 
#  intended to be passed to the trap command.
#
function interrupted {
    echo Build has been interrupted!
    echo 
    echo Be sure to run \"lsstpkg clean $product $version\" to clean up the mess
    echo 
    exit 2
}

function cleanup {
    return 0
}

#@ 
#  clean up on exit.  This function is intended to be 
#  passed to the trap command.
#
function onexit {
    if [ -z "$normsemaphore" -a -n "$builddir" -a -f "$builddir/$build_semaphore" ]; then
        rm "$builddir/$build_semaphore"
    fi
}

#@ 
#  retrieve a file from the server.  The local copy will be named after the 
#  last path component in the URL.  
#  @param url    the URL of the file to fetch, relative the base URL  (required)
#  @param out    the name of the local copy.  If not provided, it will be 
#                    place in the current directory and named after the 
#                    last path component in the URL.  
#
function fetch  {
    if [ -z "$pkgbase" ]; then
        missing_config pkgbase 1>&2; exit $?
    fi
    if [ -z "$httpget" ]; then
        missing_config pkgbase 1>&2; exit $?
    fi

    local out
    out=$2
    [ -n "$out" ] || out=`basename $1`
    echo $httpget $pkgbase/$1 \> $out
    $httpget $pkgbase/$1 > $out
    if [ $? -ne 0 ]; then
        echo $prog: problem downloading $1 1>&2
        return 1
    fi

    echo $out
    return 0
}

#@
#  fetch the table file for the product being built.  This assumes
#  the product is an LSST one, not external.
#
function fetch_table {
    mkdir -p ups
    (chdir ups && fetch $product/$version/$product.table)
}

function missing_config {
    echo $prog: LSST Build Configuration Error: $1 variable not set
    return 5
}

#@
#  run the configure script
#  @param args    run setup with these arguments.  If not provided, setup -r 
#                    will be run
#
function dosetup {
    if [ ${#*[*]} -eq 0 ]; then
        echo Setting up product in $PWD
        echo setup -r .
        setup -r .
    else
        setup $*
    fi

    return 0
}

#@
#  run the configure script
#
function doconfig {
    if [ ! -x ./configure ]; then
        echo $prog: configure script is missing from $PWD
        return 2
    fi
    echo ./configure --prefix=$installdir $*
    echo ./configure --prefix=$installdir $* >> $buildlog
    ./configure --prefix=$installdir $* >> $buildlog 2>&1 || {
        echo "configure ..."
        tail -20 $buildlog
        echo "$prog: configure failed; see $PWD/$buildlog for details"
        return 1
    }
}

#@ 
#  source the given given build script.  This allows the script to use 
#  local variables
#  @param script   the build script
#
function run_build_file {
    set -e
    . "$1"
    set +e
}

#@
#  run the make command to build.  Any arguments will be passed to make
#
function make {
    if [ -z "$make" ]; then
        return `missing_config make`
    fi
    echo $make $*
    echo $make $* >> $buildlog 
    $make $* >> $buildlog 2>&1 || {
        echo "make ..."
        tail -20 $buildlog
        echo "$prog: make failed; see $PWD/$buildlog for details"
        return 1
    }
}

#@
#  run make install  (Arguments are ignored.)
#
function makeinstall {
    if [ -z "$make" ]; then
        missing_config make; exit $?
    fi
    echo $make install
    echo $make install >> $buildlog
    $make install >> $buildlog 2>&1 || {
        echo "make install ..."
        tail -20 $buildlog
        echo "$prog: make install failed; see $PWD/$buildlog for details"
        return 1
    }
}

#@
#  run the configure, make, and make install sequence
#
function simplemake {
    doconfig $* && make && makeinstall
    return $?
}

#@
#  run "scons install declare".  The $sconsopt variable, set to "opt=3" by 
#  default, will be included in the scons command line.
#
function simplescons {
    if [ -z "$SCONS_DIR" ]; then
        echo scons is not setup via eups
        return 4
    fi
    echo scons $sconsopt install declare $*
    echo scons $sconsopt install declare $* >> $buildlog 
    scons $sconsopt install declare $* >> $buildlog 2>&1 || {
        echo "scons ..."
        tail -20 $buildlog
        echo "$prog: scons install failed; see $PWD/$buildlog for details"
        return 1
    }
}

#@
# run "python setup.py install"
#
function pysetup {
    echo python setup.py install $*
    echo python setup.py install $* >> $buildlog
    python setup.py install $* >> $buildlog 2>&1 || {
        echo "python setup.py ..."
        tail -20 $buildlog
        echo "$prog: python setup.py install failed; see $PWD/$buildlog for details"
        return 1
    }
}

#@
# run "python setup.py install" with --home
#
function simplepysetup {
    pysetup --home=$installdir $*
}

#@
# only allow removal files under the build directory.
#
function rm {

    if [ -z "$builddir" ]; then
        echo "$prog: file removal not allowed unless builddir is set"
        return 5
    fi

    local pwdokay=`echo $PWD | grep ^$builddir`

    local -a bad=()
    local -a args=()
    while [ $# -gt 0 ]; do
        case "$1" in 
            -*) ;;
            *) { 
                    if echo $1 | grep -q ^/; then
                        { echo $1 | grep -q ^$builddir; } || bad[${#bad[*]}]=$1
                    else
                        [ -n "$pwdokay" ] || bad[${#bad[*]}]=$1
                    fi 
                };;
        esac
        args[${#args[*]}]=$1
        shift
    done

    if [ ${#bad[*]} -gt 0 ]; then
        echo "$prog: Attempt to remove files outside of $builddir:"
        echo "   ${bad[*]}"
        echo "rm command aborted"
        return 1
    fi

    # echo $rmcmd ${args[*]}
    $rmcmd ${args[*]}
}

#@
#  empty the contents of the build directory using the safe rm function
#
function empty_build_dir {
    if [ -n "$builddir" -a -d "$builddir" ]; then
        if [ `ls $builddir | wc -l` -gt 0 ]; then
            echo "Emptying the build directory"
            rm -rf $builddir/*
        fi
    fi
}

unpacking_and_building=

#@
#  unpack a given tar file, descend into it and build the contents.
#
function unpack_tar_and_build {
    local gz=
    local file=$1

    if [ -n "$unpacking_and_building" ]; then
        echo $prog: Detected dangerous recursive unpack-and-build
        return 1
    fi
    unpacking_and_building=1

    unpack_tar_and_enter $file || {
        local stat=$?
        unpacking_and_building=
        return $stat
    }

    # run the setup commands that load the environment
    setupfile=
    [ -n "$defsetupfile" -a -f "$defsetupfile" ] && setupfile=$defsetupfile
    [ -z "$setupfile" ] || . $setupfile || {
        echo $prog: Failed to load environment from $setupfile
        unpacking_and_building=
        return 1
    }
    selfsetup   # "setup -r ." is only done if $setupTableDeps != ""

    # Now build and install the product
    if [ -f "$internalbuildfile" ]; then
        # via internal build script
        . $internalbuildfile || { unpacking_and_building= ; return 1; }
    elif [ -f "SConstruct" ]; then
        # via scons
        simplescons || { unpacking_and_building= ; return 1; }
    elif [ -f "configure" ]; then
        # via config-make
        simplemake || { unpacking_and_building= ; return 1; }
    elif [ -f "setup.py" ]; then
        # via python setup.py
        simplepysetup || { unpacking_and_building= ; return 1; }
    else
        echo "Warning: nothing found to build in tar file: $file"
    fi
    unpacking_and_building=

    # the specific build operation above may have declared the product to
    # EUPS; however, if it has not, we would rather have the eups distrib 
    # wrapper handle this
    #
    # ensure_declare

    return 0
}

#@ 
#  unpack a tar file and change into its top directory
#
function unpack_tar_and_enter {
    local gz=
    local file=$1

    if [ -z "$file" ]; then
        echo $prog: unpack_tar_and_enter: missing filename argument
        return 1
    fi
    if [ ! -e "$file" ]; then
        echo $prog: unpack_tar_and_enter: $file: file not found
        return 1
    fi

    { echo $file | egrep -q '.tgz$|.gz$'; } && gz="z"
    echo tar ${gz}vxf $file
    subdir=`tar ${gz}tf $file | grep / 2> /dev/null | sed -e 's/\/.*$//' 2> /dev/null | head -1`
    tar ${gz}xf $file || {
        echo "Failed to untar $file"
        return 2
    }
    if [ -z "$subdir" -o ! -d "$subdir" ]; then
        echo "Failed to discover tar root directory for $file"
        return 1
    fi
    cd $subdir

}

#@ 
#  Set up the package to be built.  This requires that the current directory 
#  have a "ups" subdirectory containing a table file.  If none such file exists, 
#  setup will not be attempted.  
# 
#  if $setupTableDeps is non-empty, setup will be done by running "setup -r ." 
#  so that the dependencies from the table file are also setup.  If $dosetupr is
#  empty, only a "setup -j -r ."  is done.  This prevents the table file from 
#  overriding the environment required by manifest.
#
function selfsetup {
    if [ -f "ups/$product.table" ]; then
        if [ -n "$setupTableDeps" ]; then
            setup -r .
        else
            setup -j -r .
        fi
    fi
}

#@
#  ensure that the product is declared to EUPS.  
#  
function ensure_declare {

    if [ ! -d "$installdir" ]; then
        echo $prog: $product $version does not appear to be installed, yet
        return 1
    fi

    mkdir -p "$installdir/ups"
    if [ ! -e "$installdir/ups/$product.table" ]; then

        # find a table file to install
        local tfile="ups/$product.table"
        [ -f "$tfile" ] || tfile="$builddir/$product.table"

        if [ ! -f "$tfile" ]; then
            # try to get one from the server
            local path=$serverpath
            [ -n "$path" ] || path=$product/$version
            tfile=`fetch $path/$product.table` || return 1
        fi

        # install it
        cp $tfile "$installdir/ups"
    fi
    
    if [ ! -f "$installdir/ups/$product.table" ]; then 
        echo $prog: Failed to install table file into "$installdir/ups"
        return 1
    fi

    eups expandtable -i "$installdir/ups/$product.table" && \
        eups declare -r "$installdir" 
    return $?
}

