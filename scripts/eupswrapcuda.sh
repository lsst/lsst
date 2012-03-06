#!/bin/bash

usage()
{
cat <<-EOF
usage: $(basename $0) [-f] [-d] [-r=pkgroot] <path_to_CUDA_Toolkit>
usage: $(basename $0) [-f] [-d] [-r=pkgroot] -a

Generate an EUPS package wrapper around NVIDIA CUDA Toolkit.

Options:
    -a              autodetect CUDA if nvcc is on path
    -r              root where to generate the EUPS package
    -f              overwrite package if already exists
    -d              declare the package to EUPS
    -h              help

Notes:
    If pkgroot is not given, the package will be generated in
    "\$EUPS_PATH/<flavor>/cuda_toolkit/\$VERSION".
EOF
}

while getopts 'fdhar:' OPTION
do
	case $OPTION in
	    h)
		   usage
		   exit 1
		   ;;
	    f)
	           FORCE=yes
	           ;;
	    r)
	           PKG="$OPTARG"
	           ;;
	    d)
	           DECLARE=yes
	           ;;
	    a)
	           AUTO=yes
	           ;;
	    ?)
		   usage
		   exit 1
		   ;;
	esac
	shift $((OPTIND-1)); OPTIND=1
done

if [ ! \( -z "$AUTO" -a $# -eq 1 \) -a ! \( ! -z "$AUTO" -a $# -eq 0 \) ]; then
	usage
	exit 1
fi

# Do no harm.
set -e

# Verify CUDA toolkit is there
CUDA="${1-$(which nvcc 2>/dev/null | xargs dirname 2>/dev/null | xargs dirname 2>/dev/null)}"
NVCC="$CUDA/bin/nvcc"
test -x "$NVCC" ||
  { echo "Error: $NVCC does not exist or isn't executable."; exit 1; }
test -f "$CUDA/lib64/libcudart.so" -o -f "$CUDA/lib/libcudart.so" || 
  { echo "Error: Cannot find libcudart.so in $CUDA/lib nor $CUDA/lib64"; exit 1; }
test -f "$CUDA/include/cuda.h" ||
  { echo "Error: Cannot find cuda.h in $CUDA/include"; exit 1; }

# Detect toolkit version
VERSION=$($NVCC --version | sed -n 's/^.*elease \(.*\),.*/\1/p')

# Decide where to generate the EUPS wrapper package
if [ -z "$PKG" ]; then
	type eups 2>/dev/null 1>/dev/null || { echo "EUPS not found; have you sourced loadLSST.*?"; exit 1; }
	PKG="$(eups path 0)/$(eups flavor)/cuda_toolkit/$VERSION"
	DCL="eups declare cuda_toolkit $VERSION"
else
	DCL="eups declare -r $PKG cuda_toolkit $VERSION"
fi

if [ -e "$PKG" -a -z "$FORCE" ]; then
	echo "Directory $PKG exists. Use -f to force overwrite."
	exit 1;
fi

# Generate the EUPS wrapper
mkdir -p "$PKG" && pushd $PWD >/dev/null && cd "$PKG"
for D in bin lib lib64 include; do
	ln -sf "$CUDA/$D"
done

mkdir -p ups
cat > ups/cuda_toolkit.cfg <<-EOF
	# -*- python -*-
	
	import lsst.sconsUtils
	import os
	
	dependencies = {}
	
	class Configuration(lsst.sconsUtils.Configuration):
	
	    def __init__(self):
	        lsst.sconsUtils.Configuration.__init__(self, __file__, libs=[], hasSwigFiles=False,
	                                               hasDoxygenTag=False,
	                                               eupsProduct="cuda_toolkit")
	
	    def configure(self, conf, packages, check=False, build=True):
	        conf.env.Append(CCFLAGS = ["-DGPU_BUILD"])
	        conf.env.Append(NVCCFLAGS = "-DGPU_BUILD")
	        conf.env.Append(NVCCFLAGS = " --ptxas-options=-v ")
	        conf.env.Append(NVCCFLAGS = ' -maxrregcount=58 ')
	        conf.env.Append(NVCCFLAGS = ' -gencode=arch=compute_13,code=\\\\"sm_13,compute_13\\\\" ')
	        conf.env.Append(NVCCFLAGS = ' -gencode=arch=compute_20,code=\\\\"sm_20,compute_20\\\\" ')
	        conf.env.Append(SHAREDNVCCFLAGS = ' --compiler-options "-fPIC" ')
	        conf.env.Append(CPPPATH = [os.path.join(self.root, "include")])
	        conf.env.Append(LIBPATH = [os.path.join(self.root, "lib64")])
	        conf.env.Append(LIBPATH = [os.path.join(self.root, "lib")])
	        if "main" not in conf.env.libs:
	            conf.env.libs["main"] = []
	        if "cudart" not in conf.env.libs["main"]:
	            conf.env.libs["main"].append("cudart")
	        if check:
	            pass # should add some tests to verify that we can find cuda here
	        return True
	
	config = Configuration()
EOF

cat > ups/cuda_toolkit.table <<-EOF
	envPrepend(PATH, \${PRODUCT_DIR}/bin)

	envPrepend(LD_LIBRARY_PATH, \${PRODUCT_DIR}/lib)
	envPrepend(LD_LIBRARY_PATH, \${PRODUCT_DIR}/lib64)

	envPrepend(DYLD_LIBRARY_PATH, \${PRODUCT_DIR}/lib)
	envPrepend(DYLD_LIBRARY_PATH, \${PRODUCT_DIR}/lib64)
EOF

cat > README <<-EOF
	EUPS package wrapper for CUDA $VERSION, as found
	in directory $CUDA.
EOF

popd >/dev/null
if [ ! -z "$DECLARE" ]; then
	$DCL --force --nolock
fi

echo "EUPS CUDA $VERSION package created in $PKG. Make it known to EUPS using:" | fold -s
test -z "$DECLARE" && echo "   $DCL"
echo "   setup cuda_toolkit $VERSION"
