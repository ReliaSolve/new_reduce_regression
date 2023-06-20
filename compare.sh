#!/bin/bash
#############################################################################
# Run regression tests against the current CCTBX/Reduce and a
# specified original to check for differences between the results.
#
#############################################################################

######################
# Parse the command line

orig="e9b0b84f2e53e18ee87948466b4fb8df9b975f80"
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
orig_args="-FLIP -DROP_HYDROGENS_ON_ATOM_RECORDS -DROP_HYDROGENS_ON_OTHER_RECORDS"
new_exe="mmtbx.reduce2"

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
  # Turn off the bond fix-up in Reduce2 so that we end up with Probe2 scores that
  # match the resulting geometry, so we can see whether things are better flipped
  # or not flipped.

  echo "Testing structure $base"
  # Run old and new versions in parallel
  ($orig_exe $orig_args $tfile > outputs/$base.orig.pdb 2> outputs/$base.orig.stderr) &
  ($new_exe $tfile add_flip_movers=True output.filename=outputs/$base.new.pdb output.description_file_name=outputs/$base.new.description output.overwrite=True > outputs/$base.new.stdout 2> outputs/$base.new.stderr) &
  wait

  # Use Probe2 to generate Kinemages from both so we can debug.
  (mmtbx.probe2 excluded_bond_chain_length=3 ignore_lack_of_explicit_hydrogens=True outputs/$base.orig.pdb output.filename=outputs/$base.orig.kin output.overwrite=True > outputs/$base.orig.probe2.kin.stdout 2> outputs/$base.orig.probe2.kin.stderr) &
  (mmtbx.probe2 excluded_bond_chain_length=3 ignore_lack_of_explicit_hydrogens=True outputs/$base.new.pdb output.filename=outputs/$base.new.kin output.overwrite=True > outputs/$base.new.probe2.kin.stdout 2> outputs/$base.new.probe2.kin.stderr) &

  # Use Probe2 to score both the original and new results to see which one is better.
  # Note that both will have scored things with non-fixed-up flips even though the output
  # includes flips, but at least we are comparing apples to apples.
  (mmtbx.probe2 excluded_bond_chain_length=3 ignore_lack_of_explicit_hydrogens=True outputs/$base.orig.pdb output.filename=outputs/$base.orig.txt output.overwrite=True output.count_dots=True > outputs/$base.orig.probe2.stdout 2> outputs/$base.orig.probe2.stderr) &
  (mmtbx.probe2 excluded_bond_chain_length=3 ignore_lack_of_explicit_hydrogens=True outputs/$base.new.pdb output.filename=outputs/$base.new.txt output.overwrite=True output.count_dots=True > outputs/$base.new.probe2.stdout 2> outputs/$base.new.probe2.stderr) &
  wait

  # See if Reduce2 did at least as well as Reduce.  If not, report a failure.
  origScore=`grep grand outputs/$base.orig.txt | awk '{print $5}'`
  newScore=`grep grand outputs/$base.new.txt | awk '{print $5}'`
  if (( $(echo "$origScore > $newScore" | bc -l) )); then echo " Worse!"; failed=$((failed + 1)); fi
  if (( $(echo "$origScore < $newScore" | bc -l) )); then echo " Better!"; fi

  # @todo Score each Reduce2 flip in the original and non-fixup flip orientation and see if
  # it picked the best one.

done

echo
if [ $failed -eq 0 ]
then
  echo "Success!"
else
  echo "$failed files failed"
fi

exit $failed

