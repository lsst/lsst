#!/usr/bin/env bash

# 31=red 32=green 33=yellow ---- 1=bold 6=normal
function color()
{
    CLR=$1
    shift
    FONT=$1
    shift
    TEXT=$1
    printf "\e[${CLR};${FONT}m ${TEXT} \e[0m\n"
}


POSSIBLE_TEST_DIRS="./.tests ./tests/.tests ../tests/.tests"
TEST_DIR=""
for TDIR in $POSSIBLE_TEST_DIRS
do
    if [ -d $TDIR ]; then
	TEST_DIR=$TDIR
    fi
done

###################################################################
## if we didn't find a directory see if we're in it, otherwise exit
if [ -z "$TEST_DIR" ]; then
    
    CWD=${PWD##*/}
    if [  $CWD = '.tests' ]; then
	TEST_DIR="./"
    else
	echo "Can't find .tests/ directory.  I tried:"
	for TDIR in $POSSIBLE_TEST_DIRS;
	do
	    echo $TDIR
	done
	echo "and we're not in it.  Have you built this package yet?"
	exit 1
    fi
fi

###################################################################
## go to the testing directory and see what's there
cd $TEST_DIR

###################################################################
## count the files and tally them in pass for fail
NFILE_STR=$(ls 2> /dev/null | wc -l)
NFAIL_STR=`ls *.failed 2> /dev/null | wc -l`
let 'NPASS = NFILE_STR - NFAIL_STR'
let 'NFAIL = NFAIL_STR + 0'

###################################################################
## not go back to the package root and print a bit on each file
cd - > /dev/null

FAILLINES=""
for TEST in $TEST_DIR/*
  do

  # get the time the test file was modified
  BUILDTIME=$(ls -lh $TEST | awk '{print $6,$7,$8}')

  # strip off the path
  FILE=$(basename $TEST)

  # format it
  LINE=$(printf "%-30s   %30s"  "$FILE"  "$BUILDTIME")

  # if there's no .failed appended ... then it passed
  if [ ${TEST%.failed} = ${TEST} ]; then  # passed
      color 32 6 "$LINE"
  else                                    # failed
      color 31 1 "$LINE"
      FAILFILES="$FAILFILES $TEST"
  fi
  
done

if [ $NFAIL -lt 10 -a $NFAIL -gt 0 ]; then
    echo 
    for FILE in $FAILFILES
    do
	color 31 1 "$FILE"
    done
fi

# print the counts
printf "\n";
color 33 1 "======================"
color 32 6 "Passed: $NPASS"
color 31 1 "Failed: $NFAIL"
color 33 1 "======================"
printf "\n";

exit 0;