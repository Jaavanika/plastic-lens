# AI-Based Plastic Waste Degradation Prediction for Intelligent Recycling Route Optimization

> **Project type:** AI/ML-based plastic waste assessment and intelligent reuse/recycling decision-support system  
> **Core idea:** Predict the degradation condition and remaining reuse potential of plastic waste, then recommend and optimize the most suitable recovery pathway so that usable material can be reused or recycled effectively.  
> **Primary outcome:** A data-driven decision on what should happen to each plastic item or batch next.  
> **Prototype name:** PlasticLens (Android app + landing website)  
> **Implementation plan:** [PLAN.md](PLAN.md) · **Current status:** [§19](#19-current-implementation-status)  
> **Earlier identification-only specification:** [documentation/plasticlens_identification_spec.md](documentation/plasticlens_identification_spec.md)

---

## 1. Project Overview

Plastic waste does not have the same condition or recovery potential. Two items made from the same polymer may have different levels of degradation because of their age, exposure to sunlight, temperature, moisture, mechanical stress, contamination, and previous usage.

This project proposes an AI-based system that analyses available information about plastic waste, predicts its degradation condition, estimates its suitability for further use, and recommends an appropriate recycling or reuse pathway.

The system combines plastic identification, degradation prediction, condition assessment, and intelligent route optimization. Here, **recycling route optimization means selecting the most suitable next-use or recovery pathway for the plastic**. It does not primarily mean optimizing the vehicle route used to transport waste.

For example, a plastic item that is still in good condition may be directed toward direct reuse or preparation for reuse. Material with moderate degradation may be directed toward an appropriate mechanical recycling process. Material that is severely degraded, contaminated, or unsuitable for the intended reuse may be directed toward another validated recovery or disposal option, depending on local facilities and safety requirements.

The project is proposed as our own system concept. Its technical contribution is the integration of degradation prediction with condition-aware pathway selection and optimization.

### Important scientific limitation

A camera image alone cannot reliably measure the chemical or mechanical degradation of every plastic item. The prediction must therefore be based on the evidence and data actually available, such as polymer type, known exposure history, observed condition, contamination indicators, and suitable reference measurements in the training dataset. The system must communicate uncertainty and must not present an AI estimate as a laboratory material test.

---

## 2. Problem Statement

Current plastic waste handling often relies on broad material categories and fixed recycling rules. However, polymer type alone does not determine whether an item can be reused, mechanically recycled, or needs another treatment. Its current condition, contamination, degradation level, and the requirements of the intended next application also matter.

A decision system is needed to:

1. Identify or record the plastic material.
2. Estimate its degradation condition using available evidence.
3. assess its remaining suitability for reuse or recycling.
4. Compare feasible recovery pathways.
5. Recommend the pathway that best meets defined objectives and constraints.
6. Explain why that pathway was selected and identify when more inspection or testing is needed.

---

## 3. Project Objectives

1. Develop a system for recording and classifying plastic waste by polymer type.
2. Build an AI model to estimate plastic degradation condition from suitable labelled data.
3. Identify the factors that contribute to degradation, such as UV exposure, temperature, moisture, age, mechanical stress, and contamination, where data is available.
4. Estimate the likely reuse or recycling suitability of each item or batch.
5. Develop a pathway recommendation engine that considers material type, predicted condition, contamination, and intended output.
6. Optimize the selection of reuse and recycling pathways against configurable objectives such as recovery value, material quality, processing cost, energy use, and waste reduction.
7. Provide an explanation of the recommended pathway and the evidence supporting it.
8. Record outcomes so that recommendations can be evaluated and improved using verified data.

---

## 4. Scope and Main Features

### 4.1 Plastic waste input

The system can accept:
- A photograph of the plastic item or waste batch.
- Polymer type, if known, or a model-predicted material category.
- Item or batch details.
- Known age or usage history, if available.
- Exposure information such as sunlight, heat, moisture, and outdoor storage, if available.
- Visible condition observations such as cracks, discoloration, brittleness, deformation, and surface damage.
- Contamination information, if available.
- Laboratory or measured properties, when supplied by a dataset or an authorized inspection process.

The system must distinguish between measured values, user-entered information, and AI-estimated values.

### 4.2 Plastic identification

A pretrained image model may be fine-tuned to classify common polymer categories:
- PET
- HDPE
- PVC
- LDPE
- PP
- PS

A photo-based classifier provides a likely material category, not definitive chemical identification. Resin markings and user-confirmed labels may be stored as additional evidence. Items with uncertain identification should be flagged for verification.

### 4.3 Degradation prediction

The degradation model estimates a target supported by the available dataset. Depending on the dataset, this may be:
- A degradation or condition category (for example, low, moderate, or high degradation).
- A measured property such as tensile strength retention, elongation at break, molecular-weight change, or another documented degradation indicator.
- A predicted condition score, only where a defensible target definition and ground-truth labels exist.

The model must not invent a universal degradation score where the training data does not support one. The target variable, units, measurement method, and prediction horizon must be documented.

### 4.4 Reuse and recycling suitability

The system combines polymer identity, predicted condition, contamination status, and intended application requirements to estimate which pathways are feasible.

Possible pathway categories include:
- Direct reuse, where the item is safe and suitable for the intended use.
- Cleaning and preparation for reuse.
- Mechanical recycling.
- Specialized recycling or treatment, where locally available and technically appropriate.
- Energy recovery or disposal, only where permitted and where higher-value recovery is unsuitable.

The system should not recommend food-contact, medical, structural, or other safety-critical reuse solely from an AI prediction. Such uses require applicable standards, testing, and regulatory checks.

### 4.5 Intelligent route optimization

The optimizer selects the most suitable pathway from the feasible options. It can consider:
- Predicted degradation and uncertainty.
- Polymer compatibility.
- Contamination and sorting requirements.
- Expected recovered-material quality.
- Processing cost and energy demand.
- Expected material recovery or reuse value.
- Local facility availability and accepted material types.
- Environmental objectives and applicable regulations.

The meaning of “route” in this project is the **material's recovery journey**: the sequence of steps and destination process through which the plastic can be reused or recovered.

---

## 5. Proposed System Workflow

1. **Input collection:** Receive an image and available item or batch information.
2. **Material identification:** Predict or record the polymer category and retain its confidence or verification status.
3. **Condition evidence extraction:** Record visible damage and available exposure, contamination, and history information.
4. **Degradation prediction:** Run the trained model to estimate the selected degradation target.
5. **Suitability assessment:** Compare the predicted condition and material information with pathway-specific requirements.
6. **Candidate pathway generation:** Generate the feasible reuse, recycling, treatment, or disposal options.
7. **Route optimization:** Rank or optimize feasible pathways against the configured objectives and constraints.
8. **Recommendation and explanation:** Display the recommended pathway, alternatives, reasons, and uncertainty.
9. **Outcome recording:** Store verified processing outcomes for evaluation and future model improvement.

---

## 6. High-Level Architecture

```text
                 USER / WASTE OPERATOR
                          |
                          v
              Mobile or Web Application
                          |
                          v
                 Plastic Waste Input
          (Image + Item / Batch Information)
                          |
             +------------+------------+
             |                         |
             v                         v
     Plastic Identification     Condition Evidence
       Model / Markings         and History Records
             |                         |
             +------------+------------+
                          |
                          v
               Feature Preparation
                          |
                          v
              Degradation Prediction
                    AI Model
                          |
                          v
              Condition / Uncertainty
                    Assessment
                          |
                          v
             Reuse-Recycling Suitability
                    Assessment
                          |
                          v
               Candidate Pathways
                          |
                          v
              Intelligent Optimization
                          |
                          v
             Recommended Recovery Route
                          |
                          v
        Explanation + Alternative Pathways
                          |
                          v
             Outcome and Feedback Records
```

---

## 7. AI and Optimization Design

### 7.1 Plastic classification model

A pretrained image-classification model can be fine-tuned to recognize the polymer categories represented in the selected dataset.

Candidate models:
- MobileNetV3
- EfficientNet-B0
- ResNet50

Model selection should be based on validation performance, class balance, inference speed, and deployment requirements. If the project uses photographs alone, the classifier's limitations must be clearly stated.

### 7.2 Degradation prediction model

The model type depends on the available labels and input features.

For tabular data:
- Random Forest
- XGBoost
- LightGBM
- Gradient Boosting

For image-based condition classification:
- EfficientNet or ResNet-based image classifier
- A multi-input model if image features and tabular evidence are both available

For numeric degradation targets, use a regression model and evaluate it with appropriate regression metrics. For degradation categories, use a classification model and evaluate it with classification metrics.

Do not select a model before inspecting the dataset. First establish the target variable, features, sample count, measurement conditions, and missing-data pattern.

### 7.3 Suitability and pathway recommendation

A rule-based or hybrid decision layer can initially translate predicted condition into feasible pathways. The rules should be based on documented material and process requirements, not arbitrary thresholds.

Each candidate pathway should specify:
- Accepted polymer types.
- Permitted condition range or measured-property requirements.
- Contamination limits.
- Required pre-processing.
- Available facility or process.
- Expected output and quality.
- Cost, energy, and environmental data, if available.

### 7.4 Optimization engine

The optimizer compares the feasible pathways and selects the best one under the chosen objective and constraints.

Potential objectives:
- Maximize useful material recovery.
- Maximize reuse value or recovered-material quality.
- Minimize processing cost.
- Minimize energy use or estimated environmental impact.
- Minimize material sent to disposal.

Potential methods:
- Weighted multi-criteria decision analysis for an initial prototype.
- Linear programming when pathway costs, capacities, and material flows can be represented linearly.
- Mixed-integer optimization when discrete process choices and facility capacities are involved.
- Multi-objective optimization when trade-offs between cost, recovery, quality, and environmental impact must be shown.

The project should begin with a transparent baseline optimizer and compare it with more advanced optimization only if the data and project scope justify it.

---

## 8. Example of How the Optimization Enables Reuse

Consider a batch of identified HDPE containers.

- The material identification module predicts HDPE.
- The degradation model estimates the batch condition using the available condition and exposure data.
- The suitability module checks contamination and the requirements of possible next-use pathways.
- The optimizer compares direct reuse after cleaning, mechanical recycling, and other locally valid options.
- If the containers meet the documented requirements for a reuse pathway, the system can recommend cleaning and reuse rather than sending the batch directly for material recycling.
- If the condition or contamination makes direct reuse unsuitable, the optimizer can recommend an appropriate recycling process instead.

This demonstrates how optimization supports reuse: **it directs each plastic item or batch toward the most suitable next application or recovery process based on its predicted condition**, rather than sending every item through the same fixed route.

This is an illustrative workflow. Actual decisions require validated thresholds, process data, local facility information, and relevant safety standards.

---

## 9. Data Requirements and Dataset Strategy

Dataset selection is a critical dependency. A plastic image dataset that only contains polymer labels is not sufficient to train a degradation prediction model.

The project may require separate datasets for:

1. **Plastic type identification:** Images labelled by polymer type.
2. **Plastic degradation:** Samples with documented exposure conditions and measured degradation outcomes.
3. **Material properties:** Measurements such as tensile strength, elongation, molecular weight, or other properties that the project chooses to predict.
4. **Recycling pathway information:** Process compatibility, contamination requirements, facility capabilities, costs, energy use, and recovered output quality.

Potential data sources to investigate include:
- Research papers and supplementary datasets on polymer weathering and accelerated ageing.
- Open materials-science repositories.
- Polymer degradation studies with measured before-and-after properties.
- Public plastic-waste image datasets for the separate identification component.
- Local recycling-facility acceptance criteria and process specifications.

Before using any dataset, verify its licence, label definitions, measurement methods, sample size, and suitability for the intended prediction. Do not combine measurements from incompatible experiments without documenting and addressing differences in polymer grade, specimen preparation, exposure conditions, and measurement protocols.

### Recommended data preparation

- Remove duplicates and invalid records.
- Standardize units and categorical values.
- Preserve experimental and sample identifiers.
- Handle missing values transparently.
- Examine class imbalance and target distribution.
- Split data by sample, batch, or experiment where appropriate to prevent leakage.
- Keep a held-out test set that is not used for model or threshold selection.
- Record dataset provenance and preprocessing steps.

---

## 10. Evaluation Plan

### 10.1 Plastic identification

- Accuracy
- Precision
- Recall
- F1-score
- Confusion matrix
- Per-class performance

### 10.2 Degradation prediction

For regression:
- MAE
- RMSE
- R-squared, interpreted alongside error metrics

For classification:
- Accuracy
- Precision
- Recall
- F1-score
- Confusion matrix
- Per-class recall

Also assess calibration or uncertainty where possible. Report performance separately across polymer types and exposure conditions if the dataset supports it.

### 10.3 Pathway recommendation and optimization

Evaluate:
- Agreement with expert- or process-validated pathway labels.
- Feasibility constraint violations.
- Predicted versus actual recovered material quality, where outcome data exists.
- Recovery yield.
- Processing cost and energy, where measured.
- Amount directed to reuse or recycling versus disposal.
- Sensitivity to uncertain degradation predictions and changes in objective weights.

Compare the optimizer with a simple baseline, such as a fixed rule-based pathway assignment. Do not claim environmental or economic improvement unless it is measured against a defined baseline.

---

## 11. Suggested Technology Stack

| Layer | Suggested technology |
|---|---|
| Application | Flutter / Dart or a web interface |
| AI development | Python |
| Data processing | Pandas, NumPy, scikit-learn |
| Deep learning | PyTorch or TensorFlow |
| Image classification | MobileNetV3 / EfficientNet |
| Tabular prediction | XGBoost / Random Forest |
| Optimization | OR-Tools or SciPy; advanced solver if needed |
| API | FastAPI |
| Database | PostgreSQL or SQLite for prototype |
| Visualization | Streamlit or Flutter dashboard |
| Testing | Pytest |
| Version control | Git and GitHub |

The technology stack is a proposal and can be adjusted after the dataset and deployment requirements are confirmed.

---

## 12. Suggested Application Modules

1. **Dashboard:** Summary of scanned or registered plastic items and their recommended pathways.
2. **Add Waste Item:** Upload an image and enter available material, history, condition, and contamination information.
3. **Material Identification:** Show predicted polymer type and verification status.
4. **Degradation Assessment:** Show the predicted degradation target, units or category, uncertainty, and key input factors.
5. **Reuse and Recycling Recommendation:** Show the feasible pathways and why some options are unsuitable.
6. **Optimization Results:** Show the recommended recovery route and alternative pathways.
7. **History:** Maintain past assessments and pathway decisions.
8. **Admin / Data Management:** Manage material rules, facility information, and verified outcome records.

---

## 13. Example Result Screen

```text
PLASTIC WASTE ASSESSMENT

Material: HDPE
Identification status: Model prediction
Degradation estimate: Moderate
Prediction confidence / uncertainty: Displayed from validated model

Condition observations:
- Surface discoloration: Detected
- Visible cracking: Not detected
- Contamination: Requires confirmation

Pathway assessment:
1. Cleaning and preparation for reuse
   Status: Requires suitability checks
2. Mechanical recycling
   Status: Candidate pathway
3. Direct reuse without preparation
   Status: Not recommended until inspected

Recommended next step:
Inspect and clean the batch, then verify whether it meets
the documented reuse requirements.

Reason:
The selected pathway considers the predicted condition,
material type, contamination status, and pathway constraints.

Note:
This is an AI-assisted decision, not a laboratory certification.
```

All values above are illustrative, not model outputs or universal material thresholds.

---

## 14. Implementation Roadmap

### Phase 1 — Problem definition and data review
- Define the exact degradation target.
- Identify suitable datasets and licences.
- Determine which features are genuinely available.
- Define pathway categories and evaluation criteria.

### Phase 2 — Data preparation
- Clean and standardize datasets.
- Analyse distributions and missing values.
- Create leakage-resistant train, validation, and test splits.
- Build reproducible preprocessing pipelines.

### Phase 3 — Baseline AI models
- Train a plastic identification model if required.
- Train a baseline degradation model.
- Evaluate per-polymer and per-condition performance.
- Document uncertainty and limitations.

### Phase 4 — Suitability assessment
- Define pathway requirements from reliable technical sources.
- Implement feasibility checks.
- Ensure unsafe or unsupported pathways are excluded.

### Phase 5 — Route optimization
- Implement a transparent baseline decision method.
- Add objective weights and constraints.
- Compare recommended pathways against a fixed-rule baseline.
- Test how recommendations change when inputs or priorities change.

### Phase 6 — Application and API
- Build the input and results interface.
- Connect model inference and optimization through an API.
- Store assessments and pathway decisions.
- Add explanations and history.

### Phase 7 — Testing and final evaluation
- Test missing, noisy, and uncertain inputs.
- Test infeasible pathway scenarios.
- Evaluate AI models on held-out data.
- Evaluate optimizer feasibility and performance.
- Document limitations and future improvements.

A project timeline should be finalized only after confirming the availability and quality of degradation and pathway datasets.

---

## 15. Expected Outcomes

The completed prototype is expected to provide:

- A structured record of plastic waste items or batches.
- A predicted plastic category, where supported by the input data.
- An AI-based degradation estimate tied to a clearly defined target.
- A condition-aware assessment of reuse and recycling suitability.
- An optimized recommendation for the next recovery pathway.
- An explanation of the recommendation and its constraints.
- Evaluation results showing the performance and limitations of both the prediction model and optimizer.

---

## 16. Key Research and Development Risks

| Risk | Mitigation |
|---|---|
| No suitable degradation dataset | Narrow the target to a measurable property or condition category with defensible data |
| Image data mistaken for chemical testing | Clearly separate visual indicators from measured material properties |
| Different studies use incompatible test conditions | Preserve study metadata and use careful harmonization or separate models |
| Arbitrary reuse thresholds | Derive criteria from standards, expert review, and documented process specifications |
| Optimizer recommends unavailable facilities | Include facility availability and accepted-material constraints |
| High uncertainty in predictions | Show uncertainty and request inspection or testing rather than forcing a route |
| Unverified feedback contaminates training data | Add only reviewed, traceable labels to future training versions |

---

## 17. Project Positioning

**AI-Based Plastic Waste Degradation Prediction for Intelligent Recycling Route Optimization** is an AI-driven decision-support concept that predicts the degradation condition of plastic waste and uses that prediction to select an appropriate reuse or recycling pathway.

The central idea is to connect **what condition the plastic is in** with **what should happen to it next**. The optimization component makes reuse actionable by directing material that meets defined requirements toward suitable reuse opportunities, while directing other material toward appropriate recycling or recovery processes.

The project should be presented as a proposed system architecture until its models, data, optimization method, and experimental results have actually been implemented and validated. Any claim of novelty or patentability requires a separate prior-art search and professional assessment.

---

## 18. Short Project Abstract

Plastic waste varies in its degradation condition and potential for further use. Conventional sorting based mainly on material category may not adequately account for the condition of individual items or batches when selecting a recovery process. This project proposes an AI-based system that predicts plastic waste degradation using available material, exposure, condition, and measurement data. The predicted condition is combined with polymer type, contamination information, reuse requirements, and recycling-process constraints to assess feasible recovery pathways. An intelligent optimization module then recommends the most suitable next step, with the aim of increasing appropriate reuse and material recovery while considering processing cost, energy, quality, and environmental objectives. The system provides an explainable recommendation and communicates uncertainty when the available evidence is insufficient. Its effectiveness will be evaluated using held-out degradation data and comparisons against baseline pathway-selection strategies.

---

## 19. Current Implementation Status

The project began as **PlasticLens**, a plastic *identification* and
recycling-guidance app ([earlier specification](documentation/plasticlens_identification_spec.md)).
That work is complete and becomes the foundation of this system. The table
maps it onto the architecture in §6. Sections 4.3–4.5, 7.2–7.4, 10.2–10.3
and the new modules in §12 are **not yet implemented**. Their order and
"done when" criteria are in [PLAN.md](PLAN.md), Part B.

| Component (this README) | Status | Where |
| --- | --- | --- |
| §4.1 Input: photograph (camera or gallery) | ✅ Built | `android_app/lib/screens/scanner_screen.dart`, `scan_flow.dart` |
| §4.1 Input: history, exposure, visible condition, contamination; measured / user-entered / AI-estimated provenance | ⏳ To build | PLAN Section 17 |
| §4.2 Plastic identification (PET, HDPE, PVC, LDPE, PP, PS + non-plastic) | ✅ Built and evaluated | `ai_model/`, `documentation/model_card.md` |
| §4.2 Verification of uncertain identifications (resin code, user correction) | ✅ Built | Result screen "Correct material"; `feedback` collection |
| §4.3 Degradation prediction | ⏳ Blocked on dataset and target decision | PLAN Sections 12–14 |
| §4.4 Reuse and recycling suitability | ⏳ To build (rule base from documented sources) | PLAN Section 15 |
| §4.5 / §7.4 Route optimization | ⏳ To build (weighted MCDA baseline vs fixed-rule baseline) | PLAN Section 16 |
| §12.1, §12.7 Dashboard, History | ✅ Partly (scan history, collection) | PLAN Section 17 extends them to assessments |
| §12.4–12.6 Degradation, recommendation and optimization screens | ⏳ To build | PLAN Section 17 |
| §12.8 Admin / data management | ✅ Partly (materials, feedback via API and Firestore rules) | PLAN Section 17 adds pathway rules, facilities and outcomes |
| API (FastAPI) | ✅ Built (identification second opinion, materials, feedback, admin) | `backend/`, `documentation/api_documentation.md` |
| Accounts, cloud sync, security rules | ✅ Built and emulator-tested; live project setup pending | `firebase/`, `android_app/lib/services/` |
| Landing website | ✅ Built (Lighthouse 100); needs repositioning for the new scope | `website/` |

### Identification results achieved so far

MobileNetV3-Large, held-out test set of 450 images: **accuracy 0.916,
macro-F1 0.915**, calibrated (ECE 0.034). Runs offline on Android (ONNX,
about 0.1 s per scan on the emulator). Full results, limitations and
robustness scenarios: [documentation/model_card.md](documentation/model_card.md).

### Deviations from the suggested stack (§11)

| Suggested | Used | Reason |
| --- | --- | --- |
| PostgreSQL / SQLite | SQLite on the device + Cloud Firestore | Offline-first app, per-user security rules, and a free hosted tier; already built and tested |
| Streamlit / Flutter dashboard | Flutter | One codebase for the app and the dashboard screens |
| PyTorch or TensorFlow | PyTorch (+ ONNX Runtime on the device) | |
| OR-Tools / SciPy | To be chosen in PLAN Section 16 | SciPy for the MCDA baseline; OR-Tools only if a MILP is justified |

---

## 20. Repository Structure

```text
plastic-lens/
|-- android_app/          Flutter app (PlasticLens)
|   |-- lib/              screens, services, models, widgets
|   |-- assets/           models/ (ONNX + labels.json), data/ (materials, lessons, badges)
|   |-- test/, integration_test/
|-- ai_model/
|   |-- preprocessing/    identification dataset pipeline
|   |-- training/ evaluation/ export/
|   |-- degradation/      (planned) degradation dataset + model, PLAN 12-14
|   `-- datasets/, models/ (not committed)
|-- backend/              FastAPI: identification second opinion, materials, feedback, admin
|   `-- app/decision/     (planned) suitability rules + optimizer, PLAN 15-16
|-- firebase/             Firestore/Storage rules, rule tests, hosting tooling
|-- website/              landing page
|-- documentation/        model card, architecture, API, testing, report
|-- tools/                icon generation
|-- PLAN.md
`-- README.md
```

## 21. Setup

| Tool | Version used |
| --- | --- |
| Flutter | 3.50 (`C:\src\flutter`) |
| Android SDK | platform 36/37, emulator `PlasticLens_Pixel` (SDK via `C:\Android\Sdk`) |
| Python | 3.11, venv `C:\src\venvs\plasticlens` (`ai_model/requirements.txt`, `backend/requirements.txt`) |
| Node.js | 24 (`firebase/`: emulator tests, Lighthouse, deploy) |

Quick checks:

```powershell
cd android_app; flutter test                    # 32 tests
cd ..\backend;  pytest                          # 21 tests
cd ..\firebase; npm run test:rules              # 9 tests (needs Java 21)
```

Reproducing the identification model: see the appendix of
[documentation/capstone_report.md](documentation/capstone_report.md).

## 22. Datasets in Use

| Dataset | Use | Licence |
| --- | --- | --- |
| PlasticWaste-DB v1 (Mendeley `tvfx5dspf3`) | Polymer identification (6 classes) | CC BY 4.0 |
| TrashNet | Non-plastic class | MIT |
| *Degradation dataset* | §4.3. **Not yet selected.** See §9 and PLAN Section 12 | to be verified |
| *Pathway / facility data* | §4.4–4.5. **Not yet collected.** See PLAN Section 15 | to be verified |

## 23. Completion Criteria

Foundation (identification app):

- [x] A user can capture or upload an image.
- [x] The app identifies the likely polymer on Android, offline, with calibrated confidence.
- [x] Uncertain and non-plastic inputs are handled safely.
- [x] AI identification results and model version are documented.
- [ ] A user can register and sign in. *(implemented; needs the live Firebase setup)*
- [ ] Cloud synchronisation works when connectivity returns. *(tested against a fake Firestore; needs a live check)*
- [ ] The landing website is live. *(built; deploy needs `firebase login`)*
- [ ] The application has been tested on physical Android devices.

Degradation and route optimization (this README):

- [ ] The degradation target, units, measurement method and dataset are documented (§4.3, §9).
- [ ] The degradation model is evaluated on held-out data with the §10.2 metrics, per polymer and condition where possible.
- [ ] Pathway rules come from cited technical sources, and unsafe or unsupported pathways are excluded (§4.4, §7.3).
- [ ] The optimizer is compared with a fixed-rule baseline, and constraint violations and sensitivity are reported (§10.3).
- [ ] The app records item or batch evidence with its provenance (measured, user-entered or AI-estimated) and shows the recommendation, alternatives, reasons and uncertainty (§12, §13).
- [ ] Outcomes can be recorded and reviewed before they are used for retraining (§5 step 9, §16).
