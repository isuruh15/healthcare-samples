import ballerina/uuid;
import ballerinax/health.fhir.r4;
import ballerinax/health.fhir.r4.international401;
import ballerinax/health.fhir.r4.medcom240;
import ballerinax/health.hl7v23;

isolated function createMedcomPatient(international401:Patient originalPatient, hl7v23:ADT_A01 incomingMessage) returns medcom240:MedComCorePatient => let
var familyName = incomingMessage.pid.pid5[0].xpn1,
var givenName = incomingMessage.pid.pid5[0].xpn2,
medcom240:MedComCorePatientIdentifierCpr cprIdentifier = {
        value: uuid:createType1AsString()
    },
    medcom240:MedComCorePatientNameOfficial slicedName = {
        family: familyName,
        given: [givenName]
    },
    medcom240:MedComCorePatientGeneralPractitionerReferencedSORUnit slicedPractitioner = {
        identifier: {
            value: incomingMessage.pv1.pv18[0].xcn1,
            system: "urn:oid:1.2.208.176.1.1",
            use: "official"
        }

    },
    r4:canonical[] profiles = ["http://medcomfhir.dk/ig/core/StructureDefinition/medcom-core-patient"]
    in {
        identifier: [

            <medcom240:MedComCorePatientIdentifierD_ecpr>{
                value: incomingMessage.pid.pid3[0].cx1

            },
            cprIdentifier

        ],
        name: [
            slicedName
        ],
        generalPractitioner: [slicedPractitioner],
        meta: {
            profile: profiles
        }
    };

isolated function createMedcomEncounter(international401:Encounter originalEncounter, hl7v23:ADT_A01 incomingMessage) returns medcom240:MedComCoreEncounter => let
r4:canonical[] profiles = ["http://medcomfhir.dk/ig/core/StructureDefinition/medcom-core-patient"]
    in {

        'class: originalEncounter.'class,
        subject: {},
        status: originalEncounter.status,
        meta: {profile: profiles}
    };
