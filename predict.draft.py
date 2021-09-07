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
    dates = [dt.date(1989, 1, 4)]
    output_id = "test_prediction"
    output_dir = os.path.join(".", "results", output_id)

    forecasts = predict_forecast(dataset_config,
                                 start_dates=dates)

    if os.path.exists(output_dir):
        raise RuntimeError("{} output already exists".format(output_dir))
    os.makedirs(output_dir, exist_ok=True)
        
    for date, forecast in zip(dates, forecasts):
        output_path = os.path.join(output_dir, date.strftime("%Y_%m_%d.npy"))

        logging.info("Saving {} - output {}".format(date, forecast.shape))
        np.save(output_path, forecast)

