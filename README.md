# HFrEF vs HFpEF Classification from Chest X-rays

This repository contains the code for our study:  
**"Discriminating HFrEF vs HFpEF from Chest Radiographs: Mitigating Demographic Performance Gaps via Augmentation and Multimodal Fusion."**

The code is used to **train deep learning models, perform subgroup analysis, and validate results** for classifying heart failure with reduced ejection fraction (HFrEF) vs preserved ejection fraction (HFpEF) from chest X-rays.  
We also implement fairness-oriented methods such as **data augmentation** and **multimodal fusion** with demographic features to reduce performance disparities across subgroups.

---

## 🚀 Getting started

### 1. Clone the repo
```bash
git clone https://github.com/jerryshu98/HFrEF-HFpEF-multimodal.git
cd HFrEF-HFpEF-multimodal
```

### 2. Install dependencies
```bash
conda create -n hfref python=3.9
conda activate hfref
pip install -r requirements.txt
```

### 3. Run training
```bash
python train.py --config configs/densenet121.yaml
```

---

## 📊 Data availability
This work uses publicly available datasets:  
- [MIMIC-CXR v2.0.0](https://physionet.org/content/mimic-cxr/2.0.0/)  
- [MIMIC-IV v2.2](https://physionet.org/content/mimiciv/2.2/)  

Access requires credentialed researcher status and completion of the PhysioNet data use agreement.