#!/usr/bin/env python
# -*- python -*-
#
# various specializations for LSST (during DC2)
#
import sys, os, os.path, re, atexit, shutil
import eupsServer
import eupsDistrib

defaultPackageBase = "http://dev.lsstcorp.org/pkgs"

class DistribServer(eupsServer.ConfigurableDistribServer):
    """a class that encapsulates the communication with a package server.

    This class allows the mechanisms (e.g. the URLs) used to retrieve 
    information from a server to be specialized to that server. 

    This implementation captures the behavior of the LSST distribution server
    during DC3 (and beyond)
    """
    def _initConfig_(self):
        eupsServer.ConfigurableDistribServer._initConfig_(self)
        if not self.config.has_key('MANIFEST_URL'):
            self.config['MANIFEST_URL'] = \
                "%(base)s/manifests/%(product)s-%(version)s.manifest";
        if not self.config.has_key('MANIFEST_FLAVOR_URL'):
            self.config['MANIFEST_FLAVOR_URL'] = \
                "%(base)s/manifests/%(flavor)s/%(product)s-%(version)s.manifest";

        if not self.config.has_key('TABLE_URL'):
            self.config['TABLE_URL'] = \
                "%(base)s/%(product)s/%(version)s/%(product)s.table";
        if not self.config.has_key('EXTERNAL_TABLE_URL'):
            self.config['EXTERNAL_TABLE_URL'] = \
                "%(base)s/external/%(product)s/%(version)s/%(product)s.table";
        if not self.config.has_key('TABLE_FLAVOR_URL'):
            self.config['TABLE_FLAVOR_URL'] = \
                "%(base)s/%(product)s/%(version)s/%(flavor)s/%(product)s.table";
        if not self.config.has_key('EXTERNAL_TABLE_FLAVOR_URL'):
            self.config['EXTERNAL_TABLE_FLAVOR_URL'] = \
                "%(base)s/external/%(product)s/%(version)s/%(flavor)s/%(product)s.table";

        if not self.config.has_key('LIST_URL'):
            self.config['LIST_URL'] = "%(base)s/%(tag)s.list";
        if not self.config.has_key('LIST_FLAVOR_URL'):
            self.config['LIST_FLAVOR_URL'] = "%(base)s/%(flavor)s/%(tag)s.list";

        if not self.config.has_key('DIST_URL'):
            self.config['DIST_URL'] = "%(base)s/%(product)s/%(version)s/%(path)s";
        if not self.config.has_key('TARBALL_FLAVOR_URL'):
            self.config['TARBALL_FLAVOR_URL'] = "%(base)s/%(product)s/%(version)s/%(flavor)s/%(path)s";

        if not self.config.has_key('EXTERNAL_DIST_URL'):
            self.config['EXTERNAL_DIST_URL'] = "%(base)s/external/%(product)s/%(version)s/%(path)s";

        if not self.config.has_key('FILE_URL'):
            self.config['FILE_URL'] = \
                "%(base)s/%(product)s/%(version)s/%(path)s";
        if not self.config.has_key('PRODUCT_FILE_URL'):
            self.config['PRODUCT_FILE_URL'] = \
                "%(base)s/%(product)s/%(version)s/%(path)s";
        if not self.config.has_key('PRODUCT_FILE_FLAVOR_URL'):
            self.config['PRODUCT_FILE_FLAVOR_URL'] = \
                "%(base)s/%(product)s/%(version)s/%(flavor)s/%(path)s";

        if not self.config.has_key('MANIFEST_DIR_URL'):
            self.config['MANIFEST_DIR_URL'] = "%(base)s/manifests";
        if not self.config.has_key('MANIFEST_FILE_RE'):
            self.config['MANIFEST_FILE_RE'] = \
                r"^(?P<product>[^\-\s]+)(-(?P<version>\S+))?" + \
                r"(@(?P<flavor>[^\-\s]+))?.manifest$"

        if not self.config.has_key('LOCATION_FLAVOR_URL'):
            self.config['LOCATION_FLAVOR_URL'] = \
                "%(base)s/%(product)s/%(version)s/%(flavor)s/%(path)s";
        if not self.config.has_key('EXTERNAL_LOCATION_FLAVOR_URL'):
            self.config['EXTERNAL_LOCATION_FLAVOR_URL'] = \
                "%(base)s/external/%(product)s/%(version)s/%(flavor)s/%(path)s";

        if not self.config.has_key('DISTRIB_CLASS'):
            self.setConfigProperty('DISTRIB_CLASS',
                                   'pacman: lssteups.DistribPacman')

    def getFileForProduct(self, path, product, version, flavor, 
                          ftype=None, filename=None, noaction=False):
        """return a copy of a file with a given path on the server associated
        with a given product.

        @param path        the path on the remote server to the desired file
        @param product     the desired product name
        @param version     the desired version of the product
        @param flavor      the flavor of the target platform
        @param ftype       a type of file to assume; if not provided, the 
                              extension will be used to determine the type
        @param filename    the recommended name of the file to write to; the
                             actual name may be different (if, say, a local 
                             copy is already cached).  If None, a name will
                             be generated.
        @param noaction    if True, simulate the retrieval
        """

        # determine the extension to determine the type of file we are 
        # retrieving; this may affect the ultimate URL
        if ftype is None:
            ftype = os.path.splitext(path)[1]
            if ftype.startswith("."):  ftype = ftype[1:]

        # determine if we looking for an external product
        ftype = ftype.upper()
        prefix = "external/"
        if path.startswith(prefix):
            ftype = "EXTERNAL_" + ftype
            path = path[len(prefix):]

        return eupsServer.ConfigurableDistribServer.getFileForProduct(self,
                    path, product, version, flavor, ftype, filename, noaction)



