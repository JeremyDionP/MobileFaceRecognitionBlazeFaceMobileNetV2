import cv2
import numpy as np
import tensorflow as tf
import mediapipe as mp
import os
import csv
import time
import matplotlib.pyplot as plt
import seaborn as sns
from mediapipe.tasks import python
from mediapipe.tasks.python import vision

interpreter = tf.lite.Interpreter(model_path="face_embedding_model_v2.tflite")
interpreter.allocate_tensors()
input_details = interpreter.get_input_details()
output_details = interpreter.get_output_details()

base_options = python.BaseOptions(model_asset_path="blaze_face_short_range.tflite")
options = vision.FaceDetectorOptions(base_options=base_options, min_detection_confidence=0.5)
detector = vision.FaceDetector.create_from_options(options)

IMG_SIZE = 160
THRESHOLD = 0.45
DATASET_PATH = "orl_dataset" 

def extract_feature_vector(img_path):
    img = cv2.imread(img_path)
    if img is None:
        return None
        
    img_rgb = cv2.cvtColor(img, cv2.COLOR_BGR2RGB)
    mp_image = mp.Image(image_format=mp.ImageFormat.SRGB, data=img_rgb)
    results = detector.detect(mp_image)
    
    if not results.detections:
        return None
        
    bbox = results.detections[0].bounding_box
    ih, iw, _ = img.shape
    x, y, w, h = bbox.origin_x, bbox.origin_y, bbox.width, bbox.height
    
    margin = 20
    x = max(0, x - margin)
    y = max(0, y - margin)
    w = min(iw - x, w + 2*margin)
    h = min(ih - y, h + 2*margin)
    
    cropped_face = img[y:y+h, x:x+w]
    if cropped_face.size == 0 or cropped_face.shape[0] <= 0 or cropped_face.shape[1] <= 0:
        return None
        
    resized_face = cv2.resize(cropped_face, (IMG_SIZE, IMG_SIZE))
    normalized_face = (cv2.cvtColor(resized_face, cv2.COLOR_BGR2RGB) / 127.5) - 1.0
    input_tensor = np.expand_dims(normalized_face, axis=0).astype(np.float32)
    
    interpreter.set_tensor(input_details[0]['index'], input_tensor)
    interpreter.invoke()
    vector = interpreter.get_tensor(output_details[0]['index'])[0]
    
    return vector

def run_evaluation():
    database = {}
    csv_data = [["Image Name", "Test Type", "Expected", "Actual", "Result Category", "Latency (ms)"]]
    
    TP = 0
    FN = 0
    TN = 0
    FP = 0
    total_latency = 0.0
    successful_extractions = 0
    
    for i in range(1, 11):
        subject = f"s{i}"
        img_path = os.path.join(DATASET_PATH, subject, "1.pgm")
        if os.path.exists(img_path):
            vec = extract_feature_vector(img_path)
            if vec is not None:
                database[subject] = vec
    
    for i in range(1, 11):
        subject = f"s{i}"
        for img_num in range(2, 11):
            img_path = os.path.join(DATASET_PATH, subject, f"{img_num}.pgm")
            if not os.path.exists(img_path): continue
            
            start_time = time.time()
            live_vector = extract_feature_vector(img_path)
            latency = round((time.time() - start_time) * 1000, 2)
            
            if live_vector is None:
                csv_data.append([f"{subject}_{img_num}", "Authorized", "Accept", "No Face Found", "FN", latency])
                FN += 1
                continue
                
            total_latency += latency
            successful_extractions += 1
            
            lowest_distance = float('inf')
            for db_name, db_vector in database.items():
                dist = float(np.linalg.norm(db_vector - live_vector))
                if dist < lowest_distance:
                    lowest_distance = dist
            
            if lowest_distance <= THRESHOLD:
                csv_data.append([f"{subject}_{img_num}", "Authorized", "Accept", "Granted", "TP", latency])
                TP += 1
            else:
                csv_data.append([f"{subject}_{img_num}", "Authorized", "Accept", "Denied", "FN", latency])
                FN += 1

    for i in range(11, 41):
        subject = f"s{i}"
        for img_num in range(1, 11):
            img_path = os.path.join(DATASET_PATH, subject, f"{img_num}.pgm")
            if not os.path.exists(img_path): continue
            
            start_time = time.time()
            live_vector = extract_feature_vector(img_path)
            latency = round((time.time() - start_time) * 1000, 2)
            
            if live_vector is None:
                csv_data.append([f"{subject}_{img_num}", "Imposter", "Reject", "No Face Found", "TN", latency])
                TN += 1
                continue
                
            total_latency += latency
            successful_extractions += 1
            
            lowest_distance = float('inf')
            for db_name, db_vector in database.items():
                dist = float(np.linalg.norm(db_vector - live_vector))
                if dist < lowest_distance:
                    lowest_distance = dist
                    
            if lowest_distance <= THRESHOLD:
                csv_data.append([f"{subject}_{img_num}", "Imposter", "Reject", "Granted", "FP", latency])
                FP += 1
            else:
                csv_data.append([f"{subject}_{img_num}", "Imposter", "Reject", "Denied", "TN", latency])
                TN += 1

    with open("dissertation_results.csv", "w", newline="") as f:
        writer = csv.writer(f)
        writer.writerows(csv_data)
        
    
    total = TP + TN + FP + FN
    if total == 0:
        return
    
    plt.figure(figsize=(7, 5))
    matrix = np.array([[TN, FP], [FN, TP]])
    sns.heatmap(matrix, annot=True, fmt='d', cmap='Blues', 
                xticklabels=['Predicted Reject', 'Predicted Accept'],
                yticklabels=['Actual Unauthorized', 'Actual Authorized'])
    
    plt.title(f'BlazeFace MobileNetV2 Confusion Matrix')
    plt.ylabel('True Class')
    plt.xlabel('Predicted Class')
    plt.tight_layout()
    plt.savefig('confusion_matrix.png', dpi=300)

if __name__ == "__main__":
    run_evaluation()