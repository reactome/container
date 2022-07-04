#! /bin/bash

# Before running this test script, start the stand-alone ContentService:
# docker run --rm -p 8080:8080 reactome/stand-alone-content-service:ReleaseXX (eg:Release74; if port is already allocated locally, try '1234:8080')

# get path to shell-independent "time" command. Many shells define a "time" keyword which is not what we want here.
PATH_TO_TIMECMD=$(which time)

# Check values at local and remote ContentService
function check_vals()
{
  ENDPOINT=$1
  VAL_NAME=$2
  JQ_FILTER=$3

  echo "Checking remote..."
  $PATH_TO_TIMECMD -f %E curl --output /tmp/REMOTEOUT -s "https://reactome.org/$ENDPOINT"
  echo "checking local..."
  $PATH_TO_TIMECMD -f %E curl --output /tmp/LOCALOUT -s "http://localhost:8080/$ENDPOINT"

  LOCAL_VAL=""
  REMOTE_VAL=""
  # process the returned value with jq if a jq filter was given.
  if [ ! -z "$JQ_FILTER" ] ; then
    LOCAL_VAL=$(cat /tmp/LOCALOUT | jq -S "$JQ_FILTER")
    REMOTE_VAL=$(cat /tmp/REMOTEOUT | jq -S "$JQ_FILTER")
  else
    LOCAL_VAL=$(cat /tmp/LOCALOUT)
    REMOTE_VAL=$(cat /tmp/REMOTEOUT)
  fi

  # If values from the different servers don't match, output the diff to the console.
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
check_vals ContentService/data/discover/R-HSA-446203 'Discovery' '.'

echo -e "\nChecking \"discover\"..."
check_vals ContentService/data/discover/R-HSA-446203 'Discovery' '.'

echo -e "\nChecking diseases..."
check_vals ContentService/data/diseases 'Diseases' '.'

echo -e "\nChecking disease DOIDs..."
check_vals ContentService/data/diseases/doid 'Disease DOIDs' 

echo -e "\nChecking complex (subunits)"
check_vals ContentService/data/complex/R-HSA-5674003/subunits?excludeStructures=false 'Complex (subunits)' '.'

echo -e "\nChecking entity; componentOf"
check_vals ContentService/data/entity/R-HSA-199420/componentOf 'Entity - componentOf' '.'

echo -e "\nChecking event hierarchy (Human)"
check_vals ContentService/data/eventsHierarchy/9606 'Human event hierarchy' '.'

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

# ...never mind, it seems that the elements in SBML Exports might not be in the same sequence, and it looks like even some metadata might not be exactly the same. Comparing outputs could be very difficult.
# Verify that they are produced but don't freak out if they don't match. OR, use some sort of SBML-specific tool (if it exists) to check for diffs.
echo -e "\nChecking SBML export"
check_vals 'ContentService/exporter/event/R-HSA-5205682.sbml' 'SBML_Export'

echo -e "\nChecking interactors - psiquic summary"
check_vals 'ContentService/interactors/psicquic/molecule/MINT/Q13501/summary' 'Interactors_psiquic_summary'

echo -e "\nChecking interactors - list of psiquic resources"
check_vals 'ContentService/interactors/psicquic/resources' 'Interactors_psiquic_resources'

echo -e "\nChecking interactors - pathays with molecule"
check_vals 'ContentService/interactors/static/molecule/Q9BXM7-1/pathways?species=Homo%20sapiens' 'Interactors_molecule_pathways'

echo -e "\nChecking mapping to UniProt"
check_vals 'ContentService/data/mapping/UniProt/PTEN/reactions' 'Maping_to_UniProt'

echo -e "\nChecking Orthology"
check_vals 'ContentService/data/orthology/R-HSA-6799198/species/49633' 'orthology'

echo -e "\nChecking participants"
check_vals 'ContentService/data/participants/5205685' 'participants'

echo -e "\nChecking events contained in pathways"
check_vals 'ContentService/data/pathway/R-HSA-5673001/containedEvents' 'events_contained_in_pathways' '.'

echo -e "\nCheck top level pathways in species"
check_vals 'ContentService/data/pathways/top/Gallus%2Bgallus' 'top_level_pathways_for_species_ggallus' '.'

echo -e "\nCheck person endpoint - search by name"
check_vals 'ContentService/data/people/name/Steve%20Jupe' 'lookup_steve_jupe' '.'

echo -e "\nCheck person endpoint - pathways authoured by Person"
check_vals 'ContentService/data/person/391309/authoredPathways' 'authoured_pathways' '.'

echo -e "\nCheck enhanced query"
check_vals 'ContentService/data/query/enhanced/R-HSA-60140' 'query'  '.'

echo -e "\nCheck cross-references lookup"
check_vals 'ContentService/references/mapping/15377' 'cross-references' '.'

echo -e "\nCheck number of entries for a schema type (Pathway)"
check_vals 'ContentService/data/schema/Pathway/count' 'schema_count'

echo -e "\nCheck Solr"
check_vals 'ContentService/search/facet_query?query=TP53' 'solr_facet_search'

echo -e "\nCheck species list"
check_vals 'ContentService/data/species/all' 'species_list' '.'
