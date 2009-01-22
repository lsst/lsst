""" Configure eups for LSST """

import os, re, sys
import pdb
import eups
import eupsDistribBuilder
try:
    import lsst.svn
    noLsstSvn = 0
except ImportError:
    noLsstSvn = 1

#-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
#
# Allow "eups fetch" as an alias for "eups distrib install"
#
def cmdHook(cmd, argv):
    """Called by eups to allow users to customize behaviour by defining it in EUPS_STARTUP

    The arguments are the command (e.g. "admin" if you type "eups admin")
    and sys.argv, which you may modify;  cmd == argv[1] if len(argv) > 1 else None
    """

    if cmd == "eups fetch":
        argv[1:2] = ["distrib", "install"]

#-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
#
# A callback function called just before version strings are sorted
#
def versionHook(v1, v2, compar):
    """Called with the pair of versions that are to be sorted; compar is the usual version comparison
    function for your possible convenience.

    Throw ValueError if the versions can't be sorted
    """

    if v1 and v2:
        numeric1 = re.search(r"^\d", v1) != None
        numeric2 = re.search(r"^\d", v2) != None

        if numeric1 != numeric2:        # numbers may only be compared to numbers (e.g. 3.1 > 2.9)
            raise ValueError
        elif not numeric1:
            prefix = os.path.commonprefix([v1, v2])
            if not prefix:              # require a common prefix for versions that can be sorted
                raise ValueError

    return compar(v1, v2)

#-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

def rewriteTicketVersion(line):
    """A callback that knows about the LSST concention that a tagname such as
       ticket_374
   means the top of ticket 374, and
      ticket_374+svn6021
   means revision 6021 on ticket 374"""

    global noLsstSvn
    if noLsstSvn:
        if noLsstSvn > 0:
            print >> sys.stderr, "Unable to import lsst.svn --- maybe scons isn't setup?"
            noLsstSvn = -1
        return line
    #
    # Look for a tagname that we recognise as having special significance
    #
    try:
        mat = re.search(r"^\s*svn\s+(?:co|checkout)\s+([^\s]+)", line)
        if mat:
            URL = mat.group(1)

            if re.search(r"^([^\s]+)/trunk$", URL): # already processed
                return line

            try:
                try:
                    type, which, revision = lsst.svn.parseVersionName(URL)
                except ValueError:      # old version doesn't return pm
                    type, which, revision, pm = lsst.svn.parseVersionName(URL)

                rewrite = None
                if type == "branch":
                    rewrite = "/branches/%s" % which
                elif type == "ticket":
                    rewrite = "/tickets/%s" % which
                elif type == "tag":
                    return line

                if rewrite is None:
                    raise RuntimeError

                if revision:
                    rewrite += " -r %s" % revision

                line = re.sub(r"/tags/([^/\s]+)", rewrite, line)
            except RuntimeError, e:
                msg = "rewriteTicketVersion: invalid version specification \"%s\" in \"%s\"" % (URL, line[:-1])
                if e.__str__():
                    msg += ": %s" % e
                raise RuntimeError, msg

    except AttributeError, e:
        print >> sys.stderr, "Your version of sconsUtils is too old to support parsing version names"
    
    return line

if __name__ == "__main__":

    #-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
    #
    # Define a distribution type "beta"
    #
    eups.defineValidTag("beta", ["stable"])

    if False:
        eups.defineValidSetupTypes("build") # this one's defined already
    #
    # Rewrite ticket names into proper svn urls
    #
    eupsDistribBuilder.buildfilePatchCallbacks.add(rewriteTicketVersion)

    try:
        eups.commandCallbacks.add(cmdHook)
        eups.versionCallback.set(versionHook)
    except AttributeError, e:
        mat = re.search(r"'([^']+)'$", e.__str__())
        print >> sys.stderr, "Your version of eups doesn't understand \"%s\"; continuing" % mat.group(1)
    
#-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import eupsServer

class ExtendibleConfigurableDistribServer(eupsServer.ConfigurableDistribServer):
    """A version of ConfigurableDistribServer that we could augment
    """

    def __init__(self, *args):
        super(eupsServer.ConfigurableDistribServer, self).__init__(*args)