class BuildDistrib(eupsDistrib.DefaultDistrib):
    """This class captures the mechanism used by LSST-NCSA to distribute 
    packages that build products from source.  
    """

    NAME = "lsstbuild"

    def __init__(self, Eups, distServ, flavor, tag="current", options=None,
                 verbosity=0, log=sys.stderr):
        eupsDistrib.Distrib.__init__(self, Eups, distServ, flavor, tag, options,
                                     verbosity, log)

        self.setupfile = self.getOption('setupsFile', "eupssetups.sh")

    # @staticmethod   # requires python 2.4
    def parseDistID(distID):
        """Return a valid package location if and only we recognize the 
        given distribution identifier

        This implementation always returns None
        """
        prefix = BuildDistrib.NAME + ":"
        distID = distID.strip()
        if distID.startswith(prefix):
            return distID[len(prefix):]

        return None

    parseDistID = staticmethod(parseDistID)  # should work as of python 2.2

    def installPackage(self, location, product, version, productRoot, 
                       installDir=None, setups=None, buildDir=None):
        """install a package, (typically) building from source.  The setups
        will be used to set the environment used to build the package.
        """
        if not buildDir:
            buildDir = self.getOption('buildDir', '_build_')
        if self.verbose > 0:
            print >> self.log, "Building in", buildDir

        # set the installation directory
        if installDir is None:
            installDir = os.path.join(product, version)

        installRoot = eupsDistrib.findInstallableRoot(self.Eups)
        if not installRoot:
            raise RuntimeError("Unable to find a stack I can write to among $EUPS_PATH")
        installDir = os.path.join(installRoot, self.Eups.flavor, installDir)

        if not os.path.isdir(buildDir):
            try:
                os.makedirs(buildDir)
            except:
                raise RuntimeError("%s: unable to create build directory" % buildDir)

        # fetch the package from the server;  by default, the URL will be 
        # of the form pkgroot/location.  With this convention, the location
        # will include the product, version, and flavor components explicitly.
        distFile = os.path.basename(location)
        self.distServer.getFileForProduct(location, product, version, 
                                          self.Eups.flavor, ftype="DIST",
                                          filename=os.path.join(buildDir, 
                                                                distFile))

        # catch the setup commands to a file in the build directory
        setupfile = os.path.join(buildDir, self.setupfile)
        if os.path.exists(setupfile):
            os.unlink(setupfile)
        if setups and len(setups) > 0:
            fd = open(setupfile, 'w')
            try:
                for setup in setups:
                    print >> fd, setup
            finally:
                fd.close()

        try:
            eupsServer.system("cd %s && lssteupsbuild.sh -D -b %s -r %s %s %s %s %s" % 
                              (buildDir, buildDir, self.distServer.base, 
                               distFile, installDir, product, version), 
                              self.Eups.noaction, self.verbose, self.log) 
        except OSError, e:
            raise RuntimeError("Failed to build and install " + location)

        if os.path.exists(installDir):
            self.setGroupPerms(installDir)

        try:
            eupsServer.system("cd %s && lssteupscleanup.sh -b %s" %
                              (os.path.dirname(buildDir), buildDir),
                              self.Eups.noaction, self.verbose, self.log)
        except OSError, e:
            raise RuntimeError("Failed to clean up build dir, " + buildDir)

    def _getInstallDirParts(self, product, version):
        path = None
        out = []
        if not self.Eups.noeups:
            pinfo = self.Eups.listProducts(product, version)
            if len(pinfo) > 0:
                pinfo = ping[0]
                path = pinfo[3]
                db = pinfo[2]

                if path.startswith(db) and db != path:
                    out.append(db)
                    path = path[len(db)+1:]

                    if path.startswith("external/"):
                        out.append("external")
                        path = path[len("external/"):]

                    out.append(path)
                else:
                    p = path.find(os.path.join(product,version))
                    if p > 0:
                        db = path[:p]
                        path = path[p:]

                        if db.endswith("external/"):
                            db = db[:-(len("external/"))]
                            out.append(db)
                            out.append("external")
                        else:
                            out.append(db)
                        if out[0][-1] == '/': out[0] = out[0][:-1]

                out.append(path)

        return out

    def _getDistIdParts(self, installParts):
        parts = installParts

        out = []
        if "external" in parts:
            out.append("external")

        installdir = apply(os.path.join, parts)
        buildfile = product+".bld"
        if not os.path.exists(installdir, "ups", buildfile):
            buildfile = "%s-%s.tar.gz" % (product, version)
        out.append(buildfile)

        return out;


    def getDistIdForPackage(self, product, version, flavor=None):
        """return the distribution ID that for a package distribution created
        by this Distrib class (via createPackage())
        @param product        the name of the product to create the package 
                                distribution for
        @param version        the name of the product version
        @param flavor         the flavor of the target platform; this may 
                                be ignored by the implentation.  None means
                                that a non-flavor-specific ID is preferred, 
                                if supported.
        """
        parts = self._getDistIdParts(self._getInstallDirParts())
        if parts is None or len(parts) == 0:
            return None

        return "lsstbuild:" + os.path.join(parts)

    def _getDistFile(self, serverDir, distidparts):
        return os.path.join([serverDir, distidparts[0:-1], product, 
                             version, distidparts[-1]])

    def packageCreated(self, serverDir, product, version, flavor=None):
        """return True if a distribution package for a given product has 
        apparently been deployed into the given server directory.  
        @param serverDir      a local directory representing the root of the 
                                  package distribution tree
        @param product        the name of the product to create the package 
                                distribution for
        @param version        the name of the product version
        @param flavor         the flavor of the target platform; this may 
                                be ignored by the implentation.  None means
                                that the status of a non-flavor-specific package
                                is of interest, if supported.
        """
        return os.path.exists(self._getDistFile(serverDir, 
                                                self._getDistIdParts(product, 
                                                                     version)))

    def createPackage(self, serverDir, product, version, flavor=None):
        """Write a package distribution into server directory tree and 
        return the distribution ID.  If a package is made up of several files,
        all of them (except for the manifest) should be deployed by this 
        function.  This includes the table file if it is not incorporated
        another file.  
        @param serverDir      a local directory representing the root of the 
                                  package distribution tree
        @param product        the name of the product to create the package 
                                distribution for
        @param version        the name of the product version
        @param flavor         the flavor of the target platform; this may 
                                be ignored by the implentation.  None means
                                that a non-flavor-specific package is preferred, 
                                if supported.
        """
        instparts = self._getInstallDirParts(product, version)
        installdir = os.path.join(instparts)
        distIdFile = self._getDistFile(serverDir, 
                                       self._getDistIdParts(instparts))

        distDir = os.path.dirname(distIdFile)

        # make the product directory
        if not os.path.exists(distDir):
            os.makedirs(distDir)

        # copy the table file over, if available
        tfile = os.path.join(installdir, "ups", product+".table")
        if os.path.exists(tfile):
            shutil.copyfile(tfile, os.join,dir(distDir, os.path.basename(tfile)))

        # copy over the src tar file, if available
        tfile = os.path.join(installdir, "ups", 
                             "%s-%s.tar.gz" % (product, version) )
        if os.path.exists(tfile):
            shutil.copyfile(tfile, os.join,dir(distDir, os.path.basename(tfile)))
        else:
            if self.verbose > 0:
                print >> self.log, "Note: Don't know how to package source", \
                    "code for", product, version

        # copy a build file over if it exists
        tfile = os.path.join(installdir, "ups", os.path.basename(distIdFile))
        if distIdFile.endswith(".bld") and os.path.exists(tfile):
            shutil.copy(tfile, distIdFile)

