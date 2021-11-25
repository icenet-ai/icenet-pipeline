#!/usr/bin/env python

import xarray as xr
import pandas as pd
import glob, os

for src_var, var_name in [
    #("q", "hus1000"), 
    #("sp", "psl"), 
    #("strd", "rlds"), 
    #("ssrd", "rsds"), 
    #("t", "ta500"), 
    #("sst", "tos"), 
    ("uas", "uas"), 
    ("vas", "vas"), 
    ("z", "zg250"), 
    ("z", "zg500")]:
    base_path = "./data/era5/sh/{}/".format(var_name)
    files = []
    for dt in pd.date_range("1990-1-1", "1999-12-31"):
        path = os.path.join(base_path, str(dt.year), dt.strftime("%Y_%m_%d.nc"))
        temp_path = os.path.join(base_path, str(dt.year), dt.strftime("temp.%Y_%m_%d.nc"))
        print("{} -> {}".format(path, temp_path))
        os.rename(path, temp_path)
        files.append(temp_path)
    ds = xr.open_mfdataset(files, concat_dim="time", combine="nested", parallel=True)
    ds = ds.drop_vars(["lambert_azimuthal_equal_area"])
    ds = ds.rename_vars({src_var:var_name})
    for dt in ds.time.values:
        day = pd.to_datetime(dt)
        daily_path = os.path.join(base_path, str(day.year), day.strftime("%Y_%m_%d.nc"))
        print(daily_path)
        ds.sel(time=slice(day, day)).to_netcdf(daily_path)
    ds.close()
    for file in files:
        print(file)
        os.unlink(file)
