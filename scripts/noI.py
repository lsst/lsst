#!/usr/bin/env python
#
# Original filename: noI.py
#
# Author: Steve Bickerton
# Email: 
# Date: Mon 2009-12-21 09:41:24
# 
# Summary: 
# 
"""
%prog [options]
"""

import sys
import re
import optparse
import os


##########################
# A function which prints the terminal code to set color/style of text
##########################
def color(col):
    c = {"red":31, "green":32, "yellow":33, "blue":34, "magenta":35, "cyan":36, "reset":0}
    s = {"bold":1}

    base = "\033["
    out = 0 # default to 'reset'
    if col in c:
        out = c[col]
    elif col in s:
        out = s[col]
    return base + str(out) + "m"

############################
# A function which searches for a pattern and colors/styles a captured portion of it.
# ##########################
def regexColorReplace(regex, clrs, line):
    m = re.search(regex, line)
    out = line
    if (m):
        pattern = m.group(1)
        colorPattern = ""
        # note clrs is a list, this way colors and styles can be included together (ie. ["red", "bold"]
        for clr in clrs:
            colorPattern += color(clr)
        colorPattern += pattern + color("reset")
        # if it's just digits, it must be line numbers
        # it'll match all digits, so we'll put the colon (g++ output) in the match expression
        if re.search("^\d+$", pattern):
            out = re.sub(":"+pattern, ":"+colorPattern, line)
        else:
            out = re.sub(pattern, colorPattern, line)
            
    return out


#############################################################
#
# Main body of code
#
#############################################################
def main(log, retryscript):

    if log:
        fp_log = open("noI.log", 'w')
        
    ####################################
    # loop over stdin lines
    ####################################

    # have the retry script echo a message if there are no errors
    no_op_mesg = "No errors were found in the most recent scons compile."
    s = "#!/usr/bin/env bash\n"
    s += "echo \"" + no_op_mesg + "\"\n"
    fp = open(retryscript, 'w')
    fp.write(s)
    fp.close()
    
    i = 0
    compile_lines = {}  # store the compile statement by path of the .cc file
    srcFileLookup = {}  # need to lookup the .cc file to build if the error is in a .h file
    prev_line = ""
    s = ""
    already_compiling = {}  # avoid putting the same build line in the rebuild script multiple times
    raw_lines = []
    iLine = 0
    while(True):
        line = sys.stdin.readline()
        
        raw_line = line
        if log:
            fp_log.write(raw_line)

        raw_lines.append(raw_line)
        iLine += 1
        
        if not line:
            break

        # stash the line if it's a compile statement (starts with 'g++')
        # POSSIBLE BUG if another compiler is used.
        # - do this before we strip off the -I -L and other options.
        if re.search("^g\+\+", line):
            srcFile = (line.split())[-1]
            compile_lines[srcFile] = line.strip()
            
        # trim the g++ options (-I -L etc.)
        line = re.sub("\s+-([DILl]|Wl,)\S+", "", line)

        ### warnings ###
        line = regexColorReplace("([Ww]arning):", ["yellow"], line)

        
        ### errors ###

        # write a script to re-execute the compile statement which failed
        # ... no sense redoing the whole configure/build
        m = re.search("^([^:]+):(\d+): error:", line)
        if m:
            errFile = m.groups()[0]
            srcFileLookup[srcFile] = errFile
            
            # if a .h file, need to get the corresponding .cc file 
            if re.search("\.h$", errFile):
                mm = re.search("^\s+from ([^:]+.cc):(\d+):", raw_lines[iLine-2])
                if mm:
                    srcFileLookup[errFile] = mm.groups()[0]

            
            srcFile = srcFileLookup[errFile]
            if not already_compiling.has_key(srcFile):
                compile_line = compile_lines[srcFile]
                already_compiling[srcFile] = 1

                # write the #! line on the first pass
                if len(s) == 0:
                    s += "#!/usr/bin/env bash\n"

                # the rebuild script should echo what it's doing and do it.
                s += "echo \"" + compile_line + "\"\n"
                s += compile_line + "\n"  #" 2>&1 | " + sys.argv[0] + "\n"

                
        # highlight the text after searching for 'error' in the line
        # (highlighting inserts extra characters)
        line = regexColorReplace("([Ee]rror):", ["red", "bold"], line)
        
        ### filenames ###
        line = regexColorReplace(r'\/?(\w+\.(?:cc|h|i|hpp)):\d+[,:]', ["cyan"], line)
        
        ### file linenumbers ###
        # don't try to match the filename too, it's now wrapped in \esc for cyan
        line = regexColorReplace(':(\d+)[,:]', ["magenta"], line)

        ### tests ###
        line = regexColorReplace("(passed)", ["green"], line)
        line = regexColorReplace("(failed)", ["red", "bold"], line)

        ### yes/no ###
        line = regexColorReplace("(?:\.\.\. ?|\(cached\) ?)(yes)\n", ["green"], line)
        line = regexColorReplace("(?:\.\.\. ?|\(cached\) ?)(no)\n", ["red", "bold"], line)
        
        # add a line number to the output and make it bold
        line = "==" +str(i)+ "== " + line

        prev_line = raw_line
        
        sys.stdout.write(line)
        sys.stdout.flush()

        i += 1

    if len(s) > 0:
        fp = open(retryscript, 'w')
        fp.write(s)
        fp.close()
        os.chmod(retryscript, 0744)
        
    if log:
        fp_log.close()

#############################################################
# end
#############################################################

if __name__ == '__main__':

    ########################################################################
    # command line arguments and options
    ########################################################################
    parser = optparse.OptionParser(usage=__doc__)
    parser.add_option("-l", "--log", dest="log", action="store_true", default=False,
                      help="Log all messages in noI.log? (default=%default)")
    parser.add_option("-r", "--retryscript", default="b",
                      help="Name of script to retry the most recent compile statment. (default=%default)")
    opts, args = parser.parse_args()

    if len(args) > 0:
        parser.print_help()
        sys.exit(1)
    
    main(opts.log, opts.retryscript)
