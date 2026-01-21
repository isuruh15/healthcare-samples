import ballerina/io;
import ballerinax/health.hl7v2 as hl7;
import ballerinax/health.hl7v23 as hl7v23;

// Sample HL7 ORU^R01 messages for testing - these are Observation Result Unsolicited messages
// containing patient information, orders, and lab/radiology results

// Simple radiology report with single OBX segment
final string oruMsg = "MSH|^~\\&|MESA_RPT_MGR|EAST_RADIOLOGY|iFW|XYZ|20010501141500||ORU^R01|MESA3b|P|2.3"+
"\rPID|||CR3^^^ADT1||CRTHREE^PAUL|||||||||||||PatientAcct"+
"\rPV1||1|CE||||12345^SMITH^BARON^H|||||||||||"+
"\rOBR|||||||20010501141500||||||||||||||||||F||||||||||||||||||"+
"\rOBX|1|TX|SR Text||Radiology Report History: Cough. Findings: PA evaluation of the chest demonstrates the lungs to be expanded and clear. Conclusions: Normal PA chest x-ray.||||||||F|||200105011415";

// Urinalysis result with multiple OBX segments (color, appearance, specific gravity)
final string oruMsg1 = "MSH|^~\\&|MESA_RPT_MGR|EAST_RADIOLOGY|iFW|XYZ|20010501141500||ORU^R01|MESA3b|P|2.3"+
"\rPID|||CR3^^^ADT1||CRTHREE^PAUL|||||||||||||PatientAcct"+
"\rPV1||1|CE||||12345^SMITH^BARON^H|||||||||||"+
"\rOBR|1||KZ144871|35340^Urinalysis,Complete^L^34F^^L|||20200102134800|||||||||^YOUSEFZADEH^PEGAH^^^^^UPIN~1750674230^YOUSEFZADEH^PEGAH^^^^^NPI||||TBR||202001030509||||||||||||||||||||||81001^^CPT|"+
"\rOBX|1|ST|5778-6^^LOINC^57786^COLOR^L||Dark Yellow||^^Yellow|A|||F|||202001030509|||"+
"\rOBX|2|ST|5767-9^^LOINC^57679^APPEARANCE^L||Clear||^^Clear||||F|||202001030509|||"+
"\rOBX|3|NM|5811-5^^LOINC^58115^SPECIFIC GRAVITY^L||1.034||1.001^1.035^||||F|||202001030509|||"+
"\rNTE|1||For patients >49 years of age, the reference limit";

// Drug screen panel with 11 OBX segments, includes ORC segment with extended fields (orc20-orc23)
final string oruMsg3 = "MSH|^~\\&|Informatics|Quest Diagnostics||MagnaCare|20200113045702-0600||ORU^R01|M2001304570200000205|P|2.3"+
"\rPID|6|111|111|1111|aaa^JANET^||bbb|F|||51 ^^sd fd^NY^23||^^^^^^||||||"+
"\rIN1|1|7630||||||316||||||||||||||||||||||||||||31601839"+
"\rORC|||KZ146999||||||20200103|||A64277^SLOMOWITS^JOSEPH^^^^^UPIN~1134212053^SLOMOWITS^JOSEPH^^^^^NPI|||||||||JOSEPH SLOMOWITS, MD^D^T71325|5117 15TH AVENUE^^BROOKLYN^NY^11219-3711|^^^^^718^8518400|"+
"\rDG1|1|ICD|Z13.89"+
"\rOBR|1||KZ146999|53011^Drug Screen 10 Drug,w/Confirm^L^86058T^^L|||20200102000000|||||||||A64277^SLOMOWITS^JOSEPH^^^^^UPIN~1134212053^SLOMOWITS^JOSEPH^^^^^NPI||||TBR||202001030827||||||||||||||||||||||G0431^^CPT|"+
"\rOBX|1|ST|^^LOINC^53000031^53000031^L||SEE NOTE||^^||||F|||202001030827|||"+
"\rNTE|1||Screen"+
"\rNTE|2||Cut Off Level"+
"\rNTE|3||(ng/mL)"+
"\rOBX|2|ST|14308-1^^LOINC^50334981^AMPHETAMINES,QL,URINE^L||Negative|1000|^^Negative||||F|||202001030827|||"+
"\rOBX|3|ST|3377-9^^LOINC^50337791^BARBITURATES,QL,URINE^L||Negative|300|^^Negative||||F|||202001030827|||"+
"\rOBX|4|ST|3390-2^^LOINC^50339021^BENZODIAZEPINES,QL,URINE^L||Negative|300|^^Negative||||F|||202001030827|||"+
"\rOBX|5|ST|3393-6^^LOINC^50339361^COCAINE,QL,URINE^L||Negative|300|^^Negative||||F|||202001030827|||"+
"\rOBX|6|ST|3773-9^^LOINC^50377391^METHADONE,QL,URINE^L||Negative|300|^^Negative||||F|||202001030827|||"+
"\rOBX|7|ST|3786-1^^LOINC^50378612^METHAQUALONE,QL,URINE^L||Negative|300|^^Negative||||F|||202001030827|||"+
"\rOBX|8|ST|3879-4^^LOINC^50387941^OPIATES,QL,URINE^L||Negative|300|^^Negative||||F|||202001030827|||"+
"\rOBX|9|ST|3936-2^^LOINC^50393621^PHENCYCLIDINE,QL,URINE^L||Negative|25|^^Negative||||F|||202001030827|||"+
"\rOBX|10|ST|19141-1^^LOINC^50354441^PROPOXYPHENE,QL,URINE^L||Negative|300|^^Negative||||F|||202001030827|||"+
"\rOBX|11|ST|14312-3^^LOINC^53143123^THC 50 URINE^L||Negative|50|^^Negative||||F|||202001030827|||"+
"\rNTE|1||These results are for medical treatment only."+
"\rNTE|2||Analysis was performed as non-forensic testing.";

