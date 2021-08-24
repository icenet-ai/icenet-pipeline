import datetime as dt
import logging
import os

import numpy as np

from icenet2.model.predict import predict_forecast

if __name__ == "__main__":
    logging.basicConfig(level=logging.DEBUG)
    logging.getLogger("matplotlib").setLevel(logging.WARNING)

    dataset = "test_forecast"
    dataset_config = \
        os.path.join(".", "dataset_config.{}.json".format(dataset))

    forecast = predict_forecast(dataset_config,
                                start_dates=[dt.date(1989, 1, 6)])

    # TODO: save results
