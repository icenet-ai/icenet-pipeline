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
    ap.add_argument("datefile", type=argparse.FileType("r"))

    ap.add_argument("-n", "--n-filters-factor", type=float, default=1.)
    ap.add_argument("-o", "--skip-outputs", default=False, action="store_true")
    ap.add_argument("-t", "--testset", default=False, action="store_true")
    ap.add_argument("-v", "--verbose", action="store_true", default=False)

    return ap.parse_args()


if __name__ == "__main__":
    args = get_args()

    logging.basicConfig(level=logging.DEBUG if args.verbose else logging.INFO)

    dataset_config = \
        os.path.join(".", "dataset_config.{}.json".format(args.dataset))
    
    date_content = args.datefile.read()
    dates = [dt.date(*[int(v) for v in s.split("-")])
             for s in date_content.split()]
    args.datefile.close()

    output_dir = os.path.join(".", "results", "predict",
                              args.output_name,
                              "{}.{}".format(args.network_name, args.seed))
    
    forecasts, gen_outputs = predict_forecast(dataset_config,
                                              args.network_name,
                                              dataset_name=args.dataset,
                                              n_filters_factor=
                                              args.n_filters_factor,
                                              seed=args.seed,
                                              start_dates=dates,
                                              testset=args.testset)

    if os.path.exists(output_dir):
        raise RuntimeError("{} output already exists".format(output_dir))
    os.makedirs(output_dir)
        
    for date, forecast in zip(dates, forecasts):
        output_path = os.path.join(output_dir, date.strftime("%Y_%m_%d.npy"))

        logging.info("Saving {} - forecast output {}".
                     format(date, forecast.shape))
        np.save(output_path, forecast)

    if not args.skip_outputs:
        logging.info("Saving outputs generated for these inputs as well...")
        gen_dir = os.path.join(output_dir, "gen_outputs")
        os.makedirs(gen_dir)

        for date, output in zip(dates, gen_outputs):
            output_path = os.path.join(gen_dir, date.strftime("%Y_%m_%d.npy"))

            logging.info("Saving {} - generated output {}".
                         format(date, output.shape))
            np.save(output_path, output)

