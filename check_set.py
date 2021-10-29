import argparse
import glob
import json
import logging
import os
import subprocess

import numpy as np
import tensorflow as tf

from icenet2.data.loader import get_decoder
from icenet2.data.loader import IceNetDataSet

import matplotlib.pyplot as plt
import datetime as dt

logging.getLogger().setLevel(logging.DEBUG)
logging.getLogger("matplotlib").setLevel(logging.WARNING)


def parse_args():
    ap = argparse.ArgumentParser()
    ap.add_argument("configuration", type=argparse.FileType("r"))

    return ap.parse_args()


def main(args):
    ds = IceNetDataSet(args.configuration, batch_size=1)
    train_ds, val_ds, test_ds = ds.get_split_datasets()

    for name, dataset in [("train", train_ds), ("val", val_ds), ("test", test_ds)]:
        it = dataset.as_numpy_iterator()

        for data in it:
            x, y, sample_weights = data
            logging.debug("x {}".format(x.shape))
            logging.debug("y {}".format(y.shape))
            logging.debug("sample_weights {}".format(sample_weights.shape))

if __name__ == "__main__":
    main(parse_args())
