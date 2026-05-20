WITH
  ICD_table AS (
    SELECT
      d.subject_id,
      d.hadm_id,
      d.icd_code,
      d.icd_version,
      ad.admittime,
      ad.dischtime,
      ad.admission_location AS AD_loc,
      pa.gender AS Gender,
      pa.anchor_age AS Age
    FROM `physionet-data.mimiciv_3_1_hosp.diagnoses_icd` AS d
    JOIN `physionet-data.mimiciv_3_1_hosp.admissions` AS ad
      ON d.subject_id = ad.subject_id AND d.hadm_id = ad.hadm_id
    JOIN `physionet-data.mimiciv_3_1_hosp.patients` AS pa
      ON pa.subject_id = ad.subject_id
  ),

  CXR_table AS (
    SELECT
      dicom,
      CAST(PatientID AS INT64) AS PatientID,
      CAST(StudyID AS INT64) AS StudyID,
      StudyDate,
      StudyTime
    FROM `physionet-data.mimic_cxr.dicom_metadata_string`
    WHERE ViewPosition IN ('AP','PA')
  ),

  Valid_CXR AS (
    SELECT
      cxr.* EXCEPT(StudyDate, StudyTime),
      CAST(
        FORMAT('%s%s', cxr.StudyDate, SUBSTR(cxr.StudyTime, 0, 6))
        AS DATETIME FORMAT 'YYYYMMDDHH24MISS'
      ) AS StudyDateTime
    FROM CXR_table AS cxr
  ),

  -- ICU stay that contains the CXR time (for ICU/Ward labeling + invasive exclusion)
  ICU_stay_at_cxr AS (
    SELECT
      icu.subject_id,
      icu.hadm_id,
      icu.stay_id,
      cxr.StudyDateTime
    FROM `physionet-data.mimiciv_3_1_icu.icustays` AS icu
    JOIN Valid_CXR AS cxr
      ON icu.subject_id = cxr.PatientID
     AND DATETIME_DIFF(cxr.StudyDateTime, icu.intime, SECOND) >= 0
     AND DATETIME_DIFF(cxr.StudyDateTime, icu.outtime, SECOND) <= 0
  ),

  -- Invasive ventilation intervals from procedureevents (time-interval definition)
  Invasive_intervals AS (
    SELECT
      stay_id,
      starttime,
      endtime
    FROM `physionet-data.mimiciv_3_1_icu.procedureevents`
    WHERE itemid = 225792  -- Invasive vent
      AND starttime IS NOT NULL
      AND endtime IS NOT NULL
      AND endtime > starttime
  ),

  -- Flag if the CXR time falls within an invasive ventilation interval
  Invasive_at_cxr AS (
    SELECT
      s.subject_id,
      s.hadm_id,
      s.stay_id,
      s.StudyDateTime,
      TRUE AS is_invasive_at_cxr
    FROM ICU_stay_at_cxr AS s
    JOIN Invasive_intervals AS inv
      ON s.stay_id = inv.stay_id
     AND s.StudyDateTime BETWEEN inv.starttime AND inv.endtime
    GROUP BY s.subject_id, s.hadm_id, s.stay_id, s.StudyDateTime
  )

SELECT
  cxr.dicom AS dicom,
  cxr.PatientID AS PatientID,
  cxr.StudyID AS StudyID,
  icd.hadm_id AS hadm_id,

  -- timestamps for timing windows
  cxr.StudyDateTime AS cxr_time,
  icd.admittime AS admit_time,
  icd.dischtime AS discharge_time,

  -- timing windows (hours)
  DATETIME_DIFF(cxr.StudyDateTime, icd.admittime, HOUR) AS hrs_admit_to_cxr,
  DATETIME_DIFF(icd.dischtime, cxr.StudyDateTime, HOUR) AS hrs_cxr_to_discharge,

  -- ICD codes aggregated within the admission
  STRING_AGG(DISTINCT icd.icd_code) AS icd_code,
  icd.icd_version AS icd_version,

  icd.AD_loc AS AD_loc,
  icd.Gender AS Gender,
  icd.Age AS Age,

  DATETIME_DIFF(icd.dischtime, icd.admittime, DAY) AS AD_duration,

  -- Unit labeling without ED table
  CASE
    WHEN icu.stay_id IS NULL THEN 'Ward/Non-ICU'
    ELSE 'ICU'
  END AS Unit,

  icu.stay_id AS Stay_id

FROM Valid_CXR AS cxr
JOIN ICD_table AS icd
  ON cxr.PatientID = icd.subject_id
 AND DATETIME_DIFF(cxr.StudyDateTime, icd.admittime, HOUR) >= 0
 AND DATETIME_DIFF(cxr.StudyDateTime, icd.dischtime, HOUR) <= 0

LEFT JOIN ICU_stay_at_cxr AS icu
  ON cxr.PatientID = icu.subject_id
 AND icd.hadm_id = icu.hadm_id
 AND cxr.StudyDateTime = icu.StudyDateTime

LEFT JOIN Invasive_at_cxr AS invflag
  ON cxr.PatientID = invflag.subject_id
 AND icd.hadm_id = invflag.hadm_id
 AND cxr.StudyDateTime = invflag.StudyDateTime

WHERE
  COALESCE(invflag.is_invasive_at_cxr, FALSE) = FALSE

GROUP BY
  dicom, PatientID, StudyID, hadm_id,
  cxr_time, admit_time, discharge_time, hrs_admit_to_cxr, hrs_cxr_to_discharge,
  icd_version, AD_loc, Gender, Age, AD_duration,
  Unit, Stay_id

HAVING
  (
    (icd_version = 10 AND (icd_code LIKE '%I502%' OR icd_code LIKE '%I503%'))
    OR
    (icd_version = 9  AND (icd_code LIKE '%4282%' OR (icd_code LIKE '%4283%')))
  )

ORDER BY AD_duration;
