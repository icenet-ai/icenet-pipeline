import datetime as dt
import logging

import pandas as pd

from icenet2.data.interfaces.cds import ERA5Downloader
from icenet2.data.interfaces.esgf import CMIP6Downloader
from icenet2.data.sic.osisaf import SICDownloader
from icenet2.data.sic.mask import Masks
from icenet2.data.processors.datasets \
    import IceNetERA5PreProcessor, IceNetOSIPreProcessor
from icenet2.data.loader import IceNetDataLoader

logging.getLogger().setLevel(logging.DEBUG)

DATES = {
    "live": [pd.to_datetime(date).date() for date in
             pd.date_range("1979-01-01", dt.datetime.now().date(), freq="D")],
    "test": [pd.to_datetime(date).date() for date in
             pd.date_range("1989-01-01", "1989-01-06", freq="D")],
}

cmip = False
dates = DATES["test"]

if __name__ == "__main__":
    Masks(north=False, south=True).generate(save_polarhole_masks=False)
    Masks(north=True, south=False).generate(save_polarhole_masks=True)

    # PRE-TRAINING DATA

    # CMIP
    if cmip:
        cmip_sources = (
            ("MRI-ESM2-0", "r1i1p1f1", None),
            ("MRI-ESM2-0", "r2i1p1f1", None),
            ("MRI-ESM2-0", "r3i1p1f1", None),
            ("MRI-ESM2-0", "r4i1p1f1", None),
            ("MRI-ESM2-0", "r5i1p1f1", None),
            ("EC-Earth3", "r2i1p1f1", "gr"),
            ("EC-Earth3", "r7i1p1f1", "gr"),
            ("EC-Earth3", "r10i1p1f1", "gr"),
            ("EC-Earth3", "r12i1p1f1", "gr"),
            ("EC-Earth3", "r14i1p1f1", "gr"),
        )
        for source, member, override in cmip_sources:
            downloader = CMIP6Downloader(
                source="MRI-ESM2-0",
                member=["r1i1p1f1", "r2i1p1f1", "r3i1p1f1", "r4i1p1f1", "r5i1p1f1"],
                var_names=["tas", "ta", "tos", "psl", "zg", "hus", "rlds", "rsds",
                           "uas", "vas", "siconca"],
                pressure_levels=[None, [500], None, None, [250, 500], [1000], None,
                                 None, None, None],
                dates=[None],
                grid_override=override,
            )
            downloader.download()
            downloader.regrid()
            downloader.rotate_wind_data()

    # ERA5
    era5 = ERA5Downloader(
        var_names=["tas", "ta", "tos", "psl", "zg", "hus", "rlds", "rsds",
                   "uas", "vas"],
        pressure_levels=[None, [500], None, None, [250, 500], [1000], None,
                         None, None, None],
        dates=dates,
    )
    era5.download()
    era5.regrid()
    era5.rotate_wind_data()

    sic = SICDownloader(
        dates=dates,
    )
    sic.download()

    # Processing

    # TODO: check CMIP

    # FIXME: hardcoded dates, should not be subsets etc etc (breaks certain
    #  things but being used for interim testing)
    train_dates = dates[:-2]
    val_dates = dates[-2:]
    test_dates = []

    pp = IceNetERA5PreProcessor(
        ["uas", "vas"],
        ["tas", "ta500", "tos", "psl", "zg500", "zg250", "rsds", "rlds",
         "hus1000"],
        "test1",
        train_dates,
        val_dates,
        test_dates,
        linear_trends=tuple(),
    )
    pp.init_source_data()
    pp.process()

    osi = IceNetOSIPreProcessor(
        ["siconca"],
        [],
        "test1",
        train_dates,
        val_dates,
        test_dates,
        include_circday=False,
        include_land=False,
        linear_trends=["siconca"],
        linear_trend_days=3,
    )
    osi.init_source_data()
    osi.process()

    dl = IceNetDataLoader("loader.test1.json",
                          "test_forecast",
                          2,
                          north=True)
    dl.generate()
