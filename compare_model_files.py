import sys
from iotbx.map_model_manager import map_model_manager
from iotbx.data_manager import DataManager

def run_comparison(fileName1, fileName2, thresh, verbosity = 10):
  # Read the the models from each file.
  dm = DataManager()
  dm.set_overwrite(True)

  if verbosity >= 1:
    print('Reading model from',fileName1)
  dm.process_model_file(fileName1)
  m1 = dm.get_model(fileName1)

  if verbosity >= 1:
    print('Reading model from',fileName2)
  dm.process_model_file(fileName2)
  m2 = dm.get_model(fileName2)

  # Compare the two models and report on any differences.
  # Differences in numbers of models, chains, or residues are fatal.
  # Differences in atoms are what is reported.
  models1 = m1.get_hierarchy().models()
  models2 = m2.get_hierarchy().models()
  if len(models1) != len(models2):
    print('Error: Different number of models:',len(models1),'vs.',len(models2))
    sys.exit(2)
  for i in range(len(models1)):
    if verbosity >= 2:
      print('Model',models1[i].id)
    chains1 = models1[i].chains()
    chains2 = models2[i].chains()
    if len(chains1) != len(chains2):
      print('Error: Different number of chains:',len(chains1),'vs.',len(chains2),'in model',models1[i].id)
      sys.exit(2)
    for j in range(len(chains1)):
      if verbosity >= 3:
        print('  Chain',chains1[j].id)
      r1 = chains1[j].residue_groups()
      r2 = chains2[j].residue_groups()
      if len(r1) != len(r2):
        print('Error: Different number of residues:',len(r1),'vs.',len(r2),'in chain',chains1[j].id)
        sys.exit(2)
      for k in range(len(r1)):
        if verbosity >= 4:
          print('    Residue group',r1[k].resseq)
        ag1 = r1[k].atom_groups()
        ag2 = r2[k].atom_groups()
        if len(ag1) != len(ag2):
          print('Error: Different number of atom groups:',len(ag1),'vs.',len(ag2),'in residue group',r1[k].resseq)
          sys.exit(2)
        for m in range(len(ag1)):
          if verbosity >= 5:
            print('      Atom group',ag1[m].resname)
          as1 = ag1[m].atoms()
          as2 = ag2[m].atoms()

          # Atom names are unique within residues, so we can use that to
          # match atoms in one file from those in the other and print out
          # missing atoms and differences in positions.
          # We only check differences in positions for matches in the first
          # list because they will be duplicated by a check for the second.
          for a1 in as1:
            match = ag2[m].get_atom(a1.name.strip())
            if match is None:
              print(ag1[m].resname+' '+chains1[j].id+r1[k].resseq,'Only in first:',a1.name.strip())
              continue
            dist = a1.distance(match)
            if dist > thresh:
              print(ag1[m].resname+' '+chains1[j].id+r1[k].resseq,'Distance between',a1.name.strip(),"{:.2f}".format(dist))
          for a2 in as2:
            match = ag1[m].get_atom(a2.name.strip())
            if match is None:
              print(ag1[m].resname+' '+chains1[j].id+r1[k].resseq,'Only in second:',a2.name.strip())

if __name__ == "__main__":

  threshold = 0.02
  verbosity = 0
  if len(sys.argv) < 3:
    print('Usage:',sys.argv[0],'FILE1 FILE2 [threshold [verbosity]]')
    print('  threshold: Distance atoms must be apart to be reported: default',threshold)
    print('  verbosity: Amount of extra information to print: default',verbosity)
    sys.exit(1)

  try:
    threshold = float(sys.argv[3])
  except:
    pass

  try:
    verbosity = int(sys.argv[4])
  except:
    pass

  run_comparison(sys.argv[1], sys.argv[2], threshold, verbosity)

  sys.exit(0)

