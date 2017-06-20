# -*- python -*-
#
# Setup our environment
#
import glob, os.path, re, os, sys
from lsst.sconsUtils import scripts, env, targets, log

# okay start the standard stuff

scripts.BasicSConstruct.initialize("lsst", versionModuleName=None)

targets["doc"].extend(env.Command("doc/README.md", "README.md", [Copy('$TARGET', '$SOURCE')]))

if "check" in BUILD_TARGETS:
    env.Command("configure", "configure.ac", ["autoconf"])
    env.Command("check", "configure", ["configure"])

env.Help("""
deploy/lsst:  LSST Build Environment Tools

This provides tools for building LSST products and installing them into
the software distribution server.  This package relies on the eups capabilities.
""")

scripts.BasicSConstruct.finish(subDirList="bin doc ups".split(),
                               defaultTargets=["bin", "doc", "tests"])

# this is not doing what I want it to do (removing bin)
env.Clean("bin", "bin")
