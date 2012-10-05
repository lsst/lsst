# -*- python -*-
#
# Setup our environment
#
import glob, os.path, re, os, sys
from lsst.sconsUtils import scripts, env, targets, log

# before we get into the boiler plate scons stuff, we start with 
# some specialization
lssthome = None
if not lssthome and os.environ.has_key('LSST_HOME'):
    lssthome = os.environ['LSST_HOME']
if not lssthome and os.environ.has_key('EUPS_PATH'):
    lssthome = os.environ['EUPS_PATH'].split(":", 1)[0].strip()

# okay start the standard stuff

if "lsst_home" not in env:
    env["lsst_home"] = lssthome
if "pkgsurl" not in env:
    log.warn("pkgsurl is not set; use of '--setenv pkgsurl=<value>' recommended")
    env["pkgsurl"] = "http://sw.lsstcorp.org/pkgs"
env["lsst_home"] = "".join(env["lsst_home"])
env["pkgsurl"] = "".join(env["pkgsurl"])

scripts.BasicSConstruct.initialize("lsst")

targets["doc"].extend(env.Command("doc/README.txt", "README.txt", [Copy('$TARGET', '$SOURCE')]))

Alias("loadLSST", env.Install(env['lsst_home'], 
                              Split("etc/loadLSST.sh etc/loadLSST.csh etc/loadLSST.zsh")))

if "check" in BUILD_TARGETS:
    env.Command("configure", "configure.ac", ["autoconf"])
    env.Command("check", "configure", ["configure"])

env.Help("""
deploy/lsst:  LSST Build Environment Tools

This provides tools for building LSST products and installing them into
the software distribution server.  This package relies on the eups capabilities.
""")

scripts.BasicSConstruct.finish(subDirList="bin doc etc python ups".split(),
                               defaultTargets=["bin", "doc", "etc", "tests"])

# this is not doing what I want it to do (removing bin and etc)
env.Clean("bin", "bin")
env.Clean("etc", "etc")
