import argparse
import logging
import os
import pickle

import tensorflow as tf

from icenet2.model.train import train_model


def get_args():
    # -b 1 -e 1 -w 1 -n 0.125
    ap = argparse.ArgumentParser()
    ap.add_argument("dataset", type=str)
    ap.add_argument("run_name", type=str)
    ap.add_argument("seed", type=int)

    ap.add_argument("-v", "--verbose", action="store_true", default=False)

    ap.add_argument("-b", "--batch-size", type=int, default=4)
    ap.add_argument("-e", "--epochs", type=int, default=4)
    ap.add_argument("-m", "--multiprocessing", action="store_true",
                    default=False)
    ap.add_argument("-n", "--n-filters-factor", type=float, default=1.)
    ap.add_argument("-p", "--preload", type=str)
    ap.add_argument("-qs", "--max-queue-size", default=10, type=int)
    ap.add_argument("-r", "--ratio", default=None, type=float)
    ap.add_argument("-s", "--strategy", default="default",
                    choices=("default", "mirrored", "central"))
    ap.add_argument("--gpus", default=None)
    ap.add_argument("-w", "--workers", type=int, default=4)

    return ap.parse_args()


if __name__ == "__main__":
    args = get_args()

    logging.basicConfig(level=logging.DEBUG if args.verbose else logging.INFO)

    dataset_config = \
        os.path.join(".", "dataset_config.{}.json".format(args.dataset))

    strategy = tf.distribute.MirroredStrategy() \
        if args.strategy == "mirrored" \
        else tf.distribute.experimental.CentralStorageStrategy() \
        if args.strategy == "central" \
        else tf.distribute.get_strategy()

    trained_path, history = \
        train_model(args.run_name,
                    dataset_config,
                    pre_load_network=args.preload is not None,
                    pre_load_path=args.preload,
                    batch_size=args.batch_size,
                    epochs=args.epochs,
                    workers=args.workers,
                    use_multiprocessing=args.multiprocessing,
                    n_filters_factor=args.n_filters_factor,
                    seed=args.seed,
                    strategy=strategy,
                    max_queue_size=args.max_queue_size,
                    dataset_ratio=args.ratio)

#    fig, ax = plt.subplots()
#    ax.plot(history.history['val_loss'], label='val')
#    ax.plot(history.history['loss'], label='train')
#    ax.legend(loc='best')
#    plot_path = os.path.join(os.path.dirname(trained_path),
#                             'network_{}_history.png'.
#                             format(args.seed))
#    logging.info("Saving plot to: {}".format(plot_path))
#    plt.savefig(plot_path)

    history_path = os.path.join(os.path.dirname(trained_path),
                                "{}_{}_history.pkl".
                                format(args.run_name, args.seed))
    with open(history_path, 'wb') as fh:
        pickle.dump(history.history, fh)

