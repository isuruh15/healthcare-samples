import ballerina/io;
import ballerina/uuid;
import ballerinax/health.fhir.r4;
import ballerinax/health.fhir.r4.international401;
import ballerinax/health.fhir.r4.medcom240;
import ballerinax/health.hl7v2 as hl7;
import ballerinax/health.hl7v23;
import ballerinax/health.hl7v2commons as hl7types;
import ballerinax/health.hl7v2.utils.v2tofhirr4;

final string msg = "MSH|^~\\&|ADT1|GOOD HEALTH HOSPITAL|GHH LAB, INC.|GOOD HEALTH" +
"HOSPITAL|198808181126|SECURITY|ADT^A01^ADT_A01|MSG00001|P|2.3||\rEVN|A01|" +
"200708181123||\rPID|1||PATID1234^5^M11^ADT1^MR^GOOD HEALTH" +
"HOSPITAL~123456789^^^USSSA^SS||" +
"BATMAN^ADAM^A^III||19610615|M||C|2222 HOME STREET^^GREENSBORO^NC^27401-1020|GL|" +
"(555)555-2004|(555)555-2004||S||PATID12345001^2^M10^ADT1^AN^A|444333333|987654^NC|" +
"\rNK1|1|NUCLEAR^NELDA^W|SPO^SPOUSE||||NK^NEXT OF KIN$\rPV1|1|I|2000^2012^01||||" +
"004777^ATTEND^AARON^A|||SUR||||ADM|A0|";

# Transformation function for patient resource. Includes custom mappings as well 
# + originalResource - generic R4 resource   
# + incomingMsg - original HL7v2 message 
# + return - completed Danish FHIR profiled resource 
isolated function transformPatient(r4:Resource originalResource, hl7:Message incomingMsg) returns medcom240:MedComCorePatient|error {

    // Create Patient for Danish IG
    medcom240:MedComCorePatient customPatient = createMedcomPatient(check incomingMsg.cloneWithType(hl7v23:ADT_A01));

    // Merge with original
    medcom240:MedComCorePatient merged = check mergeFhirResources(originalResource, customPatient).cloneWithType(medcom240:MedComCorePatient);

    return merged;
}

# Contains generic convertion and type casting implementation for Encounter resource.
#
# + originalResource - generic R4 resource  
# + incomingMsg - original HL7v2 message
# + return - completed Danish FHIR profiled resource
public isolated function transformEncounter(r4:Resource originalResource, hl7:Message incomingMsg) returns medcom240:MedComCoreEncounter|error {

    international401:Encounter typedResource = check originalResource.cloneWithType(international401:Encounter);

    // add IG specific constrained values for typed clone.
    typedResource.subject = {};

    medcom240:MedComCoreEncounter customEncounter = createMedcomEncounter(check incomingMsg.cloneWithType(hl7v23:ADT_A01));

    medcom240:MedComCoreEncounter merged = check mergeFhirResources(originalResource, customEncounter).cloneWithType(medcom240:MedComCoreEncounter);
    return merged;
}

public isolated function transformDiagnosticReport(r4:Resource originalResource, hl7:Message incomingMsg) returns medcom240:MedComCoreDiagnosticReport|error {

    international401:DiagnosticReport typedResource = check originalResource.cloneWithType(international401:DiagnosticReport);

    // add IG specific constrained values for typed clone.
    typedResource.subject = {};
    typedResource.status = "registered";
    typedResource.issued = "2015-02-07T13:28:17.239+02:00";

    medcom240:MedComCoreDiagnosticReport castedResource = check typedResource.cloneWithType(medcom240:MedComCoreDiagnosticReport);
    r4:canonical[] profiles = ["http://medcomfhir.dk/ig/core/StructureDefinition/medcom-core-diagnosticreport"];

    castedResource.meta.profile = profiles;

    return castedResource;
}

public isolated function transformPractitioner(r4:Resource originalResource, hl7:Message incomingMsg) returns medcom240:MedComCorePractitioner|error {

    international401:Practitioner typedResource = check originalResource.cloneWithType(international401:Practitioner);

    medcom240:MedComCorePractitioner castedResource = check typedResource.cloneWithType(medcom240:MedComCorePractitioner);
    r4:canonical[] profiles = ["http://medcomfhir.dk/ig/core/StructureDefinition/medcom-core-practitioner"];

    castedResource.meta.profile = profiles;

    return castedResource;
}

