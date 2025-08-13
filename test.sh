set -xe

PACKAGE=$1


echo $PACKAGE

PARENT_FOLDER=${PACKAGE%/*} # ABCDE
FOLDER=${PACKAGE#*/} # 12345

echo $PARENT_FOLDER
echo $FOLDER

mkdir -p sdk_container/src/third_party/portage-stable/$PARENT_FOLDER/
cp -r ../gentoo/$PACKAGE sdk_container/src/third_party/portage-stable/$PARENT_FOLDER/

