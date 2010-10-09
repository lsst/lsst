#!/usr/bin/env python
#
# Author: Steven Bickerton
# Date: Sun 2010-10-03 15:58:47
# 
"""
%prog [options]
"""

import sys
import re
import glob
import optparse
import os

#############################################################
#
# Main body of code
#
#############################################################

sys.path.append(os.path.join(os.getenv("LSST_DIR"), "scripts"))
import noI

def main():

    noiData = os.path.join(os.getenv("LSST_DIR"), "tests", "noIData", "*.stderr")
    errorMsgFiles = glob.glob(noiData)

    for errorMsgFile in errorMsgFiles:
        fp = open(errorMsgFile, 'r')
        try:
            sout = sys.stdout
            sys.stdout = open("testNoI.log", 'w')
            noI.main(fp, False, 'b')
            sys.stdout.close()
            sys.stdout = sout
            print "Succeeded: ", errorMsgFile
        except Exception,e:
            sys.stdout.close()
            sys.stdout = sout
            print "Failed: ", errorMsgFile, e
            pass
        fp.close()

        

#############################################################
# end
#############################################################

if __name__ == '__main__':

    ########################################################################
    # command line arguments and options
    ########################################################################
    
    parser = optparse.OptionParser(usage=__doc__)
    opts, args = parser.parse_args()

    if len(args) != 0:
        parser.print_help()
        sys.exit(1)
    
    main()
