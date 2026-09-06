import tensorflow as tf
from tensorflow.keras.applications import MobileNetV2
from tensorflow.keras.layers import GlobalAveragePooling2D, Dense, Lambda
from tensorflow.keras.models import Model
from tensorflow.keras.layers import Input
import os
import random
import numpy as np
import cv2
import matplotlib.pyplot as plt

def build_embedding_model(input_shape=(160, 160, 3)): 
    base_model = MobileNetV2(input_shape=input_shape, 
                             include_top=False, 
                             weights='imagenet')
    
    base_model.trainable = True 

    for layer in base_model.layers:
        if 'BatchNormalization' in layer.__class__.__name__:
            layer.trainable = False

    x = base_model.output
    x = GlobalAveragePooling2D()(x)
    x = Dense(128, activation=None)(x)
    
    outputs = Lambda(lambda t: tf.math.l2_normalize(t, axis=1), name="L2_Norm")(x)

    model = Model(inputs=base_model.input, outputs=outputs, name="Face_Embedding_Model")
    return model

class TripletLossLayer(tf.keras.losses.Loss):
    def __init__(self, alpha=0.5, **kwargs):
        super().__init__(**kwargs)
        self.alpha = alpha

    def call(self, y_true, y_pred):
        anchor = y_pred[:, 0, :]
        positive = y_pred[:, 1, :]
        negative = y_pred[:, 2, :]

        pos_dist = tf.reduce_sum(tf.square(anchor - positive), axis=-1)
        neg_dist = tf.reduce_sum(tf.square(anchor - negative), axis=-1)
        
        basic_loss = pos_dist - neg_dist + self.alpha
        loss = tf.maximum(basic_loss, 0.0)
        
        return loss
    
def triplet_accuracy(y_true, y_pred):
    anchor = y_pred[:, 0, :]
    positive = y_pred[:, 1, :]
    negative = y_pred[:, 2, :]

    pos_dist = tf.reduce_sum(tf.square(anchor - positive), axis=-1)
    neg_dist = tf.reduce_sum(tf.square(anchor - negative), axis=-1)
    
    is_correct = tf.cast(tf.less(pos_dist, neg_dist), tf.float32)
    return tf.reduce_mean(is_correct)

class TripletDataGenerator(tf.keras.utils.Sequence):
    def __init__(self, directory, batch_size=32, **kwargs):
        super().__init__(**kwargs)
        self.directory = directory
        self.batch_size = batch_size
        
        all_classes = [d for d in os.listdir(directory) if os.path.isdir(os.path.join(directory, d))]
        
        self.class_images = {}
        for person in all_classes:
            img_paths = os.listdir(os.path.join(directory, person))
            if len(img_paths) >= 2: 
                self.class_images[person] = [os.path.join(directory, person, img) for img in img_paths]
        
        self.valid_classes = list(self.class_images.keys())

    def __len__(self):
        return 100

    def __getitem__(self, index):
        anchors = []
        positives = []
        negatives = []
        
        for _ in range(self.batch_size):
            person_a = random.choice(self.valid_classes)
            person_b = random.choice(self.valid_classes)
            while person_b == person_a:
                person_b = random.choice(self.valid_classes)
            
            img_a1, img_a2 = random.sample(self.class_images[person_a], 2)
            img_b = random.choice(self.class_images[person_b])
            
            anchors.append(self._load_image(img_a1))
            positives.append(self._load_image(img_a2))
            negatives.append(self._load_image(img_b))
            
        x_inputs = (np.array(anchors), np.array(positives), np.array(negatives))
        y_target = np.zeros((self.batch_size,))
        
        return x_inputs, y_target

    def _load_image(self, path):
        img = cv2.imread(path)
        img = cv2.cvtColor(img, cv2.COLOR_BGR2RGB)
        
        if random.random() > 0.5:
            img = cv2.flip(img, 1)

        value = random.uniform(0.8, 1.2)
        hsv = cv2.cvtColor(img, cv2.COLOR_RGB2HSV)
        hsv = np.array(hsv, dtype = np.float64)
        hsv[:,:,1] = hsv[:,:,1]*value
        hsv[:,:,1][hsv[:,:,1]>255]  = 255
        hsv[:,:,2] = hsv[:,:,2]*value 
        hsv[:,:,2][hsv[:,:,2]>255]  = 255
        hsv = np.array(hsv, dtype = np.uint8)
        img = cv2.cvtColor(hsv, cv2.COLOR_HSV2RGB)

        img = (img / 127.5) - 1.0 
        return img
    
if __name__ == "__main__":
    embedding_model = build_embedding_model()

    anchor_input = Input(name="anchor", shape=(160, 160, 3))
    positive_input = Input(name="positive", shape=(160, 160, 3))
    negative_input = Input(name="negative", shape=(160, 160, 3))

    emb_a = embedding_model(anchor_input)
    emb_p = embedding_model(positive_input)
    emb_n = embedding_model(negative_input)

    model_output = Lambda(lambda x: tf.stack(x, axis=1), name="Stack_Layer")([emb_a, emb_p, emb_n])


    model = Model(
        inputs=[anchor_input, positive_input, negative_input], 
        outputs=model_output, 
        name="Model_Network"
    )

    model.summary()


    model.compile(
        optimizer=tf.keras.optimizers.Adam(learning_rate=0.00005), 
        loss=TripletLossLayer(alpha=0.5),
        metrics=[triplet_accuracy]
    )

    train_generator = TripletDataGenerator(directory="lfw_cropped/", batch_size=32)

    checkpoint = tf.keras.callbacks.ModelCheckpoint(
        filepath="best_face_embedding_model.weights.h5", 
        monitor="loss", 
        save_best_only=True, 
        save_weights_only=True,
        verbose=1
    )

    history = model.fit(
        train_generator,
        epochs=100, 
        callbacks=[checkpoint]
    )

    embedding_model.save("best_extractor_only.weights.h5")