public isolated function customTransformPractitioner(r4:Resource originalResource, hl7:Message incomingMsg) returns medcom240:MedComCorePractitioner|error {

    international401:Practitioner typedResource = check originalResource.cloneWithType(international401:Practitioner);

    medcom240:MedComCorePractitioner castedResource = check typedResource.cloneWithType(medcom240:MedComCorePractitioner);
    r4:canonical[] profiles = ["http://medcomfhir.dk/ig/core/StructureDefinition/medcom-core-practitioner"];

    castedResource.meta.profile = profiles;

    return castedResource;
}

# Custom values can be populated using the incoing message. Result need to be merge with original resource.
#
# + originalMessage - incoming HL7v2 message
# + return - Patient resource containing only the customly mapped values.
isolated function createCustomPatient(hl7:Message originalMessage) returns medcom240:MedComCorePatient|error {

    hl7v23:ADT_A01 adtMsg = <hl7v23:ADT_A01>originalMessage;
    hl7v23:PID pidSegment = adtMsg.pid;
    hl7v23:PV1 pv1Segment = adtMsg.pv1;

    string internalId = pidSegment.pid3[0].cx1;
    string danishFHIRId = uuid:createType1AsString();
    string familyName = pidSegment.pid5[0].xpn1;
    string givenName = pidSegment.pid5[0].xpn2;

    string referringDoctorId = pv1Segment.pv18[0].xcn1;

    medcom240:MedComCorePatientIdentifierD_ecpr deprIdentifier = {
        value: internalId

    };

    medcom240:MedComCorePatientIdentifierCpr cprIdentifier = {
        value: danishFHIRId
    };

    medcom240:MedComCorePatientNameOfficial slicedName = {
        family: familyName,
        given: [givenName]
    };

    medcom240:MedComCorePatientGeneralPractitionerReferencedSORUnit slicedPractitioner = {
        identifier: {
            value: referringDoctorId,
            system: "urn:oid:1.2.208.176.1.1",
            use: "official"
        }

    };
    r4:canonical[] profiles = ["http://medcomfhir.dk/ig/core/StructureDefinition/medcom-core-patient"];

    medcom240:MedComCorePatient customPatient = {

        identifier: [cprIdentifier, deprIdentifier],
        name: [slicedName],
        generalPractitioner: [slicedPractitioner],
        meta: {
            profile: profiles
        }
    };

    return customPatient;
}

# Custom v2 to fhir mapping implementation. pv1 segments will refer this when transforming
#
# + pv1 - PV1 segment of message
# + return - Transformed encounter resource
public isolated function pv1ToMedcomEncounter(hl7types:Pv1 pv1) returns medcom240:MedComCoreEncounter {
    string encounterClass = pv1.pv12.toString() == "I" ? "inpatient encounter" : "ambulatory";
    medcom240:MedComCoreEncounter encounter = {
        meta: {
            profile: ["http://medcomfhir.dk/ig/core/StructureDefinition/medcom-core-encounter"]
        },
        id: pv1.pv11.toString(),
        'class: {display: encounterClass},
        status: "in-progress",
        subject: {
            reference: "Patient/221" //this value has to be taken from PID segment, kept a constant for demo purpose
        },
        location: []
    };
    return encounter;
};

isolated function extendedMappingExec() returns error? {
    // You can also bind custom mapping function implementations by overriding 
    // the default mapping functions. Following are the supported mapping functions. These functions are
    // defined to map Hl7 segments to FHIR resources as per the standard mappings defined at 
    // https://build.fhir.org/ig/HL7/v2-to-fhir/branches/master/segment_maps.html.
    // Supported functions: Pv1ToPatient, Pv1ToEncounter, Nk1ToPatient, Pd1ToPatient, PidToPatient, Dg1ToCondition,
    // ObxToObservation, ObrToDiagnosticReport, Al1ToAllerygyIntolerance, EvnToProvenance, MshToMessageHeader,
    // Pv2ToEncounter, OrcToImmunization.
    v2tofhirr4:V2SegmentToFhirMapper customMapper = {
        pv1ToEncounter: pv1ToMedcomEncounter
    };
    // You can pass the custom mapper implementation as a function parameter to the v2ToFhir module.
    json v2tofhirResult = check v2tofhirr4:v2ToFhir(msg, customMapper);
    io:println("Transformed FHIR message using the custom mapper: ", v2tofhirResult.toString());
    io:println("------------------------------------------------------------------");
}
