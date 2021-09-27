import argparse
import datetime as dt
import logging
import re

import pandas as pd

from icenet2.data.processors.datasets \
    import IceNetERA5PreProcessor, IceNetOSIPreProcessor
from icenet2.data.loader import IceNetDataLoader


def date_arg(string):
    date_match = re.search(r"(\d{4})-(\d{1,2})-(\d{1,2})", string)
    return dt.date(*[int(s) for s in date_match.groups()])


def get_args():
    ap = argparse.ArgumentParser()
    ap.add_argument("name", type=str)
    ap.add_argument("hemisphere", choices=("north", "south"))

    # TODO: change this to a CSV based system: start,end,skip for each set
    ap.add_argument("train_start", type=date_arg)
    ap.add_argument("train_end", type=date_arg)
    ap.add_argument("val_start", type=date_arg)
    ap.add_argument("val_end", type=date_arg)

    ap.add_argument("-ts", "--test-dates", dest="test_start",
                    type=date_arg, required=False, default=None)
    ap.add_argument("-te", "--test-end", dest="test_end",
                    type=date_arg, required=False, default=None)

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

    ap.add_argument("-ob", "--output-batch-size", dest="batch_size", type=int,
                    default=8)
    ap.add_argument("-w", "--workers", help="Number of workers to use "
                                            "generating sets",
                    type=int, default=8)

    return ap.parse_args()


if __name__ == "__main__":
    args = get_args()

    logging.basicConfig(level=logging.DEBUG if args.verbose else logging.INFO)

    # Processing
    # python src/IceNet-Pipeline/process.draft.py -v -ob 2 -l 3 -fn small_proc2 -ts 2010-01-01 -te 2010-01-31 small north 2001-01-01 2002-12-31 2010-12-01 2010-12-31 2>&1 | tee logs/process.small_proc2.log
    train_dates = [pd.to_datetime(date).date() for date in
                   pd.date_range(args.train_start,
                                 args.train_end, freq="D")]
    val_dates = [pd.to_datetime(date).date() for date in
                 pd.date_range(args.val_start,
                               args.val_end, freq="D")]

    test_dates = []

    if args.test_start and args.test_end:
        test_dates = [pd.to_datetime(date).date() for date in
                      pd.date_range(args.test_start,
                                    args.test_end, freq="D")]

    if not args.skip_era:
        pp = IceNetERA5PreProcessor(
            ["uas", "vas"],
            ["tas", "ta500", "tos", "psl", "zg500", "zg250", "rsds", "rlds",
             "hus1000"],
            args.name,
            train_dates,
            val_dates,
            test_dates,
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
            train_dates,
            val_dates,
            test_dates,
            # TODO: move circday/land to IceNetMetaPreProcessor
            include_circday=False,
            include_land=False,
            linear_trends=["siconca"],
            linear_trend_days=args.forecast_days,
        )
        osi.init_source_data(
            lag_days=args.lag,
            lead_days=args.forecast_days,
        )
        osi.process()

    dl = IceNetDataLoader("loader.{}.json".format(args.name),
                          args.forecast_name
                          if args.forecast_name else args.name,
                          args.lag,
                          north=args.hemisphere == "north",
                          south=args.hemisphere == "south",
                          output_batch_size=args.batch_size,
                          generate_workers=args.workers)
    dl.generate()
