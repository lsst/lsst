# -*- python -*-
from lsst.sconsUtils import env
from lsst.sconsUtils.utils import memberOf
from SCons.Script.SConscript import SConsEnvironment
import os, sys, re

flts = { }
vals = { }

def filter_files(target, source, env):
    """Filter script files, substituting in certain option values.
    """
    if len(target) > len(source):
        source.extend(map(os.path.basename, map(str, target[len(source):])))
    for i in xrange(len(target)):
        filter_file(target[i], source[i], flts, vals)
    if len(source) > len(target):
        print >> sys.stderr, "Don't know where to put extra sources:",  \
            " ".join(source[len(target):])
        return 1
    return 0

def filter_file(target, source, flts, vals):
    try:
        sf = tf = None
        sf = open(source.abspath, 'r')
        tf = open(target.abspath, 'w')

        for line in sf:
            for key in flts.keys():
                line = flts[key].sub(vals[key], line)
            tf.write(line)
    finally:
        if sf: sf.close()
        if tf: tf.close()
    os.chmod(str(target), os.stat(str(source))[0])

@memberOf(SConsEnvironment)
def FilterFilesInto(env, targetdir, source):
    """filter a bunch of files and put results into the target directory
    """
    targets = map(lambda x: os.path.join(targetdir, x), source);
    print targets
    print source
    env.Command(targets, source, action=filter_files)
    return targets

