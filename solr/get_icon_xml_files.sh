#! /bin/bash

cd /tmp
mkdir -p icon-lib && cd icon-lib
wget -O icon-lib-svg.tgz https://reactome.org/icon/icon-lib-svg.tgz
tar -xf icon-lib-svg.tgz
echo "Number of *.svg files"
ls -lht *.svg | wc -l
# for f in $(ls *.svg) ; do
# 	FILENAME=$(basename $f)
# 	FILENAME=${FILENAME%.svg}
# 	wget -O $FILENAME.xml https://reactome.org/icon/$FILENAME.xml -a wget.log
# done

# The for-loop above takes 3 to 5 minutes. Using GNU Parallel takes ~30 seconds.
apt-get install -y parallel
ls *.svg | parallel "wget -O {.}.xml https://reactome.org/icon/{.}.xml 2>&1" > wget.log

echo "Number of *.xml files"
ls -lht *.xml | wc -l
cd -
