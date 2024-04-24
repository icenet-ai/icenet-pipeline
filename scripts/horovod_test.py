import logging
logging.basicConfig(level=logging.DEBUG)
import tensorflow as tf
import horovod.tensorflow.keras as hvd
from tensorflow.keras.optimizers import Adam

hvd.init()

# https://www.tensorflow.org/guide/keras/distributed_training

# Create a MirroredStrategy.
gpus = tf.config.list_physical_devices('XPU')
print("XPU count is {}".format(len(gpus)))
gpu_ids = []
for gpu in gpus:
    tf.config.experimental.set_memory_growth(gpu, True)
if gpus:
    tf.config.experimental.set_visible_devices(gpus[hvd.local_rank()], 'XPU')

from icenet.data.dataset import IceNetDataSet
import icenet.model.losses as losses
import icenet.model.metrics as metrics
import icenet.model.models as models


dataset = IceNetDataSet("dataset_config.exp23_north.json", batch_size=8, shuffling=False)
input_shape = (*dataset.shape, dataset.num_channels)

loss = losses.WeightedMSE()
metrics_list = [
        # metrics.weighted_MAE,
        #metrics.WeightedBinaryAccuracy(),
        #metrics.WeightedMAE(),
        #metrics.WeightedRMSE(),
    losses.WeightedMSE()
]
network = models.unet_batchnorm(
    custom_optimizer=hvd.DistributedOptimizer(Adam(1e5)),
    experimental_run_tf_function=False,
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
        steps_per_epoch=731 // hvd.size(),
        verbose=1 if hvd.rank() == 0 else 0,
        callbacks=[
            hvd.callbacks.BroadcastGlobalVariablesCallback(0),    
        ],
        validation_data=val_ds)
        #validation_data=strategy.experimental_distribute_dataset(val_ds),
        #max_queue_size=10)
