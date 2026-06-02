process VALIDATE_PARAMETERS {
    tag "$meta.id"
    container 'community.wave.seqera.io/library/jsonschema_python:6af54e0b89f96a2e'

    input:
    tuple val(meta), path(parameters_csv)
    path parameter_schema

    output:
    tuple val(meta), path(parameters_csv), stdout                              , emit: validated

    tuple val("${task.process}"), val('numorph_param_validation'), val('1.0.0'), emit: versions_numorph_validation, topic: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    """
    #!/usr/bin/env python3
    import json
    import csv
    import sys
    from jsonschema import validate, ValidationError

    # type correction function
    def coerce(value):
        if value is None:
            return None
        if value.lower() == 'true':
            return True
        if value.lower() == 'false':
            return False
        try:
            return int(value)
        except ValueError:
            pass
        try:
            return float(value)
        except ValueError:
            pass
        return value

    # Load schema
    with open('${parameter_schema}', 'r') as f:
        schema = json.load(f)

    # Read CSV and convert to dict/list for validation
    with open('${parameters_csv}') as f:
        reader = csv.DictReader(f)
        params = {
            row['Parameter']: coerce(row['Value'] if row['Value'] != '' else None)
            for row in reader
        }

    # Validate
    try:
        validate(instance=params, schema=schema)
        print(f"✓ Validation passed for ${meta.id}")
    except ValidationError as e:
        print(f"✗ Validation failed for ${meta.id}: {e.message}")
        sys.exit(1)
    """

    stub:
    """
    #!/usr/bin/env python3
    import json
    import csv
    import sys
    from jsonschema import validate, ValidationError

    print(f"✓ Validation passed for ${meta.id}")

    """


}
