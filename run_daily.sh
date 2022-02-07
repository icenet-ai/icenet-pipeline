#!/usr/bin/env bash

# FIXME: We're doing a daily run but uploading only the most recent?
DAYS_BEHIND=0
FORECAST_NAME="_daily_forecast"
LAG=3
UPLOAD=0
RUNNAME="$( basename `realpath .` )"
END_DATE="yesterday"

while getopts ":b:e:l:n:ux" opt; do
  case "$opt" in
    b)  DAYS_BEHIND=$OPTARG ;;
    e)  END_DATE=$OPTARG ;;
    l)  LAG=$OPTARG ;;
    n)  FORECAST_NAME="_${OPTARG}" ;;
    u)  UPLOAD=1 ;;
    x)  DO_NOT_EXECUTE=1 ;;
  esac
done

shift $((OPTIND-1))

[[ "${1:-}" = "--" ]] && shift

COPY="${1:-}"

echo "Leftovers from getopt: $@"

if [[ "$END_DATE" != "yesterday" ]] \
    && ! [[ "$END_DATE" =~ ^[0-9]{4}-[0-9]{1,2}-[0-9]{1,2}$ ]]; then
    echo "$END_DATE if specified, needs to be in the form yyyy-mm-dd"
    exit 1
else
    echo "Using end date $END_DATE"
fi

ICENET_START=$( date --date="$END_DATE - `expr $LAG \+ $DAYS_BEHIND` days" +%F )
ICENET_END=`date --date="$END_DATE" +%F`
LOGDIR="logs/`date +%Y%m%d.%H%M`"

echo "Processing dates $ICENET_START to $ICENET_END"

for HEMI in south north; do
    PROC_NAME="${HEMI}${FORECAST_NAME}"

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
            
    if [[ $UPLOAD == 1 ]]; then
        icenet_upload_azure -v \
            results/predict/${PROC_NAME}.nc $ICENET_END \
                2>&1 | tee ${LOGDIR}/${PROC_NAME}.upload_azure.log
    fi

    # while read -rs DT; do echo "Processing $DT"; icenet_upload_local -v results/predict/north_daily_forecast.nc /data/twins/common/icenet $DT; done <predict.north_daily_forecast.csv
    if [[ ! -z "$COPY" ]]; then
        icenet_upload_local -v \
            results/predict/${PROC_NAME}.nc /data/twins/common/icenet $ICENET_END \
                2>&1 | tee ${LOGDIR}/${PROC_NAME}.upload_local.log
    fi
done 

