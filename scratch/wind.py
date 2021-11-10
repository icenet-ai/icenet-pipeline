from icenet2.data.interfaces.cds import ERA5Downloader
import pandas as pd
import logging
logging.basicConfig(level=logging.DEBUG)
era5 = ERA5Downloader(
            var_names=["tas", "ta", "tos", "psl", "zg", "hus", "rlds", "rsds",
                               "uas", "vas"],
                pressure_levels=[None, [500], None, None, [250, 500], [1000], None,
                                         None, None, None],
                    dates=[pd.to_datetime(date).date() for date in
                                   pd.date_range("1990-1-1", "1999-12-31",
                                                                freq="D")],
                                       north=False,
                                           south=True
                                           )
import glob
dfs = glob.glob("./data/era5/sh/[uv]as/199[23456789]/*.nc")
dfs += glob.glob("./data/era5/sh/[uv]as/1991/*_1991_0[6789]_*.nc")
dfs += glob.glob("./data/era5/sh/[uv]as/1991/*_1991_1[012]_*.nc")
era5.rotate_wind_data(manual_files=dfs)

