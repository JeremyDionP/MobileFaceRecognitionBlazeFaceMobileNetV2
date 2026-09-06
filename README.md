# Fast and Efficient Mobile Face Recognition System

A fully offline Android face recognition system combining **MediaPipe BlazeFace** for face detection and **MobileNetV2** for feature embedding. All inference — detection, embedding, and matching — runs entirely on-device via TensorFlow Lite, with no biometric data transmitted to any external server.

This repository contains the Python model training/evaluation pipeline and the Flutter Android application.

---

## Overview

| Stage | Component | Purpose |
|---|---|---|
| Detection | MediaPipe BlazeFace | Locates the face and produces a bounding box in a single shot |
| Feature Embedding | MobileNetV2 (trained with Triplet Loss) | Converts the cropped face into a 128-dimensional feature vector |
| Recognition | Euclidean Distance | Compares the live vector against locally stored vectors to grant or reject access |

---

## Repository Structure

```
.
├── preprocess.py                    # Prepares the LFW dataset for training
├── feature_embedding.py             # Trains the MobileNetV2 embedding model
├── convertion.py                    # Converts trained Keras weights to TFLite
├── proposed_model_evaluation.py     # Runs desktop evaluation of the proposed pipeline
├── android_app/                     # Flutter mobile application
│   └── assets/models/               # Destination for the .tflite model files
└── README.md
```

> Update the tree above if your actual folder names differ — this reflects the structure implied by the setup steps below.

---

## Prerequisites

- Python 3.9+ with `pip`
- TensorFlow / Keras
- OpenCV (`opencv-python`)
- MediaPipe
- Flutter SDK (for building the Android app)
- Android device or emulator for testing
- A [Kaggle account](https://www.kaggle.com) (to download the datasets below)

Install Python dependencies:

```bash
pip install -r requirements.txt
```

> If a `requirements.txt` isn't included yet, add one listing at minimum: `tensorflow`, `opencv-python`, `mediapipe`, `numpy`.

---

## Setup and Usage

### 1. Download the datasets

This project uses two datasets:

- **Training** — [Labeled Faces in the Wild (LFW) Dataset](https://www.kaggle.com/datasets/jessicali9530/lfw-dataset)
- **Evaluation** — [AT&T Database of Faces (ORL Dataset)](https://www.kaggle.com/datasets/kasikrit/att-database-of-faces)

Download both from Kaggle and place them in the expected data directory before running the preprocessing script.

> Add the exact folder path each dataset should be extracted to (e.g. `data/lfw/`, `data/orl/`), since the scripts likely expect a specific location.

### 2. Preprocess the dataset

```bash
python preprocess.py
```

This filters the LFW dataset to identities with at least 3 images, detects and crops each face using BlazeFace with a margin, and resizes everything to a standardized 160×160 input. The result is saved as the `lfw_cropped` dataset.

### 3. Train the feature embedding model

```bash
python feature_embedding.py
```

Trains the MobileNetV2 embedding model on `lfw_cropped` using a triplet loss objective (anchor, positive, negative), producing a set of trained weights.

### 4. Convert the trained model to TFLite

```bash
python convertion.py
```

Converts the trained Keras weights into a `.tflite` model suitable for mobile deployment.

### 5. Add the models to the Android app

Copy both `.tflite` files into the app's assets folder:

```
android_app/assets/models/
├── blaze_face_short_range.tflite
└── <your_embedding_model_name>.tflite
```

### 6. Run the app

```bash
cd android_app
flutter pub get
flutter run
```

### 7. Evaluate on desktop

To reproduce the desktop-environment evaluation of the proposed pipeline (Accuracy, Precision, Recall, F1-Score):

```bash
python proposed_model_evaluation.py
```

---

## Results

| Method | Accuracy | Precision | Recall | F1-Score | Inference Latency |
|---|---|---|---|---|---|
| BlazeFace + MobileNetV2 (Proposed) | 87.69% | 100% | 46.67% | 0.64 | 5.03 ms |
| MTCNN + FaceNet | 98.97% | 100% | 95.56% | 0.98 | 143.27 ms |
| MTCNN + ArcFace | 97.95% | 100% | 91.11% | 0.95 | 121.11 ms |

Full comparison against all baseline architectures is detailed in the accompanying dissertation.

---

## Limitations

- No anti-spoofing (liveness detection) — cannot yet distinguish a genuine face from a printed photo
- Evaluation set is relatively small (40 identities / 400 images)
- The stricter matching threshold, calibrated for 0% false acceptance, results in a lower Recall — genuine users may occasionally need to rescan

---

## License

> Add your chosen license here (e.g. MIT, Apache 2.0), or state that this is submitted coursework and not licensed for reuse.
