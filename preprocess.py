import cv2
import mediapipe as mp
from mediapipe.tasks import python
from mediapipe.tasks.python import vision
import os
import glob

MODEL_PATH = "blaze_face_short_range.tflite"

base_options = python.BaseOptions(model_asset_path=MODEL_PATH)
options = vision.FaceDetectorOptions(base_options=base_options, min_detection_confidence=0.5)
detector = vision.FaceDetector.create_from_options(options)

INPUT_DIR = "LFW/lfw-deepfunneled/lfw-deepfunneled" 
OUTPUT_DIR = "lfw_cropped/" 
IMG_SIZE = 160 

def crop_faces():
    if not os.path.exists(OUTPUT_DIR):
        os.makedirs(OUTPUT_DIR)

    people_processed = 0
    images_processed = 0

    for person_name in os.listdir(INPUT_DIR):
        person_dir = os.path.join(INPUT_DIR, person_name)
        
        if not os.path.isdir(person_dir):
            continue
            
        image_paths = glob.glob(os.path.join(person_dir, "*.jpg"))
        if len(image_paths) < 3:
            continue

        out_person_dir = os.path.join(OUTPUT_DIR, person_name)
        os.makedirs(out_person_dir, exist_ok=True)
        people_processed += 1

        for img_path in image_paths:
            img = cv2.imread(img_path)
            if img is None:
                continue
                
            img_rgb = cv2.cvtColor(img, cv2.COLOR_BGR2RGB)
            
            mp_image = mp.Image(image_format=mp.ImageFormat.SRGB, data=img_rgb)
            
            results = detector.detect(mp_image)
            
            if results.detections:
                bbox = results.detections[0].bounding_box
                ih, iw, _ = img.shape
                
                x = bbox.origin_x
                y = bbox.origin_y
                w = bbox.width
                h = bbox.height
                
                margin = 20
                x = max(0, x - margin)
                y = max(0, y - margin)
                w = min(iw - x, w + 2*margin)
                h = min(ih - y, h + 2*margin)

                cropped_face = img[y:y+h, x:x+w]
                
                if cropped_face.size > 0 and cropped_face.shape[0] > 0 and cropped_face.shape[1] > 0:
                    resized_face = cv2.resize(cropped_face, (IMG_SIZE, IMG_SIZE))
                    
                    base_name = os.path.basename(img_path)
                    cv2.imwrite(os.path.join(out_person_dir, base_name), resized_face)
                    images_processed += 1

if __name__ == "__main__":
    crop_faces()