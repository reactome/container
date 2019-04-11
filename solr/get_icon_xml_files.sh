#! /bin/bash

cd /tmp
mkdir -p icon-lib && cd icon-lib
wget -O icon-lib-svg.tgz https://reactome.org/icon/icon-lib-svg.tgz
tar -xf icon-lib-svg.tgz
echo "Number of *.svg files"
ls -lht *.svg | wc -l
for f in $(ls *.svg) ; do
	FILENAME=$(basename $f)
	FILENAME=${FILENAME%.svg}
	wget -O $FILENAME.xml https://reactome.org/icon/$FILENAME.xml -a wget.log
done
echo "Number of *.xml files"
ls -lht *.xml | wc -l
cd -
