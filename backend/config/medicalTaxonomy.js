const DIABETES_CANONICAL_NAME = "Diabetes";
const DIABETES_ALIASES = new Set([
  "diabetes",
  "diabétique",
  "diabetique",
  "diabète",
  "type 1 diabetes",
  "type 2 diabetes",
  "diabète de type 1",
  "diabète de type 2",
  "diabetes type 1",
  "diabetes type 2",
]);
const REGISTRATION_SPECIALTIES = new Set(["diabetology", "endocrinology"]);

const SPECIALTY_DISEASES = {
  cardiology: [],
  dermatology: [],
  diabetology: [DIABETES_CANONICAL_NAME],
  endocrinology: [],
  gastroenterology: [],
  gynecology: [],
  hematology: [],
  nephrology: [],
  neurology: [],
  oncology: [],
  ophthalmology: [],
  orthopedics: [],
  pediatrics: [],
  psychiatry: [],
  pulmonology: [],
  rheumatology: [],
  urology: [],
};

const normalize = (value) => (value || "").toString().trim().toLowerCase();

const canonicalizeDisease = (value) => {
  const normalized = normalize(value);
  if (!normalized) return "";
  if (DIABETES_ALIASES.has(normalized)) return DIABETES_CANONICAL_NAME;
  return value?.toString().trim() || "";
};

const getSpecialties = () => Object.keys(SPECIALTY_DISEASES);

const getAllDiseases = () => [DIABETES_CANONICAL_NAME];

const isValidSpecialty = (specialty) => getSpecialties().includes(normalize(specialty));
const isValidRegistrationSpecialty = (specialty) =>
  REGISTRATION_SPECIALTIES.has(normalize(specialty));

const getDiseasesForSpecialty = (specialty) => {
  const key = normalize(specialty);
  return SPECIALTY_DISEASES[key] || [];
};

const isDiseaseAllowedForSpecialty = (specialty, disease) => {
  const diseases = getDiseasesForSpecialty(specialty).map((item) => normalize(item));
  return diseases.includes(normalize(canonicalizeDisease(disease)));
};

const isKnownDisease = (disease) => {
  const normalized = normalize(canonicalizeDisease(disease));
  return normalized === normalize(DIABETES_CANONICAL_NAME);
};

module.exports = {
  SPECIALTY_DISEASES,
  DIABETES_CANONICAL_NAME,
  getSpecialties,
  getAllDiseases,
  isValidSpecialty,
  isValidRegistrationSpecialty,
  getDiseasesForSpecialty,
  isDiseaseAllowedForSpecialty,
  isKnownDisease,
  canonicalizeDisease,
};
