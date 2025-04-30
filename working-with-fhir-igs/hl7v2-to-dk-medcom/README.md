# Ballerina HL7v2 to Danish FHIR Converter

This project demonstrates how to use Ballerina's HL7v2 to FHIR conversion utilities along with the MedCom240 Ballerina library to convert standard HL7v2 messages into Danish FHIR resources (referring MedCom Implementation Guide version 2.4.0.)

## Overview

Healthcare interoperability in Denmark requires conformance to the MedCom FHIR profiles. This utility simplifies the process of converting legacy HL7v2 messages into MedCom-compliant FHIR resources, enabling seamless integration between legacy systems and modern FHIR-based healthcare platforms.

## Features

- Convert HL7v2 ADT messages to MedCom FHIR resources
- Support for MedCom Implementation Guide v2.4.0 profiles
- Validation against Danish healthcare requirements
- Comprehensive error handling and logging

## Prerequisites

- [Ballerina](https://ballerina.io/downloads/) 2201.12.3 (Swan Lake) or newer
- Basic knowledge of HL7v2 and FHIR standards
- Knowledge of Danish healthcare standards and MedCom profiles

## HTTP Service
The transformation runs as an HTTP service. You can invoke the relevant endpoints with a valid HL7v2 ADT_A01 message to see the transformed FHIR resources. This allows for easy integration with existing systems that need to convert legacy HL7v2 messages to FHIR.

## Try Out

1. Clone this repository:
   ```bash
   git clone https://github.com/ballerina-guides/healthcare-samples.git
   cd working-with-fhir-igs/hl7v2-to-dk-medcom
   ```
2. Install dependencies:
   ```bash
   bal build
   ```

   ```
   Compiling source
        healthcare_samples/hl7v2_to_medcom_fhir:1.0.0

   Generating executable
         target/bin/hl7v2_to_medcom_fhir.jar
   ```
3. Start the server
   ```bash
   bal run
   ```
   ```
   Compiling source
        healthcare_samples/hl7v2_to_medcom_fhir:1.0.0

   Running executable

   time=2025-04-30T14:42:44.925+05:30 level=INFO module=healthcare_samples/hl7v2_to_medcom_fhir message="HL7v2 to Danish Transformation Service Started.."
   ```

### V2toFHIR Transformation with Danish profiles

Once the service is started, you can tryout the transformation using the following cURL.
```bash
curl --location 'http://localhost:9090/hl7/parse/international' \
--header 'Content-Type: text/plain' \
--data 'MSH|^~\\&|ADT1|GOOD HEALTH HOSPITAL|GHH LAB, INC.|GOOD HEALTH HOSPITAL|198808181126|SECURITY|ADT^A01^ADT_A01|MSG00001|P|2.3||
EVN|A01|200708181123||
PID|1||PATID1234^5^M11^ADT1^MR^GOOD HEALTH HOSPITAL~123456789^^^USSSA^SS||BATMAN^ADAM^A^III||19610615|M||C|2222 HOME STREET^^GREENSBORO^NC^27401-1020|GL|(555)555-2004|(555)555-2004||S||PATID12345001^2^M10^ADT1^AN^A|444333333|987654^NC|
NK1|1|NUCLEAR^NELDA^W|SPO^SPOUSE||||NK^NEXT OF KIN$
PV1|1|I|2000^2012^01||||004777^ATTEND^AARON^A|||SUR||||ADM|A0|'
```

Result will look as follows
```json
{
    "resourceType": "Bundle",
    "meta": {
        "profile": [
            "http://hl7.org/fhir/StructureDefinition/Bundle"
        ]
    },
    "type": "transaction",
    "entry": [
        {
            "resource": {
                "resourceType": "MessageHeader",
                "eventUri": "",
                "destination": [
                    {
                        "endpoint": "",
                        "name": "GHH LAB, INC."
                    }
                ],
                "source": {
                    "endpoint": "",
                    "name": "ADT1"
                },
                "eventCoding": {
                    "system": "A01",
                    "code": "ADT"
                }
            }
        },
        {
            "resource": {
                "resourceType": "Provenance",
                "agent": [],
                "activity": {
                    "coding": [
                        {
                            "display": "EVN"
                        }
                    ]
                },
                "recorded": "200708181123",
                "target": []
            }
        },
        {
            "resource": {
                "resourceType": "Patient",
                "id": "1",
                "meta": {
                    "profile": [
                        "http://medcomfhir.dk/ig/core/StructureDefinition/medcom-core-patient"
                    ]
                },
                "identifier": [
                    {
                        "value": "444333333"
                    },
                    {
                        "value": "123456789"
                    },
                    {
                        "system": "urn:oid:1.2.208.176.1.2",
                        "value": "01f025a3-4a01-1956-898a-155b7ae122f9"
                    }
                ],
                "address": [
                    {
                        "district": "GL"
                    },
                    {
                        "line": [
                            "2222 HOME STREET"
                        ],
                        "city": "GREENSBORO",
                        "state": "NC",
                        "postalCode": "27401-1020"
                    }
                ],
                "gender": "male",
                "generalPractitioner": [
                    {
                        "identifier": {
                            "use": "official",
                            "system": "urn:oid:1.2.208.176.1.1",
                            "value": ""
                        }
                    }
                ],
                "name": [
                    {
                        "given": [
                            "ADAM",
                            "A",
                            "ADAM"
                        ],
                        "use": "official",
                        "family": "BATMAN",
                        "suffix": [
                            "III"
                        ]
                    }
                ],
                "telecom": [
                    {
                        "system": "phone",
                        "use": "home"
                    },
                    {
                        "system": "phone",
                        "use": "home"
                    }
                ],
                "birthDate": "19610615",
                "maritalStatus": {
                    "coding": [
                        {
                            "code": "S"
                        }
                    ]
                }
            }
        },
        {
            "resource": {
                "resourceType": "Patient",
                "id": "1",
                "meta": {
                    "profile": [
                        "http://medcomfhir.dk/ig/core/StructureDefinition/medcom-core-patient"
                    ]
                },
                "identifier": [
                    {
                        "value": "123456789"
                    },
                    {
                        "system": "urn:oid:1.2.208.176.1.2",
                        "value": "01f025a3-4a01-1956-bd9c-b3285259bf53"
                    }
                ],
                "generalPractitioner": [
                    {
                        "identifier": {
                            "use": "official",
                            "system": "urn:oid:1.2.208.176.1.1",
                            "value": ""
                        }
                    }
                ],
                "contact": [
                    {
                        "name": {
                            "family": "NUCLEAR",
                            "given": [
                                "NELDA",
                                "W"
                            ]
                        },
                        "telecom": [
                            {
                                "system": "phone",
                                "use": "home"
                            },
                            {
                                "system": "phone",
                                "use": "home"
                            }
                        ],
                        "relationship": [
                            {
                                "coding": [
                                    {
                                        "code": "NK",
                                        "display": "NEXT OF KIN$"
                                    }
                                ]
                            }
                        ]
                    }
                ],
                "name": [
                    {
                        "given": [
                            "ADAM"
                        ],
                        "use": "official",
                        "family": "BATMAN"
                    }
                ]
            }
        },
        {
            "resource": {
                "resourceType": "Encounter",
                "meta": {
                    "profile": [
                        "http://medcomfhir.dk/ig/core/StructureDefinition/medcom-core-patient"
                    ]
                },
                "serviceType": {
                    "text": "SUR"
                },
                "hospitalization": {
                    "admitSource": {
                        "text": "ADM"
                    }
                },
                "subject": {},
                "location": [
                    {
                        "location": {
                            "display": "2000"
                        }
                    },
                    {
                        "location": {}
                    },
                ],
                "class": {
                    "code": "IMP",
                    "display": "I"
                },
                "participant": [
                    {
                        "individual": {
                            "display": "004777"
                        }
                    },
                    {
                        "individual": {
                            "display": "004777"
                        }
                    }
                ],
                "status": "in-progress"
            }
        }
    ]
}
```
