#! /bin/env python
#
import sys
import os
import os.path
import cStringIO
import re
import errno
from copy import copy
import cgitb; cgitb.enable()

defstackver = "dmstst"
stackrootdir = "/lsst/softstack"
manifestsdir = "manifests"

defaultManifestHeader = \
"""EUPS distribution manifest for %s (%s). Version 1.0
#
"""

defaultColumnNames = \
"pkg flavor version tablefile installation_directory installID".split()

class Manifest:
    """an in-memory representation of a package manifest."""

    def __init__(self, name, version, flavor="generic"):
        """create a manifest for a given package

        @param name     the name of the package this manifest is for
        @param version  the version of the package
        @param flavor   the name of the platform type supported by this
                          installation of the package
        """
        self.recs = {}
        self.keys = []
        self.name = name
        self.vers = version
        self.flav = flavor
        self.hdr = defaultManifestHeader
        self.colnames = copy(defaultColumnNames)
        self.colnames[0] = "# " + self.colnames[0]
        self.commcount = 0

    def getNameVerFlav(self):
        """return the package name, version, and flavor as a 3-tuple"""
        return (self.name, self.vers, self.flav)

    def setNameVerFlav(self, name, version, flavor="generic"):
        """set the package name, version, and flavor for this manifest"""
        self.name = name
        self.vers = version 
        self.flav = flavor

    def addComment(self, comment):
        """append a comment to the manifest"""
        self.commcount += 1
        key = '#'+str(self.commcount)
        self.keys.append(key)
        self.recs[key] = [ '' ] * len(self.colnames)
        self.recs[key][-1] = comment

    def addRecord(self, pkgname, flavor, version,
                  tablefile, installdir, installid):
        """append a record to the manifest list.  This method does not
        prevent duplicate records.

        @param pkgname    the name of the package
        @param flavor     the name of the platform type supported by this
                            installation of the package
        @param version    the version of the package
        @param tablefile  the name of the EUPS table file for this package
        @param installdir the directory (relative to $LSST_HOME) where
                             this package should be installed by default.
        @param installid  a complete handle for the deployment bundle.
        """
        key = ":".join([pkgname, flavor, version])
        if not self.recs.has_key(key):
            self.keys.append(key)
            self.recs[key] = [pkgname, flavor, version,
                              tablefile, installdir, installid]

    def addLSSTRecord(self, pkgname, version, pkgpath=None, flavor="generic",
                      insttype="lsstbuild", instfile=None,
                      tablefile=None, installdir=None, installid=None):
        """append a standard build record for an LSST package.

        @param pkgname    the name of the package
        @param version    the version of the package
        @param pkgpath    if non-None, a path to be prepended to the standard
                             pkgname/version install directory (default:
                             None)
        @param flavor     the name of the platform type supported by this
                            installation of the package (default: "generic")
        @param insttype   the type of install ID to assume when creating a 
                            default installID
        @param instfile   the install file to use when creating a default 
                            installID
        @param tablefile  the name of the EUPS table file for this package
        @param installdir the directory (relative to $LSST_PKGS) where
                             this package should be installed by default.
        @param installid  a complete handle for the deployment bundle.
        """
        if pkgpath is None:
            pkgpath = ''
        if not flavor:
            flavor = "generic"

        if not insttype:  
            if flavor == "generic":
                insttype = "lsstbuild"
            else: 
                insttype = ''
        if not instfile:  
            if insttype == "build":
                instfile = "%s.build" % pkgname
            else:
                instfile = "%s-%s.tar.gz" % (pkgname, version)
            
        if not tablefile:
            tablefile = os.path.join(pkgpath, pkgname+".table")
        if not installdir:
            installdir = os.path.join(pkgpath, pkgname, version)
        if not installid:
            if insttype:
                installid = "%s:" % insttype
            else:
                installid = ''
            installid += os.path.join(pkgpath,instfile)

        self.addRecord(pkgname, flavor, version, tablefile, installdir,
                       installid)
                       
    def addExtRecord(self, pkgname, version, pkgpath="external", 
                     flavor="generic", insttype="lsstbuild"):
        """append a standard build record for an LSST package

        @param pkgname    the name of the package
        @param version    the version of the package
        @param pkgpath    if non-None, a path to be prepended to the standard
                             pkgname/version install directory (default:
                             "external")
        @param flavor     the name of the platform type supported by this
                            installation of the package (default: "generic")
        @param insttype   the type of install ID to assume when creating a 
                            default installID
        """
        self.addLSSTRecord(pkgname, version, pkgpath, flavor, insttype)

    def addSelfRecord(self, pkgpath=None, flavor="generic",insttype="lsstbuild"):
        """append a standard build record for the package that this
        manifest is for

        @param pkgpath    if non-None, a path to be prepended to the standard
                             pkgname/version install directory (default:
                             None)
        @param flavor     the name of the platform type supported by this
                            installation of the package (default: "generic")
        @param insttype   the type of install ID to assume when creating a 
                            default installID
        """
        self.addLSSTRecord(self.name, self.vers, pkgpath, flavor, insttype)

    def hasRecord(self, pkgname, flavor, version):
        """return true if this manifest has a record matching the
        package name, flavor, and version

        @param pkgname    the name of the package
        @param flavor     the name of the platform type supported by this
                            installation of the package
        @param version    the version of the package
        """
        return self.recs.has_key(":".join([pkgname, flavor, version]))

    def recordToString(self, pkgname, flavor, version):
        """return the requested record in manifest format.
        @param pkgname    the name of the package
        @param flavor     the name of the platform type supported by this
                            installation of the package
        @param version    the version of the package
        """
        if (not self.hasRecord(pkgname, flavor, version)):
            raise RuntimeError("record not found in manifest")
        return " ".join(self.recs(":".join([pkgname, flavor, version])))

    def __repr__(self):
        """return all lines of the manifest in proper manifest format"""
        out = cStringIO.StringIO()
        self.printRecord(out)
        return out.getvalue()

    def str(self):
        """return all lines of the manifest in proper manifest format"""
        return str(self)

    def printRecord(self, strm):
        """print the lines of the manifest to a give output stream.

        @param strm  the output stream to write the records to
        """
        collen = self._collen()
        fmt = "%%-%ds %%-%ds %%-%ds %%-%ds %%-%ds %%s\n" % tuple(collen[:-1])
        
        strm.write(self.hdr % (self.name, self.vers))
        strm.write((fmt % tuple(self.colnames)))
        strm.write("#" + " ".join(map(lambda x: '-' * x, collen))[1:79])
        strm.write("\n")

        for key in self.keys:
            if key.startswith('#'):
                strm.write("# %s\n" % self.recs[key][-1])
            else:
                strm.write(fmt % tuple(self.recs[key]))
            
    def _collen(self):
        x = self.recs.values()
        x.append(self.colnames)
        return map(lambda y: max(map(lambda x: len(x[y]), x)),
                   xrange(0,len(self.colnames)))
    
