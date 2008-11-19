# -*- python -*-
#
# Setup our environment
#
import glob, os.path
import lsst.SConsUtils as scons

env = scons.makeEnv(
    "lssteups",
    r"$HeadURL: svn+ssh://svn.lsstcorp.org/DMS/afw/trunk/SConstruct $",
    [],
)
Alias("install", [
    env.Install(env['prefix'], "python"),
    env.Install(env['prefix'], "bin"),
    env.Install(env['prefix'], "lib"),
    env.InstallEups(os.path.join(env['prefix'], "ups"), glob.glob(os.path.join("ups", "*.table")))
])

scons.CleanTree(r"*~ core *.so *.os *.o")

env.Declare()
env.Help("""
LSST EUPS addons
""")
