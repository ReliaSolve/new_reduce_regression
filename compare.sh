#!/bin/bash
#############################################################################
# Run regression tests against the current CCTBX/Reduce and a
# specified original (default e31d8e0ef14e6e8b85634dea502cadac9cf7832b)
# to check for differences between the results.
#
#############################################################################

######################
# Parse the command line

orig="fcbdf1821e02661b7b3a637a1e57bcad6ba1cea9"
if [ "$1" != "" ] ; then orig="$1" ; fi

echo "Checking against $orig"

#####################
# Make sure the reduce submodule is checked out

echo "Updating submodule"
git submodule update --init
(cd reduce; git pull) &> /dev/null 

######################
# The original version is build using Make because older versions don't
# have CMakeLists.txt files.

echo "Building $orig"
(cd reduce; git checkout $orig; make) &> /dev/null 

orig_exe="./reduce/reduce_src/reduce"
orig_arg=""
new_exe="python /home/`whoami`/rlab/cctbx-reduce/modules/cctbx_project/mmtbx/reduce/Optimizers.py"

######################
# Generate two outputs for each test file, redirecting standard
# output and standard error to different files.
# Test the standard outputs to see if any differences are other than we expect.

echo
mkdir -p outputs
files=`(cd fragments; ls *.pdb)`
failed=0
for f in $files; do
  ##############################################
  # Full input-file name
  inf=fragments/$f

  # We must extract to a file and then run with that file as a command-line argument
  # because the original version did not process all models in a file when run with
  # the model coming on standard input.
  tfile=outputs/temp_file.tmp
  cp $inf $tfile

  ##############################################
  # Test with no command-line arguments

  echo "Testing file $f"
  # Run old and new versions in parallel
  ($orig_exe $orig_args $tfile > outputs/$f.orig 2> outputs/$f.orig.stderr) &
  ($new_exe $tfile > outputs/$f.new.stdout 2> outputs/$f.new.stderr ; mv deleteme.pdb outputs/$f.new) &
  wait

  # Test for unexpected differences.  The script returns messages when there
  # are any differences.  Threshold for significant difference between atom
  # positions is set.
  THRESH=0.05
  d=`python compare_model_files.py outputs/$f.orig outputs/$f.new $THRESH`
  echo "$d" > outputs/$f.compare
  s=`echo -n $d | wc -c`
  if [ $s -ne 0 ]; then echo " Failed!"; failed=$((failed + 1)); fi
  rm -f $tfile

done

echo
if [ $failed -eq 0 ]
then
  echo "Success!"
else
  echo "$failed files failed"
fi

exit $failed

