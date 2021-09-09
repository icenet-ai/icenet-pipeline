import argparse
import datetime as dt
import logging
import os
import re

import numpy as np

def get_args():
    # -b 1 -e 1 -w 1 -n 0.125
    ap = argparse.ArgumentParser()
    ap.add_argument("input", type=argparse.FileType("r"))
    ap.add_argument("output_dir", type=str)

    ap.add_argument("-v", "--verbose", action="store_true", default=False)

    return ap.parse_args()


if __name__ == "__main__":
    args = get_args()

    logging.basicConfig(level=logging.DEBUG if args.verbose else logging.INFO)

