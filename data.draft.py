import concurrent.futures
import datetime as dt
import logging

from concurrent.futures import ThreadPoolExecutor

import pandas as pd

from icenet2.data.interfaces.cds import ERA5Downloader
from icenet2.data.interfaces.esgf import CMIP6Downloader
from icenet2.data.sic.osisaf import SICDownloader
from icenet2.data.sic.mask import Masks

logging.getLogger().setLevel(logging.DEBUG)

DATES = {
    "live": [pd.to_datetime(date).date() for date in
             pd.date_range("1979-01-01", dt.datetime.now().date(), freq="D")],
    "test": [pd.to_datetime(date).date() for date in
             pd.date_range("1988-12-31", "1989-01-06", freq="D")],
}

cmip = True
dates = DATES["live"]

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

        def cmip_retrieve(source, member, override):
            downloader = CMIP6Downloader(
                source=source,
                member=member,
                var_names=["tas", "ta", "tos", "psl", "zg", "hus", "rlds",
                           "rsds",
                           "uas", "vas", "siconca"],
                pressure_levels=[None, [500], None, None, [250, 500], [1000],
                                 None,
                                 None, None, None],
                dates=[None],
                grid_override=override,
            )
            logging.info("CMIP downloading: {} {} {}".format(source,
                                                             member,
                                                             override))
            downloader.download()
            logging.info("CMIP regridding: {} {} {}".format(source,
                                                            member,
                                                            override))
            downloader.regrid()
            logging.info("CMIP rotating: {} {} {}".format(source,
                                                          member,
                                                          override))
            downloader.rotate_wind_data()
            return "CMIP done: {} {} {}".format(source, member, override)


        with ThreadPoolExecutor(max_workers=4) as executor:
            futures = []

            for source, member, override in cmip_sources:
                future = executor.submit(cmip_retrieve,
                                         source,
                                         member,
                                         override)

            for future in concurrent.futures.as_completed(futures):
                try:
                    msg = future.result()
                except Exception as e:
                    logging.error(e)
                else:
                    logging.info(msg)

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

