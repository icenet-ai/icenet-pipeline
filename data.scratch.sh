#!/usr/bin/bash
# RUN in hemisphere folder to convert Toms filenames
for VAR in $( find . -maxdepth 1 -type d -a ! -name '.' -exec basename {} \; ); do 
  for VAR_FILE in $( find $VAR -type f -a \( -name '19*.nc' -o -name '20*.nc' \) -print ); do
    VAR_DIR=$( dirname $VAR_FILE )
    VAR_NAME=$( basename $VAR_FILE )
    mv ${VAR_DIR}/${VAR_NAME} ${VAR_DIR}/${VAR}_${VAR_NAME}
  done 
done 2>&1 | tee moves.log

