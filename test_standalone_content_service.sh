#! /bin/bash

PATH_TO_TIMECMD=$(which time)

function check_vals()
{
  ENDPOINT=$1
  VAL_NAME=$2

  echo "Checking remote..."
  $PATH_TO_TIMECMD -f %E curl --output /tmp/REMOTEOUT -s "https://reactome.org/$ENDPOINT" && REMOTE_VAL=$(cat /tmp/REMOTEOUT)
  echo "checking local..."
  $PATH_TO_TIMECMD -f %E curl --output /tmp/LOCALOUT -s "http://localhost:8080/$ENDPOINT" && LOCAL_VAL=$(cat /tmp/LOCALOUT)

  if [ "$LOCAL_VAL" != "$REMOTE_VAL" ] ; then
    echo "$VAL_NAME don't match!"
    echo $LOCAL_VAL > /tmp/${VAL_NAME}_L
    echo $REMOTE_VAL > /tmp/${VAL_NAME}_R
    diff /tmp/LOCALOUT /tmp/REMOTEOUT
  else
    echo -e "$VAL_NAME test passed.\n"
  fi
}

echo -e "\nChecking names..."
check_vals ContentService/data/database/name 'Name'

echo -e "\nChecking versions..."
check_vals ContentService/data/database/version 'Version'

echo -e "\nChecking \"discover\"..."
check_vals ContentService/data/discover/R-HSA-446203 'Discovery'

echo -e "\nChecking \"discover\"..."
check_vals ContentService/data/discover/R-HSA-446203 'Discovery'

echo -e "\nChecking diseases..."
check_vals ContentService/data/diseases 'Diseases'

echo -e "\nChecking disease DOIDs..."
check_vals ContentService/data/diseases/doid 'Disease DOIDs'

echo -e "\nChecking complex (subunits)"
check_vals ContentService/data/complex/R-HSA-5674003/subunits?excludeStructures=false 'Complex (subunits)'

echo -e "\nChecking entity; componentOf"
check_vals ContentService/data/entity/R-HSA-199420/componentOf 'Entity - componentOf'

echo -e "\nChecking event hierarchy (Human)"
check_vals ContentService/data/eventsHierarchy/9606 'Human event hierarchy'

# PDF diffs cause problems
# echo -e "\nChecking PDF export"
# check_vals 'ContentService/exporter/document/event/R-HSA-177929.pdf?level%20%5B0%20-%201%5D=1&diagramProfile=Modern&resource=total&analysisProfile=Standard' "PDF_Export"
# Checking images is also not always going to work because even if a raster image is off by a pixel or two, the diff will fail.
# Even SVGs fail because I guess sometimes different XML elements are added to the file in a non-deterministic way, so that the rendered images are
# the same but the sources are not identical.
# ...let's just stick with comparing text (JSON) responses...
# echo -e "\nChecking pathway image export"
# check_vals 'ContentService/exporter/diagram/R-HSA-177929.svg?quality=5&flgInteractors=true&title=true&margin=15&ehld=true&diagramProfile=Modern&resource=total&analysisProfile=Standard' "SVG_Export"
# It seems like for SBGN, the order of output elements might also be non-deterministic, so I guess only SBML is going to be easy to test...

#   echo -e "\nChecking SBML export"
# check_vals 'ContentService/exporter/event/R-HSA-5205682.sbml' 'SBML_Export'
#
# echo -e "\nChecking interactors - psiquic summary"
# check_vals 'ContentService/interactors/psicquic/molecule/MINT/Q13501/summary' 'Interactors_psiquic_summary'
#
# echo -e "\nChecking interactors - list of psiquic resources"
# check_vals 'ContentService/interactors/psicquic/resources' 'Interactors_psiquic_resources'

echo -e "\nChecking interactors - pathays with molecule"
check_vals 'ContentService/interactors/static/molecule/Q9BXM7-1/pathways' 'Interactors_molecule_pathways'

echo -e "\nChecking mapping to UniProt"
check_vals 'ContentService/data/mapping/UniProt/PTEN/reactions' 'Maping_to_UniProt'

echo -e "\nChecking Orthology"
check_vals 'ContentService/data/orthology/R-HSA-6799198/species/49633' 'orthology'

echo -e "\nChecking participants"
check_vals 'ContentService/data/participants/5205685' 'participants'
