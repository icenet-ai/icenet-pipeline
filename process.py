import argparse
import datetime as dt
import collections
import logging
import pprint
import random
import re
import sys

import pandas as pd

from icenet2.data.processors.datasets import \
    IceNetERA5PreProcessor, \
    IceNetHRESPreProcessor, \
    IceNetOSIPreProcessor
from icenet2.data.processors.meta import IceNetMetaPreProcessor
from icenet2.data.loader import IceNetDataLoader


def date_arg(string):
    if string == "none":
        return []

    date_match = re.findall(r"(\d{4})-(\d{1,2})-(\d{1,2})", string)

    if len(date_match) < 1:
        raise argparse.ArgumentError("No dates found for supplied argument {}".
                                     format(string))
    return [dt.date(*[int(s) for s in date_tuple]) for date_tuple in date_match]


def get_args():
    ap = argparse.ArgumentParser()
    ap.add_argument("name", type=str)
    ap.add_argument("hemisphere", choices=("north", "south"))

    ap.add_argument("train_start", type=date_arg)
    ap.add_argument("train_end", type=date_arg)
    ap.add_argument("val_start", type=date_arg)
    ap.add_argument("val_end", type=date_arg)

    ap.add_argument("-ts", "--test-dates", dest="test_start",
                    type=date_arg, required=False, default=[])
    ap.add_argument("-te", "--test-end", dest="test_end",
                    type=date_arg, required=False, default=[])

    ap.add_argument("-d", "--date-ratio", type=float, default=1.0)

    ap.add_argument("-v", "--verbose", action="store_true", default=False)

    ap.add_argument("-l", "--lag", type=int, default=2)

    ap.add_argument("-fn", "--forecast-name", dest="forecast_name",
                    default=None, type=str)
    ap.add_argument("-fd", "--forecast-days", dest="forecast_days",
                    default=93, type=int)

    ap.add_argument("-se", "--skip-era", dest="skip_era",
                    default=False, action="store_true")
    ap.add_argument("-so", "--skip-osi", dest="skip_osi",
                    default=False, action="store_true")
    ap.add_argument("-sp", "--skip-process", dest="skip_process",
                    default=False, action="store_true")
    ap.add_argument("-sm", "--skip-meta", dest="skip_meta",
                    default=False, action="store_true")
    ap.add_argument("-eh", "--enable-hres", dest="enable_hres",
                    default=False, action="store_true")

    ap.add_argument("-ob", "--output-batch-size", dest="batch_size", type=int,
                    default=8)
    ap.add_argument("-w", "--workers", help="Number of workers to use "
                                            "generating sets",
                    type=int, default=8)

    return ap.parse_args()


if __name__ == "__main__":
    args = get_args()

    logging.basicConfig(level=logging.DEBUG if args.verbose else logging.INFO)

    dates = dict(train=[], val=[], test=[])

    for dataset in ("train", "val", "test"):
        dataset_dates = collections.deque()

        for i, period_start in \
                enumerate(getattr(args, "{}_start".format(dataset))):
            period_end = getattr(args, "{}_end".format(dataset))[i]
            dataset_dates += [pd.to_datetime(date).date() for date in
                   pd.date_range(period_start,
                                 period_end, freq="D")]
        logging.info("Generated {} dates for {}".format(len(dataset_dates),
                                                        dataset))

        num_dates = len(dataset_dates) * args.date_ratio
        random.shuffle(dataset_dates)

        while len(dataset_dates) > num_dates:
            f = dataset_dates.pop \
                if len(dataset_dates) % 2 == 0 \
                else dataset_dates.popleft
            f()

        logging.info("After reduction we have {} {} dates".
                     format(len(dataset_dates), dataset))
        dates[dataset] = sorted(list(dataset_dates))

    if not args.skip_era:
        pp = IceNetERA5PreProcessor(
            ["uas", "vas"],
            ["tas", "ta500", "tos", "psl", "zg500", "zg250", "rsds", "rlds",
             "hus1000"],
            args.name,
            dates["train"],
            dates["val"],
            dates["test"],
            linear_trends=tuple(),
        )
        pp.init_source_data(
            lag_days=args.lag,
        )
        pp.process()

    if not args.skip_osi:
        osi = IceNetOSIPreProcessor(
            ["siconca"],
            [],
            args.name,
            dates["train"],
            dates["val"],
            dates["test"],
            linear_trends=["siconca"],
            linear_trend_days=args.forecast_days,
        )
        osi.init_source_data(
            lag_days=args.lag,
            lead_days=args.forecast_days,
        )
        osi.process()

    if args.enable_hres:
        if not args.skip_era or not args.skip_osi:
            raise RuntimeError("Don't try to produce datasets from HRES with "
                               "OSI and ERA5, this won't be a problem when "
                               "things are properly CLI oriented")

        hres_clim = IceNetHRESPreProcessor(
            ["uas", "vas"],
            ["tas", "ta500", "tos", "psl", "zg500", "zg250", "rsds", "rlds",
             "hus1000"],
            args.name,
            dates["train"],
            dates["val"],
            dates["test"],
            linear_trends=tuple(),
        )
        hres_clim.init_source_data(
            lag_days=args.lag,
        )
        hres_clim.process()

        hres_osi = IceNetHRESPreProcessor(
            ["siconca"],
            [],
            args.name,
            dates["train"],
            dates["val"],
            dates["test"],
            linear_trends=["siconca"],
            linear_trend_days=args.forecast_days,
            # TODO: should reconsider the process for double usage (overrides?)
            #  though this does work as is, which is nice
            update_key="mars.siconca"
        )
        hres_osi.init_source_data(
            lag_days=args.lag,
            lead_days=args.forecast_days,
        )
        hres_osi.process()

    if not args.skip_meta:
        IceNetMetaPreProcessor(
            args.name,
        ).process()

    if not args.skip_process:
        dl = IceNetDataLoader("loader.{}.json".format(args.name),
                              args.forecast_name
                              if args.forecast_name else args.name,
                              args.lag,
                              north=args.hemisphere == "north",
                              south=args.hemisphere == "south",
                              output_batch_size=args.batch_size,
                              generate_workers=args.workers)
        dl.generate()
