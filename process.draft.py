from icenet2.data.processors.datasets \
    import IceNetERA5PreProcessor, IceNetOSIPreProcessor
from icenet2.data.loader import IceNetDataLoader

if __name__ == "__main__":
    # Processing

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
