import logging
logging.basicConfig(level=logging.DEBUG)
import tensorflow as tf
import intel_extension_for_tensorflow as itex

# https://www.tensorflow.org/guide/keras/distributed_training

# Create a MirroredStrategy.
gpus = tf.config.list_physical_devices('XPU')
print("XPU count is {}".format(len(gpus)))
gpu_ids = []
for gpu in gpus:
    print("Setting memory growth for XPU: {}".format(gpu))
    #tf.config.experimental.set_memory_growth(gpu, True)
    gpu_ids.append(gpu.name[-5:])

strategy = tf.distribute.MirroredStrategy(gpu_ids, cross_device_ops=itex.distribute.ItexAllReduce(1))
print('Number of devices: {}'.format(strategy.num_replicas_in_sync))


from icenet.model.train import train_model
from icenet.data.dataset import IceNetDataSet
import icenet.model.losses as losses
import icenet.model.metrics as metrics
import icenet.model.models as models


dataset = IceNetDataSet("dataset_config.exp23_south.json", batch_size=16, shuffling=False)
input_shape = (*dataset.shape, dataset.num_channels)

with strategy.scope():
    loss = losses.WeightedMSE()
    metrics_list = [
        # metrics.weighted_MAE,
        #metrics.WeightedBinaryAccuracy(),
        #metrics.WeightedMAE(),
        #metrics.WeightedRMSE(),
        losses.WeightedMSE()
    ]
    network = models.unet_batchnorm(
        input_shape=input_shape,
        loss=loss,
        metrics=metrics_list,
        filter_size=3,
        n_filters_factor=1.44,
        n_forecast_days=dataset.n_forecast_days,
    )

network.summary()
train_ds, val_ds, test_ds = dataset.get_split_datasets(ratio=1.0)

model_history = network.fit(
        #strategy.experimental_distribute_dataset(train_ds),
        train_ds,
        epochs=5,
        steps_per_epoch=731,
        verbose=1,
        callbacks=[],
        validation_data=val_ds)
        #validation_data=strategy.experimental_distribute_dataset(val_ds),
        #max_queue_size=10)
