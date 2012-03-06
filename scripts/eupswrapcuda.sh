#!/bin/bash

if [ $# -ne 1 -a $# -ne 2 ]; then
	echo 
	echo "Generate an EUPS package wrapper around NVIDIA CUDA Toolkit"
	echo
	echo "Usage: $(basename $0) <path_to_CUDA_Toolkit> [pkg_dir]";
	echo
	echo "If [pkg_dir] is not given, the package will be generated in"
	echo "\"\$EUPS_PATH/<flavor>/cuda_toolkit/\$VERSION\"."
	echo
	exit 1;
fi

# Do no harm.
set -e

# Detect CUDA compiler and version
CUDA="$1"
NVCC="$CUDA/bin/nvcc"
test -x $NVCC || { echo "Error: $NVCC does not exist or isn't executable."; exit 1; }
VERSION=$($NVCC --version | sed -n 's/^.*elease \(.*\),.*/\1/p')

# Decide where to generate the EUPS wrapper package
if [ -z "$2" ]; then
	type eups 2>/dev/null 1>/dev/null || { echo "EUPS not found; have you sourced loadLSST.*?"; exit 1; }
	PKG="$(eups path 0)/$(eups flavor)/cuda_toolkit/$VERSION"
	DCL="eups declare --force cuda_toolkit $VERSION"
else
	PKG="$2"
	DCL="eups declare --force -r $PKG cuda_toolkit $VERSION"
fi

if [ -e "$PKG" ]; then
	echo "Directory $PKG exists. Aborting."
	exit 1;
fi

# Generate the EUPS wrapper
mkdir -p "$PKG" && cd "$PKG"
for D in bin lib lib64 include; do
	ln -s "$CUDA/$D"
done

mkdir ups
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
	        conf.env.Append(NVCCFLAGS = ' -gencode=arch=compute_13,code=\\"sm_13,compute_13\\" ')
	        conf.env.Append(NVCCFLAGS = ' -gencode=arch=compute_20,code=\\"sm_20,compute_20\\" ')
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

echo "EUPS CUDA $VERSION package generated in $PKG."
echo ""
echo "Declare it to EUPS using:"
echo "   $DCL"
echo "and set it up with:"
echo "   setup cuda_toolkit $VERSION"
