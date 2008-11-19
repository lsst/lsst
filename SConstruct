# -*- python -*-
#
# Setup our environment
#
import glob, os.path
import lsst.SConsUtils as scons

env = scons.makeEnv(
    "lssteups",
    r"$HeadURL$",
    [],
)

env.Declare()
Alias("install", [
    env.Install(env['prefix'], "python"),
    env.Install(env['prefix'], "bin"),
    env.Install(env['prefix'], "lib"),
    env.InstallEups(os.path.join(env['prefix'], "ups"))
    ])

scons.CleanTree(r"*~ core *.so *.os *.o")

env.Help("""
LSST EUPS addons
""")
