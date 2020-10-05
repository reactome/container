#! /bin/bash

# Before running this test script, start the stand-alone AnalysisService:
# docker run --rm -p 8080:8080 reactome/stand-alone-analysis-service:${RELEASE_VERSION} (eg:74; if port is already allocated locally, try '1234:8080')

# Getting the path to `time` ensures that we don't use the built-in *shell* command with the same name.
# This "other" time command allows some better formatting options for output.
PATH_TO_TIMECMD=$(which time)

# Checks valus via GET
function check_vals()
{
  ENDPOINT=$1
  VAL_NAME=$2
  JQ_FILTER=$3

  echo "Checking remote..."
  # Use jq to remove the token element - it will always cause a comparison to fail, since each server will generate a different token.
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
  # If values don't match, write them to temp files, then output the diff.
  if [ "$LOCAL_VAL" != "$REMOTE_VAL" ] ; then
    echo "$VAL_NAME don't match!"

    if [ ! -z "$JQ_FILTER" ] ; then
      echo $LOCAL_VAL | jq '.' > /tmp/${VAL_NAME}_L
      echo $REMOTE_VAL | jq '.' > /tmp/${VAL_NAME}_R
    else
      echo $LOCAL_VAL > /tmp/${VAL_NAME}_L
      echo $REMOTE_VAL > /tmp/${VAL_NAME}_R
    fi
    diff  /tmp/${VAL_NAME}_L /tmp/${VAL_NAME}_R
  else
    echo -e "$VAL_NAME test passed.\n"
  fi
}

# Checks values via POST
check_vals_post()
{
  ENDPOINT=$1
  VAL_NAME=$2
  POSTDATA=$3
  JQ_FILTER=$4

  echo "Checking remote..."
  $PATH_TO_TIMECMD -f %E curl -X POST --output /tmp/REMOTEOUT -H "Accept: application/json" -H "content-type: text/plain" -d "$POSTDATA" -s "https://reactome.org/$ENDPOINT"
  echo "checking local..."
  $PATH_TO_TIMECMD -f %E curl -X POST --output /tmp/LOCALOUT -H "Accept: application/json" -H "content-type: text/plain" -d "$POSTDATA" -s "http://localhost:8080/$ENDPOINT"
  LOCAL_VAL=""
  REMOTE_VAL=""
  if [ ! -z "$JQ_FILTER" ] ; then
    LOCAL_VAL=$(cat /tmp/LOCALOUT | jq -S "$JQ_FILTER" )
    REMOTE_VAL=$(cat /tmp/REMOTEOUT | jq -S "$JQ_FILTER" )
  else
    LOCAL_VAL=$(cat /tmp/LOCALOUT )
    REMOTE_VAL=$(cat /tmp/REMOTEOUT )
  fi

  if [ "$LOCAL_VAL" != "$REMOTE_VAL" ] ; then
    echo "$VAL_NAME don't match!"
    # "jq '.'" ensures that JSON gets pretty-formatted before it's output to file. Makes debugging easier."
    echo $LOCAL_VAL | jq '.' > /tmp/${VAL_NAME}_L
    echo $REMOTE_VAL | jq '.' > /tmp/${VAL_NAME}_R
    diff /tmp/${VAL_NAME}_L /tmp/${VAL_NAME}_R
  else
    echo -e "$VAL_NAME test passed.\n"
  fi
}

echo -e "\nChecking names..."
check_vals AnalysisService/database/name 'Names'

echo -e "\nChecking versions..."
check_vals AnalysisService/database/version 'Versions'

echo -e "\nCheck identifiers lookup & projection"
check_vals 'AnalysisService/identifier/BRAF/projection?interactors=true&pageSize=20&page=1&sortBy=ENTITIES_PVALUE&order=ASC&resource=TOTAL&pValue=1&includeDisease=true' 'Identifier_projection' 'del( .summary.token )'

echo -e "\nCheck batch look for identifiers"
check_vals_post 'AnalysisService/identifiers/?interactors=true&pageSize=20&page=1&sortBy=ENTITIES_PVALUE&order=ASC&resource=TOTAL&pValue=1&includeDisease=true' 'Identifier_batch' "BRAF, BRCA" 'del( .summary.token )'

echo -e "\nCheck identifier mappings"
check_vals_post 'AnalysisService/mapping/?interactors=true' 'IdentifierMapping' 'TGFBR2, 15611' '.'

echo -e "\nCheck identifier mappings projection"
check_vals_post 'AnalysisService/mapping/projection?interactors=true' 'IdentifierMappingProjection' 'TGFBR2, 15611' '.'

echo -e "\nCheck species comparison"
check_vals 'AnalysisService/species/homoSapiens/49646?pageSize=20&page=1&sortBy=ENTITIES_PVALUE&order=ASC&resource=TOTAL&pValue=1&includeDisease=true' 'SpeciesComparison' 'del( .summary.token )'
