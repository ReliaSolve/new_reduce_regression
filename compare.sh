#!/bin/bash
#############################################################################
# Run regression tests against the current CCTBX/Reduce and a
# specified original to check for differences between the results.
#
#############################################################################

######################
# Parse the command line

orig="e435fa95557172f7741e9526fbd66a3c01354408"
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
orig_arg="-FLIP"
new_exe="python /home/`whoami`/rlab/cctbx-reduce-python27/modules/cctbx_project/mmtbx/reduce/Optimizers.py"

######################
# Generate two outputs for each test file, redirecting standard
# output and standard error to different files.  This also causes the atom
# dump files, which are what we actually compare.
# Test the dump files to see if any differences are other than we expect.

echo
mkdir -p outputs
files=`(cd fragments; ls *.pdb)`
failed=0
for f in $files; do
  # Full input-file name
  inf=fragments/$f

  # File base name
  base=`echo $f | cut -d \. -f 1`

  # We must extract to a file and then run with that file as a command-line argument
  # because the original version did not process all models in a file when run with
  # the model coming on standard input.
  tfile=outputs/temp_file.tmp
  cp $inf $tfile

  ##############################################
  # Test with -FLIP command-line argument on the original, so it behaves like the new.

  echo "Testing structure $base"
  # Run old and new versions in parallel
  ($orig_exe $orig_args -DUMPatoms outputs/$base.orig.dump $tfile > outputs/$base.orig.pdb 2> outputs/$base.orig.stderr) &
  ($new_exe $tfile > outputs/$base.new.stdout 2> outputs/$base.new.stderr ; mv deleteme.pdb outputs/$base.new.pdb; mv atomDump.pdb outputs/$base.new.dump) &
  wait

  # Test for unexpected differences.  The script returns messages when there
  # are any differences.  Threshold for significant difference between atom
  # positions is set.
  THRESH=0.05
  d=`python compare_dump_files.py outputs/$base.orig.dump outputs/$base.new.dump $THRESH`
  echo "$d" > outputs/$base.compare
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