defaultCurrentFile = "current.list"

defaultManfileName = "manifest.list"

class Loader:
    """a class that can load a Manifest from directive files"""

    def __init__(self, basedir=".", strict=True):
        """create a loader

        @param basedir   the base directory under which manifest directive
                            files can be found
        """
        self.strict = strict
        self.openfiles = []
        self.visited = []
        self.basedir = basedir
        self.pkgPath = {}
        self.currentfile = defaultCurrentFile
        self.manfile = defaultManfileName

    def parseLine(self, line):
        out = { "op": '', 'pkg': '', 'ver': '', 'flavor': '', 'pkgpath': '', 
                'tablefile': '', 'installDir': '', 'installID': '',
                'installType': '', 'installFile': ''}
        line = line.strip()

        if len(line) == 0 or line.startswith('#'):
            return out

        if line.startswith('>'):
            line = line[1:].strip()
            words = line.split()
            out['op'] = words.pop(0)

            for word in words:
                (name, val) = word.split('=', 1)
                if name != 'op':
                    out[name] = val

        else:
            out['op'] = 'add'
            words = line.split()
            if len(words) > 0: out['pkg']        = words[0]
            if len(words) > 1: out['flavor']     = words[1]
            if len(words) > 2: out['ver']        = words[2]
            if len(words) > 3: out['tablefile']  = words[3]
            if len(words) > 4: out['installDir'] = words[4]
            if len(words) > 5: out['installID']  = words[5]

        return out

    def updateManifest(self, manifest, rec, pflavor=None):

        if not rec.has_key('op'):
            raise ValueError("data missing op directive")
        if rec['op'] == '':
            return 

        if not rec['flavor']:
            if pflavor:  rec['flavor'] = pflavor
            else:  rec['flavor'] = "generic"

        if rec['op'] == 'id':
            if rec['pkg'] and rec['ver']:
                manifest.setNameVerFlavor(rec['pkg'], rec['ver'], rec['flavor'])
        
        elif rec['op'] == 'add' or rec['op'] == 'merge':
            if not rec['pkg']:
                self.badFileSyntax("bad syntax: add needs at " +
                                   "least a pkg parameter: " +
                                   str(rec), manifest)
            if not rec['ver'] or not rec['pkgpath']:
                lu = self.lookupCurrent(rec['pkg'])
                if not rec['ver']:
                    if len(lu) == 0:
                        self.badFileSyntax("lack of current version " +
                                           "for " + rec['pkg'] + ": " +
                                           str(rec), manifest)
                        return
                    rec['ver'] = lu[0]

                if not rec['pkgpath'] and len(lu) > 1 and lu[1]:
                    rec['pkgpath'] = lu[1]

            if rec['op'] == 'add':
                manifest.addLSSTRecord(rec['pkg'], rec['ver'], rec['pkgpath'],
                                       rec['flavor'], rec['installType'], 
                                       rec['installFile'], rec['tablefile'], 
                                       rec['installDir'], rec['installID'])

            else:
                # merge
                (file, pp) = self.getFileFor(rec['pkg'],rec['ver'],rec['flavor'])
                                             
                if not os.path.exists(file):
                    (file, pp) = self.getFileFor(rec['pkg'], rec['ver'])
                    rec['flavor'] = "generic"
                if pp is None: pp = ''
                if not rec['installDir']: 
                    rec['installDir'] = os.path.join(pp, rec['pkg'], rec['ver'])

                self.loadFromFile(manifest, file, pp, rec['pkg'], rec['ver'], 
                                  rec['flavor'], pflavor)

        else:
            manifest.addComment(" unrecognized directive: %s" % rec['op'])

        
        

    def loadFromFile(self, manifest, file, pkgpath=None, 
                     pkgname=None, version=None, flavor=None, pflavor=None):
        """load records into a manifest according to directives in the
        given file.

        @param manifest   the Manifest object to add to
        @param file       a manifest directive file
        @param pkgpath    the path to this package; if None (default),
                            no extra path will be assumed
        @param pkgname    the name of the package associate with this
                            manifest file; if None (default), the name
                            associated with the manifest will be assumed
        @param version    the version of the package associate with this
                            manifest file; if None (default), the version
                            associated with the manifest will be assumed
        @param flavor     the flavor associate with this package; if None,
                            (default), the flavor associated with the
                            manifest will be assumed.
        @param pflavor    the preferred flavor for dependent packages; if None,
                            (default), the preferred flavor with be that
                            assumed for the given file
        """
        if file in self.openfiles:
            raise ValueError, "Circular inclusion detected!"
        if file in self.visited:
            # silently skip this file since we've already processed it
            return

        if pkgname is None:
            if version is None:  version = manifest.vers
            if flavor is None: flavor = manifest.flav
            pkgname = manifest.name
        if version is None:
            raise ValueError, "can't set a default version for " + pkgname
        if flavor is None:
            flavor = "generic"
        if pflavor is None:
            pflavor = flavor
            
        try:
            mf = open(file, "r")
            self.openfiles.append(file)
        except IOError, (enum, emsg):
            if (self.strict or enum != 2):
                raise IOError, (enum, "%s: %s" % (file, emsg))
            else:
                if pkgpath is None:  pkgpath = ''
                if len(pkgpath) > 0: pkgpath = "(%s)" % pkgpath
                manifest.addComment("No manifest found for %s %s %s: %s" %
                                    (pkgname, version, pkgpath, file))
                self.visited.append(file)
                return

        try:
            for line in mf:
                directive = self.parseLine(line)

                if directive['op'] == 'self':
                    directive['pkg'] = pkgname
                    directive['ver'] = version
                    directive['flavor'] = flavor
                    directive['op'] = 'add'
                    
                if directive['op'] != 'id':
                    self.updateManifest(manifest, directive, pflavor)

        finally:
            mf.close()
            self.openfiles.pop(-1)
            self.visited.append(file)

    def load(self, manifest):
        """load records into a manifest.

        Loading will start by opening the directive file corresponding to
        the name, version, and flavor associated with the manifest.  

        @param manifest   the Manifest object to add to
        """
        (pkgname, version, flavor) = manifest.getNameVerFlav()
        pflavor = flavor

        (mfilename, pkgpath) = self.getFileFor(pkgname, version, flavor)
        found = os.path.exists(mfilename); 
        if not found and flavor != '' and flavor != 'generic':
            (mfilename, pkgpath) = self.getFileFor(pkgname, version)
            flavor = manifest.flav = 'generic'
            found = os.path.exists(mfilename);
        if not found:
            raise IOError, (errno.ENOENT,
                            "%s: top-level file not found" % mfilename,
                            mfilename)
        
        self.loadFromFile(manifest, mfilename, pkgpath,
                          pkgname, version, flavor, pflavor)


    def lookupCurrent(self, pkgname):
        """look up the current version of and relative path to a given
        package. 

        This specifically finds the path to the package name directory
        (containing the various version directories) relative to the
        base directory.
        @param pkgname   the name of the package to look up
        @return an array [] where the first element is the version,
                    the second is the relative path (which may be an empty
                    string), and the third (which may be empty) is the
                    package directory (overriding the default pkg/ver
                    pattern)
        """
        if self.pkgPath.has_key(pkgname):
            return self.pkgPath[pkgname]

        cf = open(os.path.join(self.basedir, self.currentfile))
        try: 
            parts = []
            for line in cf:
                line = line.strip()
                if line.startswith('#'):
                    continue

                parts = re.findall(r"\S+", line)
                if len(parts) > 0 and parts[0] == pkgname:
                    break
        finally:
            cf.close()

        # if we didn't find it in the current file, try to guess some values
        if parts[0] != pkgname:
            parts = [pkgname, 'generic', '']
            path = os.path.join(self.basedir,manifestsdir,pkgname+'.manifest')
            if not os.path.exists(path):
                parts = []

        out = []
        if len(parts) < 3 or parts[0] != pkgname:
            return out

        out.append(parts[2])

        out.append('')
        if len(parts) > 3:
            out[1] = parts[3]

        out.append('')
        if len(parts) > 4:
            out[2] = parts[4]

        self.pkgPath[pkgname] = out
        return out

    def getFileFor(self, pkgname, version=None, flavor="generic"):
        """determine the path to the manifest directive file for a
        specified package along with the extra path to the package

        @return  a 2-element tuple containing the file path (or None
                   if that path cannot be determined because version
                   is None and pkgname is not in the current file)
                   and the extra package path (or None if there is
                   none).
        """
        lu = self.lookupCurrent(pkgname)
        if version is None and len(lu) > 0:
            version = lu[0]

        basename = pkgname
        if version:
            basename += "-%s" % version
        basename += ".manifest"

        if flavor is None or flavor == 'generic':
            flavor = ''
        
        file = os.path.join(self.basedir,manifestsdir,flavor,basename)

        pkgpath = None
        if len(lu) > 1 and len(lu[1]) > 0:
            pkgpath = lu[1]            

        return (file, pkgpath)

    def badFileSyntax(self, msg, manifest):
        if self.strict:
            raise RuntimeError, msg
        else:
            manifest.addComment(msg)

    def makeManifestFor(self, pkg, version, flavor='generic'):
        out = Manifest(pkg, version, flavor)
        self.load(out)
        return out

