# -*- python -*-
#
# Setup our environment
#
import glob, os.path, re, os
import lsst.SConsUtils as scons

# before we get into the boiler plate scons stuff, we start with 
# some specialization
lssthome = None
if not lssthome is None and os.environ.has_key('LSST_HOME'):
    lssthome = os.environ['LSST_HOME']
if not lssthome and os.environ.has_key('EUPS_PATH'):
    lssthome = os.environ['EUPS_PATH'].split(":", 1)[0].strip()

# okay start the standard stuff        

opts = scons.LsstOptions()
opts.AddOptions(('pkgsurl', 'the base url for the software server',
                 'http://dev.lsstcorp.org/pkgs'),
                ('lsst_home', 'the root directory for the LSST software stack',
                 lssthome))

env = scons.makeEnv("lsst", r"$HeadURL$", options=opts)

env.Command('bin', '', [Mkdir('bin')])
env.Command('etc', '', [Mkdir('etc')])
env.Clean('bin', 'bin')

for d in Split("scripts"):
    SConscript("%s/SConscript" % d)

env.Command("doc/README.txt", "README.txt", [Copy('$TARGET', '$SOURCE')])

Alias("loadLSST", env.Install(env['lsst_home'], 
                              Split("etc/loadLSST.sh etc/loadLSST.csh")))
Alias("install", env.Install(env['prefix'], "bin"))
Alias("install", env.Install(env['prefix'], "doc"))
Alias("install", env.Install(env['prefix'], "etc"))
Alias("install", env.InstallEups(env['prefix'] + "/ups", glob.glob("ups/*.table")))

env.Declare()
env.Help("""
deploy/lsst:  LSST Build Environment Tools

This provides tools for building LSST products and installing them into
the software distribution server.  This package relies on the eups capabilities.
""")
