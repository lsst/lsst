# -*- python -*-
from lsst.sconsUtils import scripts, env, targets

# okay start the standard stuff

scripts.BasicSConstruct.initialize("lsst", versionModuleName=None)

targets["doc"].extend(env.Command("doc/README.md", "README.md", [Copy('$TARGET', '$SOURCE')]))

env.Help("""
deploy/lsst:  LSST Build Environment Tools

This provides tools for building LSST products and installing them into
the software distribution server.  This package relies on the eups capabilities.
""")

scripts.BasicSConstruct.finish(subDirList="doc ups".split(),
                               defaultTargets=["doc", "tests"])
