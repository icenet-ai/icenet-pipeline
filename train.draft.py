import argparse
import datetime as dt
import logging
import os

import matplotlib.pyplot as plt
import pandas as pd

from icenet2.model.train import train_model

DATES = {
    "live": [pd.to_datetime(date).date() for date in
             pd.date_range("1979-01-01", dt.datetime.now().date(), freq="D")],
    "test": [pd.to_datetime(date).date() for date in
             pd.date_range("1989-01-01", "1989-01-06", freq="D")],
}

PRESET = {
    "laptop": {
        "batch_size":   1,
        "epochs":       4,
        "workers":      1,
        "use_multiprocessing":  False,
        "n_filters_factor": 1/8,
        "seed":         42,
    },
}

if __name__ == "__main__":
    logging.basicConfig(
        level=logging.DEBUG
    )
    logging.getLogger("matplotlib").setLevel(logging.WARNING)

    ap = argparse.ArgumentParser()
    ap.add_argument("-p", "--preload", default=None)
    args = ap.parse_args()

    cmip = False
    dates = DATES["test"]
    dataset = "test_forecast"
    dataset_config = \
        os.path.join(".", "dataset_config.{}.json".format(dataset))
    preload = args.preload is not None
    pretrain_path = args.preload
    train_args = PRESET["laptop"]

    # CMIP
    if cmip:
        pretrain_path, _ = \
            train_model(dataset_config,
                        network_folder=os.path.join(".", "results", "pretrain"),
                        pre_load_network=preload,
                        preload_path=pretrain_path,
                        **train_args)

    trained_path, history = \
        train_model(dataset_config,
                    pre_load_network=preload,
                    pre_load_path=pretrain_path,
                    **train_args)

    fig, ax = plt.subplots()
    ax.plot(history.history['val_loss'], label='val')
    ax.plot(history.history['loss'], label='train')
    ax.legend(loc='best')
    plot_path = os.path.join(os.path.dirname(trained_path),
                             'network_{}_history.png'.
                             format(train_args["seed"]))
    logging.info("Saving plot to: {}".format(plot_path))
    plt.savefig(plot_path)

