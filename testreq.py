#!/usr/bin/env python
from ecmwfapi import ECMWFService

## This is what we need
# https://www.ecmwf.int/en/forecasts/dataset/atmospheric-model-high-resolution-10-day-forecast

server = ECMWFService("mars")
server.execute(
    {
    "class": "od",
    "date": "20210721",
    "expver": "1",
    "levtype": "sfc",
    "param": "167.128",
    "step": "0/to/240/by/12",
    "stream": "oper",
    "time": "00",
    "type": "fc"
    },
    "target.grib")
