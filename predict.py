import argparse
import datetime as dt
import logging
import os
import re

import numpy as np

from icenet2.model.predict import predict_forecast


def date_arg(string):
    date_match = re.search(r"(\d{4})-(\d{1,2})-(\d{1,2})", string)
    return dt.date(*[int(s) for s in date_match.groups()])


def get_args():
    # -b 1 -e 1 -w 1 -n 0.125
    ap = argparse.ArgumentParser()
    ap.add_argument("dataset", type=str)
    ap.add_argument("network_name", type=str)
    ap.add_argument("output_name", type=str)
    ap.add_argument("seed", type=int, default=42)
    ap.add_argument("dates", type=date_arg, nargs="+")

    ap.add_argument("-n", "--n-filters-factor", type=float, default=1.)

    ap.add_argument("-v", "--verbose", action="store_true", default=False)

    return ap.parse_args()


if __name__ == "__main__":
    args = get_args()

    logging.basicConfig(level=logging.DEBUG if args.verbose else logging.INFO)

    dataset_config = \
        os.path.join(".", "dataset_config.{}.json".format(args.dataset))
    dates = [*args.dates]
    output_dir = os.path.join(".", "results", "predict",
                              args.output_name,
                              "{}.{}".format(args.network_name, args.seed))

    forecasts = predict_forecast(dataset_config,
                                 args.network_name,
                                 n_filters_factor=args.n_filters_factor,
                                 seed=args.seed,
                                 start_dates=dates)

    if os.path.exists(output_dir):
        raise RuntimeError("{} output already exists".format(output_dir))
    os.makedirs(output_dir)
        
    for date, forecast in zip(dates, forecasts):
        output_path = os.path.join(output_dir, date.strftime("%Y_%m_%d.npy"))

        logging.info("Saving {} - output {}".format(date, forecast.shape))
        np.save(output_path, forecast)

