def main():
    import logging
    logging.basicConfig(level=logging.DEBUG)
    import tensorflow as tf, numpy as np
    # tf.config.run_functions_eagerly(True)
    from icenet.model.train import train_model
    from icenet.data.dataset import IceNetDataSet
    import icenet.model.losses as losses
    import icenet.model.metrics as metrics
    import icenet.model.models as models
    from tensorflow.keras.models import Model
    from tensorflow.keras.layers import Conv2D, BatchNormalization, UpSampling2D, \
        concatenate, MaxPooling2D, Input
    from tensorflow.keras.optimizers import Adam
    # Create a MirroredStrategy.
    gpus = tf.config.list_physical_devices('XPU')
    print("XPU count is {}".format(len(gpus)))
    gpu_ids = []
    for gpu in gpus:
        print("Setting memory growth for XPU: {}".format(gpu))
        tf.config.experimental.set_memory_growth(gpu, True)
        gpu_ids.append(gpu.name[-5:])
    strategy = tf.distribute.MirroredStrategy(gpu_ids)
    print('Number of devices: {}'.format(strategy.num_replicas_in_sync))
    #dataset = IceNetDataSet("dataset_config.exp23_south.json", batch_size=32, shuffling=False)
    #input_shape = (*dataset.shape, dataset.num_channels)
    (mnist_images, mnist_labels), _ = \
        tf.keras.datasets.mnist.load_data(path='mnist.npz')
    dataset = tf.data.Dataset.from_tensor_slices(
        ((mnist_images[..., tf.newaxis] / 255.0).astype(np.float32),
        tf.cast(mnist_labels, tf.int32)))
    dataset = dataset.repeat().shuffle(1000).batch(1000)
    with strategy.scope():
        #loss = losses.WeightedMSE()
        #metrics_list = [
        #    losses.WeightedMSE()
        #]
        model = tf.keras.Sequential([
            tf.keras.layers.Input(shape=(28, 28, 1,)),
            tf.keras.layers.Conv2D(32, [3, 3], activation='relu'),
            tf.keras.layers.Conv2D(64, [3, 3], activation='relu'),
            tf.keras.layers.MaxPooling2D(pool_size=(2, 2)),
            tf.keras.layers.Dropout(0.25),
            tf.keras.layers.Flatten(),
            tf.keras.layers.Dense(128, activation='relu'),
            tf.keras.layers.Dropout(0.5),
            tf.keras.layers.Dense(10, activation='softmax')
        ])
        opt = tf.optimizers.Adam(0.001)
        model.compile(loss=tf.losses.SparseCategoricalCrossentropy(),
                        optimizer=opt,
                        metrics=['accuracy'],
                        experimental_run_tf_function=False)
    model.summary()
    tboard_callback = tf.keras.callbacks.TensorBoard(log_dir = "tensorboard",
                                                     histogram_freq = 1,
                                                     profile_batch = 5)
    #train_ds, val_ds, test_ds = dataset.get_split_datasets(ratio=1.0)
    #model_history = network.fit(
    #        train_ds,
    #        epochs=5,
    #        verbose=2,
    #        callbacks=list(),
    #        validation_data=val_ds)
    model.fit(dataset, epochs=12, verbose=1, steps_per_epoch=50, callbacks=[tboard_callback])
