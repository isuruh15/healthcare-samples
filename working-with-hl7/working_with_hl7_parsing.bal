import ballerina/io;
import ballerinax/health.hl7v2 as hl7;
import ballerinax/health.hl7v23 as hl7v23;

final string oruMsg = "MSH|^~\\&|MESA_RPT_MGR|EAST_RADIOLOGY|iFW|XYZ|20010501141500||ORU^R01|MESA3b|P|2.3"+
"\rPID|||CR3^^^ADT1||CRTHREE^PAUL|||||||||||||PatientAcct"+
"\rPV1||1|CE||||12345^SMITH^BARON^H|||||||||||"+
"\rOBR|||||||20010501141500||||||||||||||||||F||||||||||||||||||"+
"\rOBX|1|TX|SR Text||Radiology Report History: Cough. Findings: PA evaluation of the chest demonstrates the lungs to be expanded and clear. Conclusions: Normal PA chest x-ray.||||||||F|||200105011415";

public function main() returns error? {


    hl7v23:ORU_R01 oruMessage = check hl7:parse(oruMsg).ensureType(hl7v23:ORU_R01);

    // Extract patient data
    anydata patientData = oruMessage["patient_result"];
    hl7v23:ORU_R01_PATIENT_RESULT patientResultForPid = check patientData.ensureType(hl7v23:ORU_R01_PATIENT_RESULT);
    anydata patientInfoData = patientResultForPid["oru_r01_patient"];
    hl7v23:ORU_R01_PATIENT patientInfo = check patientInfoData.ensureType(hl7v23:ORU_R01_PATIENT);
    hl7v23:PID pidSegment = patientInfo.pid;

    // Print patient data
    io:println("\n=== Patient Data ===");
    io:println("Patient ID: ", pidSegment.pid3[0].cx1);
    io:println("Patient Name: ", pidSegment.pid5[0].xpn2, " ", pidSegment.pid5[0].xpn1);
    io:println("Account Number: ", pidSegment.pid18.cx1);

    // Access the observation from the patient_result
    anydata patientResultData = oruMessage["patient_result"];
    hl7v23:ORU_R01_PATIENT_RESULT patientResult = check patientResultData.ensureType(hl7v23:ORU_R01_PATIENT_RESULT);
    hl7v23:ORU_R01_ORDER_OBSERVATION orderObs = patientResult.oru_r01_order_observation[0];
    hl7v23:ORU_R01_OBSERVATION observation = orderObs.oru_r01_observation[0];

    // Extract observation data
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


}
