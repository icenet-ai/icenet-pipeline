import argparse
import concurrent.futures
import datetime as dt
import logging
import re

from concurrent.futures import ThreadPoolExecutor

import pandas as pd

from icenet2.data.interfaces.cds import ERA5Downloader
from icenet2.data.interfaces.esgf import CMIP6Downloader
from icenet2.data.sic.osisaf import SICDownloader
from icenet2.data.sic.mask import Masks


def date_arg(string):
    date_match = re.search(r"(\d{4})-(\d{1,2})-(\d{1,2})", string)
    return dt.date(*[int(s) for s in date_match.groups()])


def get_args():
    ap = argparse.ArgumentParser()
    ap.add_argument("hemisphere", choices=("north", "south"))

    ap.add_argument("start_date", type=date_arg)
    ap.add_argument("end_date", type=date_arg)

    ap.add_argument("-c", "--cmip", action="store_true", default=False)
    ap.add_argument("-e", "--era", action="store_true", default=False)
    ap.add_argument("-o", "--osisaf", action="store_true", default=False)

    ap.add_argument("-v", "--verbose", action="store_true", default=False)
    return ap.parse_args()


def get_data(dates,
             cmip=False,
             era=False,
             osasif=False,
             north=True,
             south=False):
    Masks(north=north, south=south).generate(save_polarhole_masks=north)

    # PRE-TRAINING DATA

    # CMIP
    if cmip:
        logging.info("CMIP6 Data Downloading")
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
                                 None, None, None, None, None],
                dates=[None],
                grid_override=override,
                north=north,
                south=south
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

            for source_arg, member_arg, override_arg in cmip_sources:
                future = executor.submit(cmip_retrieve,
                                         source_arg,
                                         member_arg,
                                         override_arg)
                futures.append(future)

            for future in concurrent.futures.as_completed(futures):
                try:
                    msg = future.result()
                except Exception as e:
                    logging.error(e)
                else:
                    logging.info(msg)

    # ERA5
    if era:
        logging.info("ERA5 Data Downloading")
        era5 = ERA5Downloader(
            var_names=["tas", "ta", "tos", "psl", "zg", "hus", "rlds", "rsds",
                       "uas", "vas"],
            pressure_levels=[None, [500], None, None, [250, 500], [1000], None,
                             None, None, None],
            dates=dates,
            north=north,
            south=south
        )
        era5.download()
        era5.regrid()
        era5.rotate_wind_data()

    if osasif:
        logging.info("OSASIF-SIC Data Downloading")
        sic = SICDownloader(
            dates=dates,
            north=north,
            south=south
        )
        sic.download()


if __name__ == "__main__":
    args = get_args()

    logging.basicConfig(level=logging.DEBUG if args.verbose else logging.INFO)

    logging.info("Data downloader")
    get_data([pd.to_datetime(date).date() for date in
              pd.date_range(args.start_date, args.end_date,
                            freq="D")],
             cmip=args.cmip,
             era=args.era,
             osasif=args.osisaf,
             north=args.hemisphere == "north",
             south=args.hemisphere == "south")



