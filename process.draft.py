import datetime as dt

import pandas as pd

from icenet2.data.processors.datasets \
    import IceNetERA5PreProcessor, IceNetOSIPreProcessor
from icenet2.data.loader import IceNetDataLoader

if __name__ == "__main__":
    # Processing
    train_dates = [pd.to_datetime(date).date() for date in
                   pd.date_range("1979-01-01",
                                 "2013-12-31", freq="D")]
    val_dates = [pd.to_datetime(date).date() for date in
                 pd.date_range("2014-01-01",
                               "2016-12-31", freq="D")]
    test_dates = [pd.to_datetime(date).date() for date in
                  pd.date_range("2017-01-01",
                                "2020-12-31", freq="D")]

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