// Custom ORC segment definition extending the standard HL7v2.3 ORC segment
// This adds fields orc20-orc23 which are not part of the standard HL7v2.3 specification
// but may be used by specific implementations for vendor-specific data
@hl7:SegmentDefinition {
    fields: {
        "orc20": {
            required: false,
            length: 1,
            maxReps: 1,
            dataType: hl7v23:ST
        },
        "orc21": {
            required: false,
            length: 1,
            maxReps: 1,
            dataType: hl7v23:ST
        },
        "orc22": {
            required: false,
            length: 1,
            maxReps: 1,
            dataType: hl7v23:ST
        },
        "orc23": {
            required: false,
            length: 1,
            maxReps: 1,
            dataType: hl7v23:ST
        }
    }
}
public type ORC record {
    *hl7v23:ORC;
    hl7v23:ST orc20 = "";
    hl7v23:ST orc21 = "";
    hl7v23:ST orc22 = "";
    hl7v23:ST orc23 = "";
};
public function main() returns error? {

    // Register the custom ORC segment with the HL7 parser for version 2.3
    // This enables parsing of extended ORC fields (orc20-orc23) from the message
    ORC orc = {};
    hl7:registerCustomSegment("2.3", orc);

    // Parse the raw HL7 message string into a typed ORU_R01 message structure
    hl7v23:ORU_R01 oruMessage = check hl7:parse(oruMsg3).ensureType(hl7v23:ORU_R01);

    // Extract patient data from the PID segment
    // ORU_R01 structure: patient_result[] -> oru_r01_patient -> pid
    hl7v23:ORU_R01_PATIENT_RESULT patientResultForPid = oruMessage.patient_result[0];
    hl7v23:ORU_R01_PATIENT? patientInfo = patientResultForPid.oru_r01_patient;
    hl7v23:PID pidSegment = patientInfo?.pid ?: {};

    // Print patient data
    io:println("\n=== Patient Data ===");
    io:println("Patient ID: ", pidSegment.pid3[0].cx1);
    io:println("Patient Name: ", pidSegment.pid5[0].xpn2, " ", pidSegment.pid5[0].xpn1);
    io:println("Account Number: ", pidSegment.pid18.cx1);

    // Extract observation data from the OBX segment
    // ORU_R01 structure: patient_result[] -> oru_r01_order_observation[] -> oru_r01_observation[] -> obx
    hl7v23:ORU_R01_PATIENT_RESULT patientResult = oruMessage.patient_result[0];
    hl7v23:ORU_R01_ORDER_OBSERVATION orderObs = patientResult.oru_r01_order_observation[0];
    hl7v23:ORU_R01_OBSERVATION observation = orderObs.oru_r01_observation[0];

    // Get the first OBX (Observation/Result) segment containing the actual test result
    hl7v23:OBX obxSegment = observation.obx ?: {};

    // Print observation data
    io:println("\n=== Observation Data ===");
    io:println("Set ID: ", obxSegment.obx1);
    io:println("Value Type: ", obxSegment.obx2);
    io:println("Observation Identifier: ", obxSegment.obx3.ce1);
    io:println("Observation Sub-ID: ", obxSegment.obx4);
    io:println("Observation Value: ", obxSegment.obx5.toString());
    io:println("Units: ", obxSegment.obx6.ce1);
    io:println("Reference Range: ", obxSegment.obx7);
    io:println("Abnormal Flags: ", obxSegment.obx8);
    io:println("Probability: ", obxSegment.obx9);
    io:println("Nature of Abnormal Test: ", obxSegment.obx10);
    io:println("Observation Result Status: ", obxSegment.obx11);
    io:println("Date Last Obs Normal Value: ", obxSegment.obx12.ts1);
    io:println("User Defined Access Checks: ", obxSegment.obx13);
    io:println("Observation Date/Time: ", obxSegment.obx14.ts1);

    // Extract custom ORC (Common Order) fields data
    // The ORC segment is cast to the custom ORC type to access extended fields orc20-orc23
    hl7:Segment? orcSegmentData = orderObs.orc;
    ORC orcSegment = check orcSegmentData.ensureType(ORC);

    // Print custom ORC fields
    io:println("\n=== Custom ORC Fields ===");
    io:println("ORC-20: ", orcSegment.orc20);
    io:println("ORC-21: ", orcSegment.orc21);
    io:println("ORC-22: ", orcSegment.orc22);
    io:println("ORC-23: ", orcSegment.orc23);

}



