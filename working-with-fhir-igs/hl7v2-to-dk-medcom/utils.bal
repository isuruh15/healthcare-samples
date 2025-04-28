import ballerinax/health.fhir.r4;
import ballerinax/health.fhir.r4.medcom240;
import ballerinax/health.hl7v2 as hl7;
import ballerinax/health.hl7v2commons as hl7types;
import ballerina/log;
import ballerinax/health.fhir.r4.parser;

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

# Update resources in the bundle that are defined in Danish IG.
#
# + bundle - Bundle resource from v2toFHIR transformation  
# + incomingMsg - incoming HL7v2 message
# + return - Updated bundle resource
public isolated function processBundle(r4:Bundle bundle, hl7:Message incomingMsg) returns r4:Bundle|error? {

    r4:BundleEntry[] updatedEntries = [];
    r4:BundleEntry[] entries = <r4:BundleEntry[]>bundle.entry;
    foreach var entry in entries {
        r4:Resource unionResult = check entry?.'resource.cloneWithType(r4:Resource);
        string resourceType = unionResult.resourceType;

        if resourceType.equalsIgnoreCaseAscii("Patient") {
            updatedEntries.push({'resource: check transformPatient(unionResult, incomingMsg)});
        } else if resourceType.equalsIgnoreCaseAscii("Encounter") {
            updatedEntries.push({'resource: check transformEncounter(unionResult, incomingMsg)});
        } else if resourceType.equalsIgnoreCaseAscii("DiagnosticReport") {
            updatedEntries.push({'resource: check transformDiagnosticReport(unionResult, incomingMsg)});
         } else if resourceType.equalsIgnoreCaseAscii("Practitioner") {
            updatedEntries.push({'resource: check transformPractitioner(unionResult, incomingMsg)});
        } else {
            updatedEntries.push(entry);
        }
    }
    bundle.entry = updatedEntries;

    return bundle;

}


// Utility function to merge the original FHIR resource with the transformed FHIR resource.
public isolated function mergeFhirResources(r4:Resource originalResource, r4:Resource transformedResource) returns r4:Resource {
    // Merge logic here
    // This is a placeholder for the actual merge logic
    json transformed = transformedResource.toJson();
    json original = originalResource.toJson();
    json|error merged = customMergeJson(transformed, original);

    if merged is error {
        log:printError("Error merging resources. Ignoring original FHIR resource", merged);
        return transformedResource;
    }
    // Convert merged json back to FHIR resource
    r4:Resource|error mergedResource = parser:parse(merged.toString()).ensureType(r4:Resource);
    if mergedResource is error {
        log:printError("Error parsing merged resource. Ignoring original FHIR resource", mergedResource);
        return transformedResource;
    }
    return mergedResource;
}

// Utility function to merge JSON objects with precedence for first object

public isolated function customMergeJson(json firstJson, json secondJson) returns json|error {
    // Handle non-object JSON types
    if (!(firstJson is map<json>) || !(secondJson is map<json>)) {
        // If first is not an object or both are not objects, return first (precedence)
        if (!(firstJson is map<json>)) {
            return firstJson;
        }
        // If only second is not an object, return first
        return firstJson;
    }

    map<json> result = {};
    map<json> secondMap = <map<json>>secondJson;
    map<json> firstMap = <map<json>>firstJson;

    // First, add all fields from second JSON
    foreach var [key, val] in secondMap.entries() {
        // Skip empty arrays and empty strings
        if (val is string && val == "") {
            continue;
        } else if (val is json[] && val.length() == 0) {
            continue;
        } else {
            result[key] = val;
        }
    }

    // Then process all fields from first JSON (taking precedence)
    foreach var [key, val] in firstMap.entries() {
        // Skip empty arrays and empty strings
        if (val is string && val == "") {
            continue;
        } else if (val is json[] && val.length() == 0) {
            continue;
        }
        // Deep merge for nested objects
        else if (val is map<json> && result.hasKey(key) && result[key] is map<json>) {
            result[key] = check customMergeJson(val, result[key]);
        }
        // Array concatenation - combine arrays from both objects
        else if (val is json[] && result.hasKey(key) && result[key] is json[]) {
            json[] firstArray = <json[]>val;
            json[] secondArray = <json[]>result[key];

            // Single element arrays will be treated as special case
            if (firstArray.length() == 1 && secondArray.length() == 1) {
                // If both arrays have a single element, merge them
                if (val[0] is map<json> && secondArray[0] is map<json>) {
                    result[key] = [check customMergeJson(val[0], secondArray[0])];
                } else {
                    // If both arrays have a single element, keep the first one
                    result[key] = [firstArray[0]];
                }
                continue;
            }

            // Concatenate arrays, putting first object's items first
            result[key] = [...firstArray, ...secondArray];
        }
        // For all other cases, first object takes precedence
        else {
            result[key] = val;
        }
    }

    return result;
}

