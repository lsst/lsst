#
#
Import("env")
import os, sys, re

flts = { 'lsst_home': re.compile(r"#LSST_HOME ?.*$"), 
         'pkgsurl':   re.compile(r"#EUPS_PKGROOT ?.*$"), 
         'version':   re.compile(r"svn\(unbuilt\)")      }

def filter_files(target, source, env):
    """Filter script files, substituting in certain option values.
    """
    if len(target) > len(source):
        source.extend(map(os.path.basename, map(str, target[len(source):])))

    vals = { 'lsst_home': env['lsst_home'], 
             'pkgsurl':   env['pkgsurl'],
             'version':   env['version']            }

    # why do I have to do this?
    # print 'os.chdir("..")'
    os.chdir("..")

    for i in xrange(len(target)):
        filter_file(target[i], source[i], flts, vals)

    if len(source) > len(target):
        print >> sys.stderr, "Don't know where to put extra sources:",  \
            " ".join(source[len(target):])
        return 1

    return None

def filter_file(target, source, flts, vals):
    try:
        sf = tf = None
        sf = open(str(source), 'r')
        tf = open(str(target), 'w')

        for line in sf:
            for key in flts.keys():
                line = flts[key].sub(vals[key], line)
            tf.write(line)
    finally:
        if sf: sf.close()
        if tf: tf.close()

    os.chmod(str(target), os.stat(str(source))[0])

def FilterFilesInto(env, targetdir, source):
    """filter a bunch of files and put results into the target directory
    """
    if not isinstance(source, list):
        source = [source]
    targets = map(lambda x: os.path.join(targetdir, x), source);
    env.FilterFiles(targets, source, env)

filterfile = Builder(action=filter_files)
env.Append(BUILDERS = {'FilterFiles': filterfile})

Export("FilterFilesInto")

