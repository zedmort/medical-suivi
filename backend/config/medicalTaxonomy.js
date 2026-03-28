const SPECIALTY_DISEASES = {
  cardiology: [
    "Hypertension",
    "Coronary Artery Disease",
    "Heart Failure",
    "Arrhythmia",
    "Cardiomyopathy",
  ],
  dermatology: [
    "Acne",
    "Eczema",
    "Psoriasis",
    "Dermatitis",
    "Skin Infection",
  ],
  endocrinology: [
    "Type 1 Diabetes",
    "Type 2 Diabetes",
    "Hypothyroidism",
    "Hyperthyroidism",
    "Metabolic Syndrome",
  ],
  gastroenterology: [
    "Gastritis",
    "GERD",
    "Irritable Bowel Syndrome",
    "Hepatitis",
    "Ulcerative Colitis",
  ],
  gynecology: [
    "Polycystic Ovary Syndrome",
    "Endometriosis",
    "Uterine Fibroids",
    "Cervicitis",
    "Menstrual Disorder",
  ],
  hematology: [
    "Iron Deficiency Anemia",
    "Sickle Cell Disease",
    "Thalassemia",
    "Leukopenia",
    "Hemophilia",
  ],
  nephrology: [
    "Chronic Kidney Disease",
    "Nephritis",
    "Kidney Stones",
    "Proteinuria",
    "Acute Kidney Injury",
  ],
  neurology: [
    "Migraine",
    "Epilepsy",
    "Stroke",
    "Peripheral Neuropathy",
    "Parkinson Disease",
  ],
  oncology: [
    "Breast Cancer",
    "Lung Cancer",
    "Colon Cancer",
    "Leukemia",
    "Lymphoma",
  ],
  ophthalmology: [
    "Cataract",
    "Glaucoma",
    "Conjunctivitis",
    "Diabetic Retinopathy",
    "Dry Eye Syndrome",
  ],
  orthopedics: [
    "Osteoarthritis",
    "Rheumatoid Arthritis",
    "Fracture",
    "Lumbar Disc Hernia",
    "Tendonitis",
  ],
  pediatrics: [
    "Bronchiolitis",
    "Otitis",
    "Childhood Asthma",
    "Gastroenteritis",
    "Growth Delay",
  ],
  psychiatry: [
    "Depression",
    "Generalized Anxiety Disorder",
    "Bipolar Disorder",
    "Schizophrenia",
    "Insomnia",
  ],
  pulmonology: [
    "Asthma",
    "Chronic Bronchitis",
    "Pneumonia",
    "COPD",
    "Pulmonary Fibrosis",
  ],
  rheumatology: [
    "Lupus",
    "Gout",
    "Rheumatoid Arthritis",
    "Vasculitis",
    "Ankylosing Spondylitis",
  ],
  urology: [
    "Urinary Tract Infection",
    "Benign Prostatic Hyperplasia",
    "Kidney Stones",
    "Prostatitis",
    "Urinary Incontinence",
  ],
};

const normalize = (value) => (value || "").toString().trim().toLowerCase();

const getSpecialties = () => Object.keys(SPECIALTY_DISEASES);

const getAllDiseases = () =>
  Array.from(new Set(Object.values(SPECIALTY_DISEASES).flat())).sort((a, b) =>
    a.localeCompare(b)
  );

const isValidSpecialty = (specialty) => getSpecialties().includes(normalize(specialty));

const getDiseasesForSpecialty = (specialty) => {
  const key = normalize(specialty);
  return SPECIALTY_DISEASES[key] || [];
};

const isDiseaseAllowedForSpecialty = (specialty, disease) => {
  const diseases = getDiseasesForSpecialty(specialty).map(normalize);
  return diseases.includes(normalize(disease));
};

const isKnownDisease = (disease) => getAllDiseases().map(normalize).includes(normalize(disease));

module.exports = {
  SPECIALTY_DISEASES,
  getSpecialties,
  getAllDiseases,
  isValidSpecialty,
  getDiseasesForSpecialty,
  isDiseaseAllowedForSpecialty,
  isKnownDisease,
};
