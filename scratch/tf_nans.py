#!/usr/bin/env python

import tensorflow as tf
import argparse, glob, os, logging, sys
import numpy as np

from icenet2.data.dataset import IceNetDataSet, get_decoder

def main(dataset):
    ds = IceNetDataSet(dataset)
    decoder = get_decoder(ds.shape, ds.num_channels, ds.n_forecast_days)

    for dset in ["train", "val", "test"]:
        logging.info("Studying dataset {}".format(dset))

        files = getattr(ds, "{}_fns".format(dset))

        if not len(files):
            continue

        logging.info("{} files".format(len(files)))
        tfds = tf.data.TFRecordDataset(files)
        tfds = tfds.map(decoder)
        i = 0

        for x, y, s in tfds:
            x, y, s = x.numpy(), y.numpy(), s.numpy()
            logging.info("{} {} {}".format(x.shape, y.shape, s.shape))

            for c in range(0, ds.num_channels):
                channel_nan = np.sum(np.isnan(x[..., c]) == True)
                if channel_nan > 0:
                    logging.info("{} = {} nans".format(channels[c], channel_nan))

            y_nan = np.sum(np.isnan(y) == True)

            if y_nan:
                logging.info("output = {} nans".format(y_nan))
                
            s_nan = np.sum(np.isnan(s) == True)

            if s_nan:
                logging.info("sample = {} nans".format(s_nan))
            i += 1


if __name__ == "__main__":
    logging.basicConfig(level=logging.DEBUG)
    ap = argparse.ArgumentParser()
    ap.add_argument("dataset")
    args = ap.parse_args()
    main(args.dataset)
