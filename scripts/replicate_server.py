#! /usr/bin/env python
#
import sys, os
from optparse import OptionParser

prog = ""
progannounce = ""

def main():
    global prog, progannounce
    prog = os.path.basename(sys.argv[0])
    progannounce = "%s: " %  prog

    usage = """Usage:
    %s from_stackdir to_stackdir
    """ % prog
    cli = OptionParser(prog=prog, usage=usage)

    cli.add_option("-v", "--verbose", action="count", dest="verbose",
                   default=0,
                   help="Be chattier (repeat for even more chat)")
    cli.add_option("-n", "--new", action="store_true", dest="new", default=False,
                   help="Insist that the output directory previously not exist")

    (opts, args) = cli.parse_args()

    if len(args) < 1:
        raise RuntimeError("No source and destination directories given")
    if len(args) < 2:
        raise RuntimeError("No destination directory given")

    fromstack = args[0]
    tostack = args[1]

    if not os.path.isdir(fromstack):
        raise RuntimeError("%s: directory not found" % fromstack)
    if not os.access(fromstack, (os.R_OK|os.X_OK)):
        raise RuntimeError("%s: directory not readable/descendable" % fromstack)
        
    if opts.new:
        if os.path.exists(tostack):
            raise RuntimeError("%s: destination directory already exists")
    elif not os.path.isdir(tostack) or not os.access(tostack, (os.R_OK|os.X_OK)):
        raise RuntimeError("%s: destination not a directory with read/descend permission" % tostack)

    replicate(fromstack, tostack)

def replicate(fromstack, tostack):
    """efficiently replicate a directory tree.  Files in the source tree are
    replicated into the destination tree as a hard link.  This function will 
    only work if the source and destinations directories are on the same 
    partition.
    """

    fromstack = os.path.abspath(fromstack)
    tostack = os.path.abspath(tostack)
    toparent = tostack
    if not os.path.exists(toparent):
        toparent = os.path.dirname(toparent)
    if not os.path.exists(toparent) or \
            not os.access(toparent, (os.R_OK|os.X_OK)):
        raise RuntimeError("%s: destination's parent directory does not exist with read/descend permission" % toparent)

    if partition(fromstack) != partition(toparent):
        raise RuntimeError("source and destination directories not on the same partition (use 'cp -r')")

    if not os.path.exists(tostack):
        os.mkdir(tostack)

    origdir = os.getcwd()
    os.chdir(tostack)

    os.path.walk(fromstack, replicateContents, [fromstack, tostack])

    os.chdir(origdir)

def replicateContents(stacks, dirname, names):
    skip = [".svn"]
    fromstack = stacks[0].rstrip('/ ')
    tostack = stacks[1].rstrip('/ ')
    if not dirname.startswith(fromstack):
        raise RuntimeError("replicateContents: bad stacks argument passed")
    reldir = dirname[len(fromstack)+1:]

    remove = filter(lambda x: x in skip, names)
    for name in remove:
        while name in names:
            del names[names.index(name)]

    for name in names:
        fromfile = os.path.join(dirname, name)
        tofile = os.path.join(tostack, reldir, name)
        if os.path.lexists(tofile):
            continue

        if os.path.islink(fromfile):
            linkfile = os.path.realpath(fromfile)
            if linkfile.startswith(fromstack):
                linkfile = os.path.join(tostack,linkfile[len(fromstack)+1:])
            os.symlink(linkfile, tofile)
        elif os.path.isdir(fromfile):
            os.mkdir(tofile)
        else:
            os.link(fromfile, tofile)


def partition(file):
    """return the root directory for the current file's disk partiition"""

    pd = os.popen("df -P %s" % file)
    out = None
    for line in pd:
        if line.find("Mounted on") >= 0:
            continue
        out = line.split()[-1]
        break

    if out is None:
        raise RuntimeError("%s: no partition found" % file)
    pd.close()
    return out
    
        
if __name__ == "__main__":

    sys.exit(main())