def EUPSManifestService():
    path = os.environ["PATH_INFO"]
    if (path is None or len(path) == 0):
        raise ValueError, "no manifest file provided"

    stackver = defstackver
    p = path.find("/"+manifestsdir+"/")
    if p >= 0:
        stackver = path[:p]
        while len(stackver) > 0 and stackver[0] == '/':
            stackver = stackver[1:]
        path = path[p+len(manifestsdir)+1:]
    pkgsdir = os.path.join(stackrootdir, stackver)

#    sys.stderr.write("path: %s" % path)

    ldr = Loader(pkgsdir, False)
    ldr.strict = False

    if path.endswith(".manifest"):
        path = path[:-len(".manifest")]
    if path.startswith("/"):
        path = path[1:]

    dir = None
    if path.find("/") > 0:
#        (dir, path) = path.rsplit("/", 1)
        dir = os.path.dirname(path)
        path = os.path.basename(path)

    sys.stderr.write("path: %s" % path)
    if path.find("-") >= 0:
        (pkg, version) = path.split("-", 1)
    else:
        pkg = path
        lu = ldr.lookupCurrent(pkg)
        if lu is None or len(lu) == 0:
            raise ValueError, pkg + ": current version for package not found: "
        version = lu[0]

    if len(pkg) == 0 or len(version) == 0:
        raise ValueError, "bad manifest file name: " + os.environ["PATH_INFO"]

    flavor = dir
    if flavor is None or len(flavor) == 0:  flavor = "generic"
    out = Manifest(pkg, version, flavor)
    try:
        ldr.load(out)

        sys.stdout.write("Content-type: text/plain\n\n")
        out.printRecord(sys.stdout)
        sys.stdout.close()
        
    except IOError, e:
        if e.errno == errno.ENOENT:
            print >> sys.stderr, "Missing file,", str(e)
            # this is a hack to return a 404 response
            sys.stdout.write("Location: /%s%s\n\n" %
                             (manifestsdir, os.environ["PATH_INFO"]))
        else:
            raise e

def test():
    test = Manifest("fw", "0.3")
    ldr = Loader(".")
    ldr.strict = False
    ldr.load(test)
    test.printRecord(sys.stdout)
    
if __name__ == "__main__":
    EUPSManifestService()
    
