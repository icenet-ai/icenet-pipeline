import argparse
import concurrent.futures, pprint, glob
import numpy as np

def check(path):
    nans = []
    files = glob.glob("{}/*.npy".format(path))
    print("{} {} files".format(path, len(files)))
    for f in files:
        s = np.sum(np.isnan(np.load(f)) == True)
        if s > 0:
            nans.append((f, s))
    return nans

if __name__ == "__main__":

    futures = []
    var_paths = [
        "processed/south_40/era5/sh/uas",
        "processed/south_40/era5/sh/vas",
        "processed/south_40/era5/sh/tas", 
        "processed/south_40/era5/sh/ta500", 
        "processed/south_40/era5/sh/tos", 
        "processed/south_40/era5/sh/psl", 
        "processed/south_40/era5/sh/zg500", 
        "processed/south_40/era5/sh/zg250", 
        "processed/south_40/era5/sh/rsds", 
        "processed/south_40/era5/sh/rlds", 
        "processed/south_40/era5/sh/hus1000", 
        "processed/south_40/osisaf/sh/siconca",
        "processed/south_40/meta/sh/cos",
        "processed/south_40/meta/sh/sin",
        "processed/south_40/meta/sh/land",
    ]

    with concurrent.futures.ProcessPoolExecutor() as executor:
        for var_path in var_paths:
            futures.append(executor.submit(check, var_path))
        for f in futures:
            pprint.pprint(f.result())
