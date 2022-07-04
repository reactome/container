#! /bin/bash


echo "getting fireworks files"
mkdir fireworks
cd ./fireworks
wget -nd -nv -r --no-parent http://reactome.org/download/current/fireworks/
rm index.html* robots.txt
cd ..
echo "getting diagram files"
mkdir diagram
cd ./diagram
# this is a big download, so -q option might be nice here
wget -nd -nv -r --no-parent http://reactome.org/download/current/diagram/
rm index.html* robots.txt
