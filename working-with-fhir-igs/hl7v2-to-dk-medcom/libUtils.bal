import ballerina/log;
import ballerinax/health.fhir.r4;
import ballerinax/health.fhir.r4.parser;
import ballerinax/health.hl7v2;

// This file contains utility function that will be added to v2tofhir lib


// This map holds the custom transformation functions for each resource type.
// The key is the resource type and the value is the function that will be used to transform the resource.
isolated map<enrichFhirResource> customTransformationFunctions = {
};

// Kept an option to skip the merge of original resource with transformed resource.
// This is useful when the original resource is not needed and only the transformed resource is required.
isolated boolean isSkipMergeConfig = false;

public type enrichFhirResource isolated function (r4:Resource originalResource, hl7v2:Message incomingMsg) returns r4:Resource|error;

// This function will be engaged after the v2ToFhir transformation.
public isolated function postProcessBundle(r4:Bundle bundle, hl7v2:Message incomingMsg) returns r4:Bundle|error {
    r4:BundleEntry[] updatedEntries = [];
    r4:BundleEntry[] entries = <r4:BundleEntry[]>bundle.entry;
    map<enrichFhirResource> customMappings = {};
    boolean isSkipMerge = false;

    lock {
        isSkipMerge = isSkipMergeConfig;
    }

    lock {
        customMappings = customTransformationFunctions.clone();
    }
    foreach var entry in entries {
        r4:Resource unionResult = check entry?.'resource.cloneWithType(r4:Resource);
        string resourceType = unionResult.resourceType;

        if customMappings.hasKey(resourceType) {
            enrichFhirResource customFunction = customMappings.get(resourceType);
            r4:Resource transformedResource = check customFunction(unionResult.clone(), incomingMsg.clone());
            // Merge original resource with transformed resource
            if isSkipMerge.clone() {
                updatedEntries.push({'resource: transformedResource});
            } else {
                updatedEntries.push({'resource: mergeFhirResources(unionResult, transformedResource)});
            }
        } else {
            updatedEntries.push(entry.clone());
        }
        continue;
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
    json|error merged = original.mergeJson(transformed);

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


// Utility function to add custom transformation functions
public isolated function addCustomTransformationFunction(string resourceType, enrichFhirResource customFunction) {
    lock {
        customTransformationFunctions[resourceType] = customFunction;
    }
}
