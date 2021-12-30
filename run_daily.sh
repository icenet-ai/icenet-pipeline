#!/usr/bin/env bash

DAYS_BEHIND=${1:-0}
LAG=${2:-3}
ICENET_START=$( date --date="yesterday - `expr $LAG \+ $DAYS_BEHIND` days" +%F )
ICENET_END=`date --date="yesterday" +%F`
LOGDIR="logs/`date +%Y%m%d.%H%M`"

for HEMI in south north; do
    PROC_NAME="${HEMI}_daily_forecast"

    if [ "$HEMI" == "north" ]; then
        HEMI_SHORT="nh"
    else
        HEMI_SHORT="sh"
    fi
    
    mkdir $LOGDIR
    echo "Removing previous daily predictions"
    rm -rv results/predict/$PROC_NAME
    rm -v results/predict/${PROC_NAME}.nc

    echo "Removing previous ensemble"
    rm -rv ensemble/$PROC_NAME

    icenet_data_hres -v $HEMI $ICENET_START $ICENET_END \
        2>&1 | tee ${LOGDIR}/${PROC_NAME}.data.hres.log

    icenet_process_metadata -v ${PROC_NAME} $HEMI \
            2>&1 | tee ${LOGDIR}/${PROC_NAME}.proc.meta.log
            
    icenet_process_hres -v ${PROC_NAME} $HEMI \
        -ts $ICENET_START -te $ICENET_END -l $LAG \
        -r processed/${HEMI}_10/era5/${HEMI_SHORT} \
            2>&1 | tee ${LOGDIR}/${PROC_NAME}.proc.hres.log
    
    # NOTE THE -c - we only produce configuration here...
    icenet_dataset_create -c -l $LAG -ob 1 -w 4 $PROC_NAME $HEMI \
        2>&1 | tee ${LOGDIR}/${PROC_NAME}.dataset.log        
        
    ./loader_test_dates.sh $PROC_NAME | tail -n `expr $DAYS_BEHIND + 1` >predict.${PROC_NAME}.csv
    
    echo rm -rv ensemble/${PROC_NAME}/

    # NOTE THE -l - we use the loader directly
    ./run_predict_ensemble.sh \
        -b 1 -f 1.2 -p bashpc.sh -l -i ${HEMI}_test22 \
        ${HEMI}_hemi $PROC_NAME $PROC_NAME predict.${PROC_NAME}.csv \
            2>&1 | tee ${LOGDIR}/${PROC_NAME}.ensemble.predict.log
            
    icenet_upload_azure -v \
        results/predict/${PROC_NAME}.nc $ICENET_END \
            2>&1 | tee ${LOGDIR}/${PROC_NAME}.upload.log
done 

