import tensorflow as tf
from feature_embedding import build_embedding_model

model = build_embedding_model(input_shape=(160, 160, 3))
model.load_weights('best_extractor_only.weights.h5')

converter = tf.lite.TFLiteConverter.from_keras_model(model)

converter.optimizations = [tf.lite.Optimize.DEFAULT]
converter.target_spec.supported_types = [tf.float16]

tflite_model = converter.convert()

tflite_filename = "face_embedding_model.tflite"
with open(tflite_filename, "wb") as f:
    f.write(tflite_model)