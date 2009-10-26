#!/usr/bin/env python
#
# Original filename: test-style.py
#
# Author: Steve Bickerton
# Email: bick@astro.princeton.edu
# Date: Tue 2009-10-20 14:36:37
# 
# Summary:
#
# This program is intended to run style.py on a series of 'test files'
#  which contain known violations.
# I takes no command line arguments or options.
#
# Usage: test-style.py
# 
"""
%prog [options]
"""

import sys
import re
import optparse
import os
import datetime
import glob
import commands

def red(s):   return "\033[31;1m " + s + " \033[0m"
def green(s): return "\033[32;1m " + s + " \033[0m"

#############################################################
#
# Main body of code
#
#############################################################

def main():

    ########################################################################
    # command line arguments and options
    ########################################################################
    
    parser = optparse.OptionParser(usage = __doc__)
    #parser.add_option("-a", "--aa", dest = "aa", type = float,
    #                  default = 1.0, help="default = %default")
    
    opts, args = parser.parse_args()

    styleDataDir = os.getenv("LSST_DIR") + "/tests/styleData"

    if (len(args) > 0):
        testFiles = args
        missingFiles = []
        for testFile in testFiles:
            if not os.path.exists(testFile):
                missingFiles.append(testFile)
        if missingFiles:
            print "The following files could not be found:"
            print "  " + "\n  ".join(missingFiles)
            sys.exit(1)
    else:
        testFiles = glob.glob(styleDataDir + "/test*")
        #testFiles = glob.glob(styleDataDir + "/test3-1.cc")
        testFiles.sort()

        
    for testFile in testFiles:

        #######################################################
        # get the failure lines
        # encoded in each test*.{cc,h} file as "// L1,L2,L3"
        fp = open(testFile, 'r')
        lines = fp.readlines()
        fp.close()

        expectedFailures = {}
        expFailExplanations = {}
        for line in lines:
            m = re.search("\/\/\s+(\d\-\d+\w?)\s+((?:\d+,?)+)\s+(.*)\s*$", line)
            if m:
                code = m.group(1)
                expectedFailures[code] = m.group(2).split(",")
                expFailExplanations[code] = m.group(3)
                
        #######################################################
        # run style.py on the test file and collect failures
        cmd = "style.py " + testFile
        status, output = commands.getstatusoutput(cmd)
        failureList = output.split("\n")
        
        detectedFailures = {}
        detFailExplanations = {}
        for failure in failureList:
            m = re.search("(\d+):\s+\t([^\t]+)\s+\tLsstDm-(\d-\d+\w?)-\d\s*$", failure)
            if m:
                lineNo = m.group(1)
                detFailExplanations[code] = m.group(2)
                code   = m.group(3)
                if (detectedFailures.has_key(code)):
                    detectedFailures[code].append(lineNo)
                else:
                    detectedFailures[code] = [lineNo]


        #######################################################
        # make sure the output is consistent with expected

        falsePositives = []
        for code in detectedFailures:
            for lineNo in detectedFailures[code]:
                if (not expectedFailures.has_key(code) or not lineNo in expectedFailures[code]):
                    falsePositives.append([lineNo, code, detFailExplanations[code]])
                
        falseNegatives = []
        for code in expectedFailures:
            for lineNo in expectedFailures[code]:
                if (not detectedFailures.has_key(code) or not lineNo in detectedFailures[code]):
                    falseNegatives.append([lineNo, code, expFailExplanations[code]])

        #print "detected: ", detectedFailures["3-1"]
        #print "expected: ", expectedFailures["3-1"]
                    
        #######################################################
        # output
        print "%-24s " % (os.path.basename(testFile)),
        if (falseNegatives or falsePositives):
            print red("Fail")
            if (falseNegatives):
                print "    False negatives:"
                for falseNegative in falseNegatives:
                    print "      %-4d %6s %s" % (int(falseNegative[0]), falseNegative[1], falseNegative[2])
            if (falsePositives):
                print "    False positives:"
                for falsePositive in falsePositives:
                    print "      %-4d %6s %s" % (int(falsePositive[0]), falsePositive[1], falsePositive[2])
        else:
            print green("Pass")

#############################################################
# end
#############################################################

if __name__ == '__main__':
    main()
