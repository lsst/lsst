#! /usr/bin/env python
#
# before we get into the boiler plate scons stuff, we start with 
# some specialization
import os, re

lssthome = None
if not lssthome is None and os.environ.has_key('LSST_HOME'):
    lssthome = os.environ['LSST_HOME']
if not lssthome and os.environ.has_key('EUPS_PATH'):
    lssthome = os.environ['EUPS_PATH'].split(":", 1)[0].strip()

flts = { 'lsst_home': re.compile(r"#LSST_HOME ?.*$"), 
         'pkgsurl':   re.compile(r"#EUPS_PKGROOT ?.*$"), 
         'version':   re.compile(r"svn\(unbuilt\)")      }

def filter_files(target, source, env):
    """Filter script files, substituting in certain option values.
    A single or a list of sources can be provided; if a list is given the 
    target is assumed to be a directory.  If a list of targets is provided, 
    only the first is used; the others are ignored.  If only a single source
    is given and its name matches the base filename of the target, the target 
    is assumed to be the output file.
    """
    if target is None:  return None
    if source is None:  
        if not isinstance(target, list):
            target = [target]
        source = filter(os.path.basename, target)

    elif isinstance(target, list):
        target = target[0]

    if not isinstance(source, list):
        source = [source]

    vals = { 'lsst_home': env['lsst_home'] + "\n", 
             'pkgsurl':   env['pkgsurl'] + "\n",
             'version':   env['version'] + "\n"   }

    if isinstance(target, list):
        for i in xrange(len(target)):
            filter_file(target[i], source[i], flts, vals)
    else:
        for src in source:
            targ = os.path.basename(src)
            filter_file(os.path.join("..", "bin", targ), src, flts, vals)
    return None

def filter_file(target, source, flts, vals):
    try:
        sf = open(source, 'r')
        tf = open(target, 'w')

        for line in sf:
            for key in flts.keys():
                line = flts[key].sub(vals[key], line)
            tf.write(line)
    finally:
        sf.close()
        tf.close()

