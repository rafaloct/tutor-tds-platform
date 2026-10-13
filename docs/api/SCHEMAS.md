# Schemas JSON da API

Gerados do OpenAPI; `required` significa presença obrigatória, e `null` é uma alternativa explícita. Um campo opcional sem `default` serializado pode possuir default/factory no modelo Python. OpenAPI não expressa todos os validadores cruzados: consulte as notas da operação e [regras semânticas](README.md#regras-semanticas).

[Endpoints](ENDPOINTS.md) · [OpenAPI JSON](openapi.json)

<a id="schema-ActivationInviteRequest"></a>

## ActivationInviteRequest

| Campo | Obrigatório | Tipo | Default / limites |
| --- | --- | --- | --- |
| `cpf` | sim | string (password) | writeOnly=true |
| `expires_in_hours` | não | integer | default=24; minimum=1.0; maximum=168.0 |

Schema exato:
```json
{
  "properties": {
    "cpf": {
      "type": "string",
      "format": "password",
      "title": "Cpf",
      "writeOnly": true
    },
    "expires_in_hours": {
      "type": "integer",
      "maximum": 168.0,
      "minimum": 1.0,
      "title": "Expires In Hours",
      "default": 24
    }
  },
  "type": "object",
  "required": [
    "cpf"
  ],
  "title": "ActivationInviteRequest"
}
```

<a id="schema-AssessmentAnswerKeyItem"></a>

## AssessmentAnswerKeyItem

| Campo | Obrigatório | Tipo | Default / limites |
| --- | --- | --- | --- |
| `correct_index` | sim | integer | — |
| `explanation` | sim | string | — |

Schema exato:
```json
{
  "properties": {
    "correct_index": {
      "type": "integer",
      "title": "Correct Index"
    },
    "explanation": {
      "type": "string",
      "title": "Explanation"
    }
  },
  "type": "object",
  "required": [
    "correct_index",
    "explanation"
  ],
  "title": "AssessmentAnswerKeyItem"
}
```

<a id="schema-AssessmentAttemptPage"></a>

## AssessmentAttemptPage

| Campo | Obrigatório | Tipo | Default / limites |
| --- | --- | --- | --- |
| `attempts` | sim | array de [AssessmentAttemptResponse](SCHEMAS.md#schema-AssessmentAttemptResponse) | — |
| `total` | sim | integer | — |
| `limit` | sim | integer | — |
| `offset` | sim | integer | — |

Schema exato:
```json
{
  "properties": {
    "attempts": {
      "items": {
        "$ref": "#/components/schemas/AssessmentAttemptResponse"
      },
      "type": "array",
      "title": "Attempts"
    },
    "total": {
      "type": "integer",
      "title": "Total"
    },
    "limit": {
      "type": "integer",
      "title": "Limit"
    },
    "offset": {
      "type": "integer",
      "title": "Offset"
    }
  },
  "type": "object",
  "required": [
    "attempts",
    "total",
    "limit",
    "offset"
  ],
  "title": "AssessmentAttemptPage"
}
```

<a id="schema-AssessmentAttemptResponse"></a>

## AssessmentAttemptResponse

| Campo | Obrigatório | Tipo | Default / limites |
| --- | --- | --- | --- |
| `course_id` | sim | string | minLength=1; maxLength=120 |
| `origin` | não | enum ["practice", "published_block"] | default="practice" |
| `assessment_content_id` | não | string / null | minLength=1; maxLength=180; pattern="^[A-Za-z0-9][A-Za-z0-9_.:-]*$" |
| `topic` | sim | string | minLength=1; maxLength=240 |
| `mode` | sim | enum ["quiz", "exam"] | — |
| `organization_id` | não | string / null | minLength=1; maxLength=36 |
| `program_id` | não | string / null | minLength=1; maxLength=36 |
| `class_id` | não | string / null | minLength=1; maxLength=36 |
| `membership_id` | não | string / null | minLength=1; maxLength=36 |
| `enrollment_id` | não | string / null | minLength=1; maxLength=36 |
| `legacy_enrollment_id` | não | string / null | minLength=1; maxLength=36 |
| `course_version_id` | não | string / null | minLength=1; maxLength=36 |
| `section_id` | não | string / null | minLength=1; maxLength=120 |
| `section_version_id` | não | string / null | minLength=1; maxLength=36 |
| `block_id` | não | string / null | minLength=1; maxLength=180 |
| `block_version_id` | não | string / null | minLength=1; maxLength=36 |
| `revision` | sim | integer | minimum=1.0; maximum=2147483647.0 |
| `answers` | não | object | maxProperties=500; additionalProperties={"type": "integer"} |
| `marked` | não | array de integer | maxItems=500 |
| `current_index` | sim | integer | minimum=0.0; maximum=999.0 |
| `remaining_seconds` | sim | integer | minimum=0.0; maximum=86400.0 |
| `completed` | sim | boolean | — |
| `score` | sim | integer | minimum=0.0; maximum=1000.0 |
| `updated_at` | sim | string (date-time) | — |
| `attempt_id` | sim | string | — |

Schema exato:
```json
{
  "properties": {
    "course_id": {
      "type": "string",
      "maxLength": 120,
      "minLength": 1,
      "title": "Course Id"
    },
    "origin": {
      "type": "string",
      "enum": [
        "practice",
        "published_block"
      ],
      "title": "Origin",
      "default": "practice"
    },
    "assessment_content_id": {
      "anyOf": [
        {
          "type": "string",
          "maxLength": 180,
          "minLength": 1,
          "pattern": "^[A-Za-z0-9][A-Za-z0-9_.:-]*$"
        },
        {
          "type": "null"
        }
      ],
      "title": "Assessment Content Id"
    },
    "topic": {
      "type": "string",
      "maxLength": 240,
      "minLength": 1,
      "title": "Topic"
    },
    "mode": {
      "type": "string",
      "enum": [
        "quiz",
        "exam"
      ],
      "title": "Mode"
    },
    "organization_id": {
      "anyOf": [
        {
          "type": "string",
          "maxLength": 36,
          "minLength": 1
        },
        {
          "type": "null"
        }
      ],
      "title": "Organization Id"
    },
    "program_id": {
      "anyOf": [
        {
          "type": "string",
          "maxLength": 36,
          "minLength": 1
        },
        {
          "type": "null"
        }
      ],
      "title": "Program Id"
    },
    "class_id": {
      "anyOf": [
        {
          "type": "string",
          "maxLength": 36,
          "minLength": 1
        },
        {
          "type": "null"
        }
      ],
      "title": "Class Id"
    },
    "membership_id": {
      "anyOf": [
        {
          "type": "string",
          "maxLength": 36,
          "minLength": 1
        },
        {
          "type": "null"
        }
      ],
      "title": "Membership Id"
    },
    "enrollment_id": {
      "anyOf": [
        {
          "type": "string",
          "maxLength": 36,
          "minLength": 1
        },
        {
          "type": "null"
        }
      ],
      "title": "Enrollment Id"
    },
    "legacy_enrollment_id": {
      "anyOf": [
        {
          "type": "string",
          "maxLength": 36,
          "minLength": 1
        },
        {
          "type": "null"
        }
      ],
      "title": "Legacy Enrollment Id"
    },
    "course_version_id": {
      "anyOf": [
        {
          "type": "string",
          "maxLength": 36,
          "minLength": 1
        },
        {
          "type": "null"
        }
      ],
      "title": "Course Version Id"
    },
    "section_id": {
      "anyOf": [
        {
          "type": "string",
          "maxLength": 120,
          "minLength": 1
        },
        {
          "type": "null"
        }
      ],
      "title": "Section Id"
    },
    "section_version_id": {
      "anyOf": [
        {
          "type": "string",
          "maxLength": 36,
          "minLength": 1
        },
        {
          "type": "null"
        }
      ],
      "title": "Section Version Id"
    },
    "block_id": {
      "anyOf": [
        {
          "type": "string",
          "maxLength": 180,
          "minLength": 1
        },
        {
          "type": "null"
        }
      ],
      "title": "Block Id"
    },
    "block_version_id": {
      "anyOf": [
        {
          "type": "string",
          "maxLength": 36,
          "minLength": 1
        },
        {
          "type": "null"
        }
      ],
      "title": "Block Version Id"
    },
    "revision": {
      "type": "integer",
      "maximum": 2147483647.0,
      "minimum": 1.0,
      "title": "Revision"
    },
    "answers": {
      "additionalProperties": {
        "type": "integer"
      },
      "type": "object",
      "maxProperties": 500,
      "title": "Answers"
    },
    "marked": {
      "items": {
        "type": "integer"
      },
      "type": "array",
      "maxItems": 500,
      "title": "Marked"
    },
    "current_index": {
      "type": "integer",
      "maximum": 999.0,
      "minimum": 0.0,
      "title": "Current Index"
    },
    "remaining_seconds": {
      "type": "integer",
      "maximum": 86400.0,
      "minimum": 0.0,
      "title": "Remaining Seconds"
    },
    "completed": {
      "type": "boolean",
      "title": "Completed"
    },
    "score": {
      "type": "integer",
      "maximum": 1000.0,
      "minimum": 0.0,
      "title": "Score"
    },
    "updated_at": {
      "type": "string",
      "format": "date-time",
      "title": "Updated At"
    },
    "attempt_id": {
      "type": "string",
      "title": "Attempt Id"
    }
  },
  "additionalProperties": false,
  "type": "object",
  "required": [
    "course_id",
    "topic",
    "mode",
    "revision",
    "current_index",
    "remaining_seconds",
    "completed",
    "score",
    "updated_at",
    "attempt_id"
  ],
  "title": "AssessmentAttemptResponse"
}
```

<a id="schema-AssessmentAttemptUpsert"></a>

## AssessmentAttemptUpsert

| Campo | Obrigatório | Tipo | Default / limites |
| --- | --- | --- | --- |
| `course_id` | sim | string | minLength=1; maxLength=120 |
| `origin` | não | enum ["practice", "published_block"] | default="practice" |
| `assessment_content_id` | não | string / null | minLength=1; maxLength=180; pattern="^[A-Za-z0-9][A-Za-z0-9_.:-]*$" |
| `topic` | sim | string | minLength=1; maxLength=240 |
| `mode` | sim | enum ["quiz", "exam"] | — |
| `organization_id` | não | string / null | minLength=1; maxLength=36 |
| `program_id` | não | string / null | minLength=1; maxLength=36 |
| `class_id` | não | string / null | minLength=1; maxLength=36 |
| `membership_id` | não | string / null | minLength=1; maxLength=36 |
| `enrollment_id` | não | string / null | minLength=1; maxLength=36 |
| `legacy_enrollment_id` | não | string / null | minLength=1; maxLength=36 |
| `course_version_id` | não | string / null | minLength=1; maxLength=36 |
| `section_id` | não | string / null | minLength=1; maxLength=120 |
| `section_version_id` | não | string / null | minLength=1; maxLength=36 |
| `block_id` | não | string / null | minLength=1; maxLength=180 |
| `block_version_id` | não | string / null | minLength=1; maxLength=36 |
| `revision` | sim | integer | minimum=1.0; maximum=2147483647.0 |
| `answers` | não | object | maxProperties=500; additionalProperties={"type": "integer"} |
| `marked` | não | array de integer | maxItems=500 |
| `current_index` | sim | integer | minimum=0.0; maximum=999.0 |
| `remaining_seconds` | sim | integer | minimum=0.0; maximum=86400.0 |
| `completed` | sim | boolean | — |
| `score` | sim | integer | minimum=0.0; maximum=1000.0 |
| `updated_at` | sim | string (date-time) | — |

Schema exato:
```json
{
  "properties": {
    "course_id": {
      "type": "string",
      "maxLength": 120,
      "minLength": 1,
      "title": "Course Id"
    },
    "origin": {
      "type": "string",
      "enum": [
        "practice",
        "published_block"
      ],
      "title": "Origin",
      "default": "practice"
    },
    "assessment_content_id": {
      "anyOf": [
        {
          "type": "string",
          "maxLength": 180,
          "minLength": 1,
          "pattern": "^[A-Za-z0-9][A-Za-z0-9_.:-]*$"
        },
        {
          "type": "null"
        }
      ],
      "title": "Assessment Content Id"
    },
    "topic": {
      "type": "string",
      "maxLength": 240,
      "minLength": 1,
      "title": "Topic"
    },
    "mode": {
      "type": "string",
      "enum": [
        "quiz",
        "exam"
      ],
      "title": "Mode"
    },
    "organization_id": {
      "anyOf": [
        {
          "type": "string",
          "maxLength": 36,
          "minLength": 1
        },
        {
          "type": "null"
        }
      ],
      "title": "Organization Id"
    },
    "program_id": {
      "anyOf": [
        {
          "type": "string",
          "maxLength": 36,
          "minLength": 1
        },
        {
          "type": "null"
        }
      ],
      "title": "Program Id"
    },
    "class_id": {
      "anyOf": [
        {
          "type": "string",
          "maxLength": 36,
          "minLength": 1
        },
        {
          "type": "null"
        }
      ],
      "title": "Class Id"
    },
    "membership_id": {
      "anyOf": [
        {
          "type": "string",
          "maxLength": 36,
          "minLength": 1
        },
        {
          "type": "null"
        }
      ],
      "title": "Membership Id"
    },
    "enrollment_id": {
      "anyOf": [
        {
          "type": "string",
          "maxLength": 36,
          "minLength": 1
        },
        {
          "type": "null"
        }
      ],
      "title": "Enrollment Id"
    },
    "legacy_enrollment_id": {
      "anyOf": [
        {
          "type": "string",
          "maxLength": 36,
          "minLength": 1
        },
        {
          "type": "null"
        }
      ],
      "title": "Legacy Enrollment Id"
    },
    "course_version_id": {
      "anyOf": [
        {
          "type": "string",
          "maxLength": 36,
          "minLength": 1
        },
        {
          "type": "null"
        }
      ],
      "title": "Course Version Id"
    },
    "section_id": {
      "anyOf": [
        {
          "type": "string",
          "maxLength": 120,
          "minLength": 1
        },
        {
          "type": "null"
        }
      ],
      "title": "Section Id"
    },
    "section_version_id": {
      "anyOf": [
        {
          "type": "string",
          "maxLength": 36,
          "minLength": 1
        },
        {
          "type": "null"
        }
      ],
      "title": "Section Version Id"
    },
    "block_id": {
      "anyOf": [
        {
          "type": "string",
          "maxLength": 180,
          "minLength": 1
        },
        {
          "type": "null"
        }
      ],
      "title": "Block Id"
    },
    "block_version_id": {
      "anyOf": [
        {
          "type": "string",
          "maxLength": 36,
          "minLength": 1
        },
        {
          "type": "null"
        }
      ],
      "title": "Block Version Id"
    },
    "revision": {
      "type": "integer",
      "maximum": 2147483647.0,
      "minimum": 1.0,
      "title": "Revision"
    },
    "answers": {
      "additionalProperties": {
        "type": "integer"
      },
      "type": "object",
      "maxProperties": 500,
      "title": "Answers"
    },
    "marked": {
      "items": {
        "type": "integer"
      },
      "type": "array",
      "maxItems": 500,
      "title": "Marked"
    },
    "current_index": {
      "type": "integer",
      "maximum": 999.0,
      "minimum": 0.0,
      "title": "Current Index"
    },
    "remaining_seconds": {
      "type": "integer",
      "maximum": 86400.0,
      "minimum": 0.0,
      "title": "Remaining Seconds"
    },
    "completed": {
      "type": "boolean",
      "title": "Completed"
    },
    "score": {
      "type": "integer",
      "maximum": 1000.0,
      "minimum": 0.0,
      "title": "Score"
    },
    "updated_at": {
      "type": "string",
      "format": "date-time",
      "title": "Updated At"
    }
  },
  "additionalProperties": false,
  "type": "object",
  "required": [
    "course_id",
    "topic",
    "mode",
    "revision",
    "current_index",
    "remaining_seconds",
    "completed",
    "score",
    "updated_at"
  ],
  "title": "AssessmentAttemptUpsert"
}
```

<a id="schema-AssessmentContentResponse"></a>

## AssessmentContentResponse

| Campo | Obrigatório | Tipo | Default / limites |
| --- | --- | --- | --- |
| `assessment_content_id` | sim | string | — |
| `course_id` | sim | string | — |
| `topic` | sim | string | — |
| `mode` | sim | enum ["quiz", "exam"] | — |
| `title` | sim | string | — |
| `duration_seconds` | sim | integer | — |
| `questions` | sim | array de [AssessmentQuestionPublic](SCHEMAS.md#schema-AssessmentQuestionPublic) | — |
| `answer_key` | sim | array de [AssessmentAnswerKeyItem](SCHEMAS.md#schema-AssessmentAnswerKeyItem) / [PublishedBlockAnswerKeyItem](SCHEMAS.md#schema-PublishedBlockAnswerKeyItem) / null | — |
| `created_at` | sim | string (date-time) | — |

Schema exato:
```json
{
  "properties": {
    "assessment_content_id": {
      "type": "string",
      "title": "Assessment Content Id"
    },
    "course_id": {
      "type": "string",
      "title": "Course Id"
    },
    "topic": {
      "type": "string",
      "title": "Topic"
    },
    "mode": {
      "type": "string",
      "enum": [
        "quiz",
        "exam"
      ],
      "title": "Mode"
    },
    "title": {
      "type": "string",
      "title": "Title"
    },
    "duration_seconds": {
      "type": "integer",
      "title": "Duration Seconds"
    },
    "questions": {
      "items": {
        "$ref": "#/components/schemas/AssessmentQuestionPublic"
      },
      "type": "array",
      "title": "Questions"
    },
    "answer_key": {
      "anyOf": [
        {
          "items": {
            "anyOf": [
              {
                "$ref": "#/components/schemas/AssessmentAnswerKeyItem"
              },
              {
                "$ref": "#/components/schemas/PublishedBlockAnswerKeyItem"
              }
            ]
          },
          "type": "array"
        },
        {
          "type": "null"
        }
      ],
      "title": "Answer Key"
    },
    "created_at": {
      "type": "string",
      "format": "date-time",
      "title": "Created At"
    }
  },
  "type": "object",
  "required": [
    "assessment_content_id",
    "course_id",
    "topic",
    "mode",
    "title",
    "duration_seconds",
    "questions",
    "answer_key",
    "created_at"
  ],
  "title": "AssessmentContentResponse"
}
```

<a id="schema-AssessmentContentUpsert"></a>

## AssessmentContentUpsert

| Campo | Obrigatório | Tipo | Default / limites |
| --- | --- | --- | --- |
| `course_id` | sim | string | minLength=1; maxLength=120 |
| `topic` | sim | string | minLength=1; maxLength=240 |
| `mode` | sim | enum ["quiz", "exam"] | — |
| `title` | sim | string | minLength=1; maxLength=240 |
| `duration_seconds` | sim | integer | minimum=0.0; maximum=86400.0 |
| `questions` | sim | array de [AssessmentQuestionInput](SCHEMAS.md#schema-AssessmentQuestionInput) | minItems=1; maxItems=100 |

Schema exato:
```json
{
  "properties": {
    "course_id": {
      "type": "string",
      "maxLength": 120,
      "minLength": 1,
      "title": "Course Id"
    },
    "topic": {
      "type": "string",
      "maxLength": 240,
      "minLength": 1,
      "title": "Topic"
    },
    "mode": {
      "type": "string",
      "enum": [
        "quiz",
        "exam"
      ],
      "title": "Mode"
    },
    "title": {
      "type": "string",
      "maxLength": 240,
      "minLength": 1,
      "title": "Title"
    },
    "duration_seconds": {
      "type": "integer",
      "maximum": 86400.0,
      "minimum": 0.0,
      "title": "Duration Seconds"
    },
    "questions": {
      "items": {
        "$ref": "#/components/schemas/AssessmentQuestionInput"
      },
      "type": "array",
      "maxItems": 100,
      "minItems": 1,
      "title": "Questions"
    }
  },
  "additionalProperties": false,
  "type": "object",
  "required": [
    "course_id",
    "topic",
    "mode",
    "title",
    "duration_seconds",
    "questions"
  ],
  "title": "AssessmentContentUpsert"
}
```

<a id="schema-AssessmentQuestionInput"></a>

## AssessmentQuestionInput

| Campo | Obrigatório | Tipo | Default / limites |
| --- | --- | --- | --- |
| `question` | sim | string | minLength=1; maxLength=1000 |
| `options` | sim | array de string | minItems=2; maxItems=8 |
| `correct_index` | sim | integer | minimum=0.0; maximum=7.0 |
| `explanation` | não | string | default=""; maxLength=2000 |
| `topic` | sim | string | minLength=1; maxLength=240 |

Schema exato:
```json
{
  "properties": {
    "question": {
      "type": "string",
      "maxLength": 1000,
      "minLength": 1,
      "title": "Question"
    },
    "options": {
      "items": {
        "type": "string"
      },
      "type": "array",
      "maxItems": 8,
      "minItems": 2,
      "title": "Options"
    },
    "correct_index": {
      "type": "integer",
      "maximum": 7.0,
      "minimum": 0.0,
      "title": "Correct Index"
    },
    "explanation": {
      "type": "string",
      "maxLength": 2000,
      "title": "Explanation",
      "default": ""
    },
    "topic": {
      "type": "string",
      "maxLength": 240,
      "minLength": 1,
      "title": "Topic"
    }
  },
  "additionalProperties": false,
  "type": "object",
  "required": [
    "question",
    "options",
    "correct_index",
    "topic"
  ],
  "title": "AssessmentQuestionInput"
}
```

<a id="schema-AssessmentQuestionPublic"></a>

## AssessmentQuestionPublic

| Campo | Obrigatório | Tipo | Default / limites |
| --- | --- | --- | --- |
| `question` | sim | string | — |
| `options` | sim | array de string | — |
| `topic` | sim | string | — |

Schema exato:
```json
{
  "properties": {
    "question": {
      "type": "string",
      "title": "Question"
    },
    "options": {
      "items": {
        "type": "string"
      },
      "type": "array",
      "title": "Options"
    },
    "topic": {
      "type": "string",
      "title": "Topic"
    }
  },
  "type": "object",
  "required": [
    "question",
    "options",
    "topic"
  ],
  "title": "AssessmentQuestionPublic"
}
```

<a id="schema-BaselinePut"></a>

## BaselinePut

| Campo | Obrigatório | Tipo | Default / limites |
| --- | --- | --- | --- |
| `reason` | sim | string | minLength=3; maxLength=500 |
| `idempotency_key` | sim | string | minLength=8; maxLength=180; pattern="^[A-Za-z0-9_.:-]+$" |
| `expected_revision` | sim | integer | minimum=0.0 |
| `source` | sim | string | minLength=1; maxLength=120; pattern="^[A-Za-z0-9_.:-]+$" |
| `record_id` | sim | string | minLength=1; maxLength=240 |
| `baseline_date` | sim | string (date) | — |
| `territory_id` | não | string / null | minLength=1; maxLength=120 |
| `bi_record_id` | não | string / null | minLength=1; maxLength=120; pattern="^[A-Za-z0-9][A-Za-z0-9_.:-]*$" |

Schema exato:
```json
{
  "properties": {
    "reason": {
      "type": "string",
      "maxLength": 500,
      "minLength": 3,
      "title": "Reason"
    },
    "idempotency_key": {
      "type": "string",
      "maxLength": 180,
      "minLength": 8,
      "pattern": "^[A-Za-z0-9_.:-]+$",
      "title": "Idempotency Key"
    },
    "expected_revision": {
      "type": "integer",
      "minimum": 0.0,
      "title": "Expected Revision"
    },
    "source": {
      "type": "string",
      "maxLength": 120,
      "minLength": 1,
      "pattern": "^[A-Za-z0-9_.:-]+$",
      "title": "Source"
    },
    "record_id": {
      "type": "string",
      "maxLength": 240,
      "minLength": 1,
      "title": "Record Id"
    },
    "baseline_date": {
      "type": "string",
      "format": "date",
      "title": "Baseline Date"
    },
    "territory_id": {
      "anyOf": [
        {
          "type": "string",
          "maxLength": 120,
          "minLength": 1
        },
        {
          "type": "null"
        }
      ],
      "title": "Territory Id"
    },
    "bi_record_id": {
      "anyOf": [
        {
          "type": "string",
          "maxLength": 120,
          "minLength": 1,
          "pattern": "^[A-Za-z0-9][A-Za-z0-9_.:-]*$"
        },
        {
          "type": "null"
        }
      ],
      "title": "Bi Record Id"
    }
  },
  "additionalProperties": false,
  "type": "object",
  "required": [
    "reason",
    "idempotency_key",
    "expected_revision",
    "source",
    "record_id",
    "baseline_date"
  ],
  "title": "BaselinePut"
}
```

<a id="schema-Caption"></a>

## Caption

| Campo | Obrigatório | Tipo | Default / limites |
| --- | --- | --- | --- |
| `language` | sim | string | pattern="^[a-z]{2,3}(?:-[A-Z]{2})?$" |
| `label` | não | string / null | maxLength=80 |
| `format` | sim | const "vtt" | — |
| `reference` | sim | string | minLength=1; maxLength=500 |

Schema exato:
```json
{
  "properties": {
    "language": {
      "type": "string",
      "pattern": "^[a-z]{2,3}(?:-[A-Z]{2})?$",
      "title": "Language"
    },
    "label": {
      "anyOf": [
        {
          "type": "string",
          "maxLength": 80
        },
        {
          "type": "null"
        }
      ],
      "title": "Label"
    },
    "format": {
      "type": "string",
      "const": "vtt",
      "title": "Format"
    },
    "reference": {
      "type": "string",
      "maxLength": 500,
      "minLength": 1,
      "title": "Reference"
    }
  },
  "additionalProperties": false,
  "type": "object",
  "required": [
    "language",
    "format",
    "reference"
  ],
  "title": "Caption"
}
```

<a id="schema-CaseCreate"></a>

## CaseCreate

| Campo | Obrigatório | Tipo | Default / limites |
| --- | --- | --- | --- |
| `reason` | sim | string | minLength=3; maxLength=500 |
| `idempotency_key` | sim | string | minLength=8; maxLength=180; pattern="^[A-Za-z0-9_.:-]+$" |
| `user_id` | sim | string | minLength=1; maxLength=36 |
| `mentor_id` | sim | string | minLength=1; maxLength=36 |
| `objective` | sim | string | minLength=3; maxLength=1000 |
| `next_action` | sim | string | minLength=3; maxLength=1000 |

Schema exato:
```json
{
  "properties": {
    "reason": {
      "type": "string",
      "maxLength": 500,
      "minLength": 3,
      "title": "Reason"
    },
    "idempotency_key": {
      "type": "string",
      "maxLength": 180,
      "minLength": 8,
      "pattern": "^[A-Za-z0-9_.:-]+$",
      "title": "Idempotency Key"
    },
    "user_id": {
      "type": "string",
      "maxLength": 36,
      "minLength": 1,
      "title": "User Id"
    },
    "mentor_id": {
      "type": "string",
      "maxLength": 36,
      "minLength": 1,
      "title": "Mentor Id"
    },
    "objective": {
      "type": "string",
      "maxLength": 1000,
      "minLength": 3,
      "title": "Objective"
    },
    "next_action": {
      "type": "string",
      "maxLength": 1000,
      "minLength": 3,
      "title": "Next Action"
    }
  },
  "additionalProperties": false,
  "type": "object",
  "required": [
    "reason",
    "idempotency_key",
    "user_id",
    "mentor_id",
    "objective",
    "next_action"
  ],
  "title": "CaseCreate"
}
```

<a id="schema-CasePatch"></a>

## CasePatch

| Campo | Obrigatório | Tipo | Default / limites |
| --- | --- | --- | --- |
| `reason` | sim | string | minLength=3; maxLength=500 |
| `idempotency_key` | sim | string | minLength=8; maxLength=180; pattern="^[A-Za-z0-9_.:-]+$" |
| `expected_revision` | sim | integer | minimum=1.0 |
| `mentor_id` | não | string / null | minLength=1; maxLength=36 |
| `objective` | não | string / null | minLength=3; maxLength=1000 |
| `next_action` | não | string / null | minLength=3; maxLength=1000 |
| `status` | não | enum ["open", "in_progress", "closed"] / null | — |

Schema exato:
```json
{
  "properties": {
    "reason": {
      "type": "string",
      "maxLength": 500,
      "minLength": 3,
      "title": "Reason"
    },
    "idempotency_key": {
      "type": "string",
      "maxLength": 180,
      "minLength": 8,
      "pattern": "^[A-Za-z0-9_.:-]+$",
      "title": "Idempotency Key"
    },
    "expected_revision": {
      "type": "integer",
      "minimum": 1.0,
      "title": "Expected Revision"
    },
    "mentor_id": {
      "anyOf": [
        {
          "type": "string",
          "maxLength": 36,
          "minLength": 1
        },
        {
          "type": "null"
        }
      ],
      "title": "Mentor Id"
    },
    "objective": {
      "anyOf": [
        {
          "type": "string",
          "maxLength": 1000,
          "minLength": 3
        },
        {
          "type": "null"
        }
      ],
      "title": "Objective"
    },
    "next_action": {
      "anyOf": [
        {
          "type": "string",
          "maxLength": 1000,
          "minLength": 3
        },
        {
          "type": "null"
        }
      ],
      "title": "Next Action"
    },
    "status": {
      "anyOf": [
        {
          "type": "string",
          "enum": [
            "open",
            "in_progress",
            "closed"
          ]
        },
        {
          "type": "null"
        }
      ],
      "title": "Status"
    }
  },
  "additionalProperties": false,
  "type": "object",
  "required": [
    "reason",
    "idempotency_key",
    "expected_revision"
  ],
  "title": "CasePatch"
}
```

<a id="schema-CertificatePage"></a>

## CertificatePage

| Campo | Obrigatório | Tipo | Default / limites |
| --- | --- | --- | --- |
| `certificates` | sim | array de [CertificateReferenceResponse](SCHEMAS.md#schema-CertificateReferenceResponse) | — |

Schema exato:
```json
{
  "properties": {
    "certificates": {
      "items": {
        "$ref": "#/components/schemas/CertificateReferenceResponse"
      },
      "type": "array",
      "title": "Certificates"
    }
  },
  "type": "object",
  "required": [
    "certificates"
  ],
  "title": "CertificatePage"
}
```

<a id="schema-CertificateReferenceCreate"></a>

## CertificateReferenceCreate

| Campo | Obrigatório | Tipo | Default / limites |
| --- | --- | --- | --- |
| `id` | sim | string | minLength=8; maxLength=120 |
| `program_id` | sim | string | minLength=1; maxLength=36 |
| `course_id` | sim | string | minLength=1; maxLength=120 |
| `class_id` | não | string / null | minLength=1; maxLength=36 |
| `issued_at` | sim | string (date-time) | — |
| `verification_url` | sim | string (uri) | minLength=1; maxLength=2083 |
| `content_hash` | sim | string | — |

Schema exato:
```json
{
  "properties": {
    "id": {
      "type": "string",
      "maxLength": 120,
      "minLength": 8,
      "title": "Id"
    },
    "program_id": {
      "type": "string",
      "maxLength": 36,
      "minLength": 1,
      "title": "Program Id"
    },
    "course_id": {
      "type": "string",
      "maxLength": 120,
      "minLength": 1,
      "title": "Course Id"
    },
    "class_id": {
      "anyOf": [
        {
          "type": "string",
          "maxLength": 36,
          "minLength": 1
        },
        {
          "type": "null"
        }
      ],
      "title": "Class Id"
    },
    "issued_at": {
      "type": "string",
      "format": "date-time",
      "title": "Issued At"
    },
    "verification_url": {
      "type": "string",
      "maxLength": 2083,
      "minLength": 1,
      "format": "uri",
      "title": "Verification Url"
    },
    "content_hash": {
      "type": "string",
      "title": "Content Hash"
    }
  },
  "additionalProperties": false,
  "type": "object",
  "required": [
    "id",
    "program_id",
    "course_id",
    "issued_at",
    "verification_url",
    "content_hash"
  ],
  "title": "CertificateReferenceCreate"
}
```

<a id="schema-CertificateReferenceResponse"></a>

## CertificateReferenceResponse

| Campo | Obrigatório | Tipo | Default / limites |
| --- | --- | --- | --- |
| `id` | sim | string | — |
| `user_id` | sim | string | — |
| `program_id` | sim | string / null | — |
| `course_id` | sim | string | — |
| `class_id` | sim | string / null | — |
| `holder_name` | sim | string / null | — |
| `course_title` | sim | string / null | — |
| `institution_name` | sim | string / null | — |
| `planned_hours` | sim | number / null | — |
| `issued_at` | sim | string (date-time) | — |
| `verification_url` | sim | string | — |
| `content_hash` | sim | string | — |

Schema exato:
```json
{
  "properties": {
    "id": {
      "type": "string",
      "title": "Id"
    },
    "user_id": {
      "type": "string",
      "title": "User Id"
    },
    "program_id": {
      "anyOf": [
        {
          "type": "string"
        },
        {
          "type": "null"
        }
      ],
      "title": "Program Id"
    },
    "course_id": {
      "type": "string",
      "title": "Course Id"
    },
    "class_id": {
      "anyOf": [
        {
          "type": "string"
        },
        {
          "type": "null"
        }
      ],
      "title": "Class Id"
    },
    "holder_name": {
      "anyOf": [
        {
          "type": "string"
        },
        {
          "type": "null"
        }
      ],
      "title": "Holder Name"
    },
    "course_title": {
      "anyOf": [
        {
          "type": "string"
        },
        {
          "type": "null"
        }
      ],
      "title": "Course Title"
    },
    "institution_name": {
      "anyOf": [
        {
          "type": "string"
        },
        {
          "type": "null"
        }
      ],
      "title": "Institution Name"
    },
    "planned_hours": {
      "anyOf": [
        {
          "type": "number"
        },
        {
          "type": "null"
        }
      ],
      "title": "Planned Hours"
    },
    "issued_at": {
      "type": "string",
      "format": "date-time",
      "title": "Issued At"
    },
    "verification_url": {
      "type": "string",
      "title": "Verification Url"
    },
    "content_hash": {
      "type": "string",
      "title": "Content Hash"
    }
  },
  "type": "object",
  "required": [
    "id",
    "user_id",
    "program_id",
    "course_id",
    "class_id",
    "holder_name",
    "course_title",
    "institution_name",
    "planned_hours",
    "issued_at",
    "verification_url",
    "content_hash"
  ],
  "title": "CertificateReferenceResponse"
}
```

<a id="schema-CheckinCreate"></a>

## CheckinCreate

| Campo | Obrigatório | Tipo | Default / limites |
| --- | --- | --- | --- |
| `kind` | sim | enum ["checkin", "checkout"] | — |
| `idempotency_key` | sim | string | minLength=8; maxLength=180; pattern="^[A-Za-z0-9_.:-]+$" |
| `token` | não | string / null | maxLength=200 |
| `user_id` | não | string / null | maxLength=36 |

Schema exato:
```json
{
  "properties": {
    "kind": {
      "type": "string",
      "enum": [
        "checkin",
        "checkout"
      ],
      "title": "Kind"
    },
    "idempotency_key": {
      "type": "string",
      "maxLength": 180,
      "minLength": 8,
      "pattern": "^[A-Za-z0-9_.:-]+$",
      "title": "Idempotency Key"
    },
    "token": {
      "anyOf": [
        {
          "type": "string",
          "maxLength": 200
        },
        {
          "type": "null"
        }
      ],
      "title": "Token"
    },
    "user_id": {
      "anyOf": [
        {
          "type": "string",
          "maxLength": 36
        },
        {
          "type": "null"
        }
      ],
      "title": "User Id"
    }
  },
  "additionalProperties": false,
  "type": "object",
  "required": [
    "kind",
    "idempotency_key"
  ],
  "title": "CheckinCreate"
}
```

<a id="schema-CheckinResponse"></a>

## CheckinResponse

| Campo | Obrigatório | Tipo | Default / limites |
| --- | --- | --- | --- |
| `id` | sim | string | — |
| `session_id` | sim | string | — |
| `user_id` | sim | string | — |
| `kind` | sim | string | — |
| `occurred_at` | sim | string (date-time) | — |
| `method` | sim | string | — |
| `evidence_id` | sim | string | — |

Schema exato:
```json
{
  "properties": {
    "id": {
      "type": "string",
      "title": "Id"
    },
    "session_id": {
      "type": "string",
      "title": "Session Id"
    },
    "user_id": {
      "type": "string",
      "title": "User Id"
    },
    "kind": {
      "type": "string",
      "title": "Kind"
    },
    "occurred_at": {
      "type": "string",
      "format": "date-time",
      "title": "Occurred At"
    },
    "method": {
      "type": "string",
      "title": "Method"
    },
    "evidence_id": {
      "type": "string",
      "title": "Evidence Id"
    }
  },
  "type": "object",
  "required": [
    "id",
    "session_id",
    "user_id",
    "kind",
    "occurred_at",
    "method",
    "evidence_id"
  ],
  "title": "CheckinResponse"
}
```

<a id="schema-CheckpointComplete"></a>

## CheckpointComplete

| Campo | Obrigatório | Tipo | Default / limites |
| --- | --- | --- | --- |
| `answers` | sim | object | additionalProperties={"type": "integer"} |

Schema exato:
```json
{
  "properties": {
    "answers": {
      "additionalProperties": {
        "type": "integer"
      },
      "type": "object",
      "title": "Answers"
    }
  },
  "additionalProperties": false,
  "type": "object",
  "required": [
    "answers"
  ],
  "title": "CheckpointComplete"
}
```

<a id="schema-CheckpointConfig"></a>

## CheckpointConfig

| Campo | Obrigatório | Tipo | Default / limites |
| --- | --- | --- | --- |
| `id` | sim | string | minLength=1; maxLength=80; pattern="^[A-Za-z0-9_.:-]+$" |
| `kind` | sim | string | minLength=1; maxLength=48 |
| `source_id` | sim | string | minLength=1; maxLength=180 |

Schema exato:
```json
{
  "properties": {
    "id": {
      "type": "string",
      "maxLength": 80,
      "minLength": 1,
      "pattern": "^[A-Za-z0-9_.:-]+$",
      "title": "Id"
    },
    "kind": {
      "type": "string",
      "maxLength": 48,
      "minLength": 1,
      "title": "Kind"
    },
    "source_id": {
      "type": "string",
      "maxLength": 180,
      "minLength": 1,
      "title": "Source Id"
    }
  },
  "additionalProperties": false,
  "type": "object",
  "required": [
    "id",
    "kind",
    "source_id"
  ],
  "title": "CheckpointConfig"
}
```

<a id="schema-ClassroomCreate"></a>

## ClassroomCreate

| Campo | Obrigatório | Tipo | Default / limites |
| --- | --- | --- | --- |
| `program_id` | sim | string | minLength=1; maxLength=36 |
| `course_id` | sim | string | minLength=1; maxLength=120 |
| `teacher_id` | sim | string | minLength=1; maxLength=36 |
| `name` | sim | string | minLength=2; maxLength=240 |
| `offer_municipality` | não | string / null | maxLength=240 |
| `offer_location` | não | string / null | maxLength=500 |
| `start_date` | sim | string (date) | — |
| `end_date` | sim | string (date) | — |
| `status` | não | enum ["planned", "active", "closed"] | default="planned" |

Schema exato:
```json
{
  "properties": {
    "program_id": {
      "type": "string",
      "maxLength": 36,
      "minLength": 1,
      "title": "Program Id"
    },
    "course_id": {
      "type": "string",
      "maxLength": 120,
      "minLength": 1,
      "title": "Course Id"
    },
    "teacher_id": {
      "type": "string",
      "maxLength": 36,
      "minLength": 1,
      "title": "Teacher Id"
    },
    "name": {
      "type": "string",
      "maxLength": 240,
      "minLength": 2,
      "title": "Name"
    },
    "offer_municipality": {
      "anyOf": [
        {
          "type": "string",
          "maxLength": 240
        },
        {
          "type": "null"
        }
      ],
      "title": "Offer Municipality"
    },
    "offer_location": {
      "anyOf": [
        {
          "type": "string",
          "maxLength": 500
        },
        {
          "type": "null"
        }
      ],
      "title": "Offer Location"
    },
    "start_date": {
      "type": "string",
      "format": "date",
      "title": "Start Date"
    },
    "end_date": {
      "type": "string",
      "format": "date",
      "title": "End Date"
    },
    "status": {
      "type": "string",
      "enum": [
        "planned",
        "active",
        "closed"
      ],
      "title": "Status",
      "default": "planned"
    }
  },
  "additionalProperties": false,
  "type": "object",
  "required": [
    "program_id",
    "course_id",
    "teacher_id",
    "name",
    "start_date",
    "end_date"
  ],
  "title": "ClassroomCreate"
}
```

<a id="schema-ClassroomDashboard"></a>

## ClassroomDashboard

| Campo | Obrigatório | Tipo | Default / limites |
| --- | --- | --- | --- |
| `classroom` | sim | [ClassroomResponse](SCHEMAS.md#schema-ClassroomResponse) | — |
| `generated_at` | sim | string (date-time) | — |
| `expected_progress_percent` | sim | number | — |
| `summary` | sim | [DashboardSummary](SCHEMAS.md#schema-DashboardSummary) | — |
| `students` | sim | array de [StudentProgress](SCHEMAS.md#schema-StudentProgress) | — |

Schema exato:
```json
{
  "properties": {
    "classroom": {
      "$ref": "#/components/schemas/ClassroomResponse"
    },
    "generated_at": {
      "type": "string",
      "format": "date-time",
      "title": "Generated At"
    },
    "expected_progress_percent": {
      "type": "number",
      "title": "Expected Progress Percent"
    },
    "summary": {
      "$ref": "#/components/schemas/DashboardSummary"
    },
    "students": {
      "items": {
        "$ref": "#/components/schemas/StudentProgress"
      },
      "type": "array",
      "title": "Students"
    }
  },
  "type": "object",
  "required": [
    "classroom",
    "generated_at",
    "expected_progress_percent",
    "summary",
    "students"
  ],
  "title": "ClassroomDashboard"
}
```

<a id="schema-ClassroomDetail"></a>

## ClassroomDetail

| Campo | Obrigatório | Tipo | Default / limites |
| --- | --- | --- | --- |
| `program_id` | sim | string | minLength=1; maxLength=36 |
| `course_id` | sim | string | minLength=1; maxLength=120 |
| `teacher_id` | sim | string | minLength=1; maxLength=36 |
| `name` | sim | string | minLength=2; maxLength=240 |
| `offer_municipality` | não | string / null | maxLength=240 |
| `offer_location` | não | string / null | maxLength=500 |
| `start_date` | sim | string (date) | — |
| `end_date` | sim | string (date) | — |
| `status` | não | enum ["planned", "active", "closed"] | default="planned" |
| `id` | sim | string | — |
| `course_version_id` | não | string / null | — |
| `student_ids` | sim | array de string | — |
| `monitor_ids` | sim | array de string | — |

Schema exato:
```json
{
  "properties": {
    "program_id": {
      "type": "string",
      "maxLength": 36,
      "minLength": 1,
      "title": "Program Id"
    },
    "course_id": {
      "type": "string",
      "maxLength": 120,
      "minLength": 1,
      "title": "Course Id"
    },
    "teacher_id": {
      "type": "string",
      "maxLength": 36,
      "minLength": 1,
      "title": "Teacher Id"
    },
    "name": {
      "type": "string",
      "maxLength": 240,
      "minLength": 2,
      "title": "Name"
    },
    "offer_municipality": {
      "anyOf": [
        {
          "type": "string",
          "maxLength": 240
        },
        {
          "type": "null"
        }
      ],
      "title": "Offer Municipality"
    },
    "offer_location": {
      "anyOf": [
        {
          "type": "string",
          "maxLength": 500
        },
        {
          "type": "null"
        }
      ],
      "title": "Offer Location"
    },
    "start_date": {
      "type": "string",
      "format": "date",
      "title": "Start Date"
    },
    "end_date": {
      "type": "string",
      "format": "date",
      "title": "End Date"
    },
    "status": {
      "type": "string",
      "enum": [
        "planned",
        "active",
        "closed"
      ],
      "title": "Status",
      "default": "planned"
    },
    "id": {
      "type": "string",
      "title": "Id"
    },
    "course_version_id": {
      "anyOf": [
        {
          "type": "string"
        },
        {
          "type": "null"
        }
      ],
      "title": "Course Version Id"
    },
    "student_ids": {
      "items": {
        "type": "string"
      },
      "type": "array",
      "title": "Student Ids"
    },
    "monitor_ids": {
      "items": {
        "type": "string"
      },
      "type": "array",
      "title": "Monitor Ids"
    }
  },
  "additionalProperties": false,
  "type": "object",
  "required": [
    "program_id",
    "course_id",
    "teacher_id",
    "name",
    "start_date",
    "end_date",
    "id",
    "student_ids",
    "monitor_ids"
  ],
  "title": "ClassroomDetail"
}
```

<a id="schema-ClassroomPage"></a>

## ClassroomPage

| Campo | Obrigatório | Tipo | Default / limites |
| --- | --- | --- | --- |
| `classes` | sim | array de [ClassroomResponse](SCHEMAS.md#schema-ClassroomResponse) | — |

Schema exato:
```json
{
  "properties": {
    "classes": {
      "items": {
        "$ref": "#/components/schemas/ClassroomResponse"
      },
      "type": "array",
      "title": "Classes"
    }
  },
  "type": "object",
  "required": [
    "classes"
  ],
  "title": "ClassroomPage"
}
```

<a id="schema-ClassroomResponse"></a>

## ClassroomResponse

| Campo | Obrigatório | Tipo | Default / limites |
| --- | --- | --- | --- |
| `program_id` | sim | string | minLength=1; maxLength=36 |
| `course_id` | sim | string | minLength=1; maxLength=120 |
| `teacher_id` | sim | string | minLength=1; maxLength=36 |
| `name` | sim | string | minLength=2; maxLength=240 |
| `offer_municipality` | não | string / null | maxLength=240 |
| `offer_location` | não | string / null | maxLength=500 |
| `start_date` | sim | string (date) | — |
| `end_date` | sim | string (date) | — |
| `status` | não | enum ["planned", "active", "closed"] | default="planned" |
| `id` | sim | string | — |
| `course_version_id` | não | string / null | — |

Schema exato:
```json
{
  "properties": {
    "program_id": {
      "type": "string",
      "maxLength": 36,
      "minLength": 1,
      "title": "Program Id"
    },
    "course_id": {
      "type": "string",
      "maxLength": 120,
      "minLength": 1,
      "title": "Course Id"
    },
    "teacher_id": {
      "type": "string",
      "maxLength": 36,
      "minLength": 1,
      "title": "Teacher Id"
    },
    "name": {
      "type": "string",
      "maxLength": 240,
      "minLength": 2,
      "title": "Name"
    },
    "offer_municipality": {
      "anyOf": [
        {
          "type": "string",
          "maxLength": 240
        },
        {
          "type": "null"
        }
      ],
      "title": "Offer Municipality"
    },
    "offer_location": {
      "anyOf": [
        {
          "type": "string",
          "maxLength": 500
        },
        {
          "type": "null"
        }
      ],
      "title": "Offer Location"
    },
    "start_date": {
      "type": "string",
      "format": "date",
      "title": "Start Date"
    },
    "end_date": {
      "type": "string",
      "format": "date",
      "title": "End Date"
    },
    "status": {
      "type": "string",
      "enum": [
        "planned",
        "active",
        "closed"
      ],
      "title": "Status",
      "default": "planned"
    },
    "id": {
      "type": "string",
      "title": "Id"
    },
    "course_version_id": {
      "anyOf": [
        {
          "type": "string"
        },
        {
          "type": "null"
        }
      ],
      "title": "Course Version Id"
    }
  },
  "additionalProperties": false,
  "type": "object",
  "required": [
    "program_id",
    "course_id",
    "teacher_id",
    "name",
    "start_date",
    "end_date",
    "id"
  ],
  "title": "ClassroomResponse"
}
```

<a id="schema-CodeCheckinCreate"></a>

## CodeCheckinCreate

| Campo | Obrigatório | Tipo | Default / limites |
| --- | --- | --- | --- |
| `kind` | sim | enum ["checkin", "checkout"] | — |
| `idempotency_key` | sim | string | minLength=8; maxLength=180; pattern="^[A-Za-z0-9_.:-]+$" |
| `code` | sim | string | minLength=1; maxLength=16 |

Schema exato:
```json
{
  "properties": {
    "kind": {
      "type": "string",
      "enum": [
        "checkin",
        "checkout"
      ],
      "title": "Kind"
    },
    "idempotency_key": {
      "type": "string",
      "maxLength": 180,
      "minLength": 8,
      "pattern": "^[A-Za-z0-9_.:-]+$",
      "title": "Idempotency Key"
    },
    "code": {
      "type": "string",
      "maxLength": 16,
      "minLength": 1,
      "title": "Code"
    }
  },
  "additionalProperties": false,
  "type": "object",
  "required": [
    "kind",
    "idempotency_key",
    "code"
  ],
  "title": "CodeCheckinCreate"
}
```

<a id="schema-Command"></a>

## Command

| Campo | Obrigatório | Tipo | Default / limites |
| --- | --- | --- | --- |
| `id` | sim | string | minLength=16; maxLength=180 |
| `action` | sim | enum ["register", "enroll", "assign", "revoke"] | — |
| `reason` | sim | string | minLength=3; maxLength=500 |
| `institution_id` | sim | string | — |
| `program_id` | sim | string | — |
| `course_id` | sim | string | — |
| `version_id` | sim | string | — |
| `person_id` | não | string / null | maxLength=36 |
| `expected_revision` | não | integer / null | minimum=0.0 |
| `identity_proof` | não | string / null | maxLength=2000 |
| `registration` | não | [RegisterRequest](SCHEMAS.md#schema-RegisterRequest) / null | — |

Schema exato:
```json
{
  "properties": {
    "id": {
      "type": "string",
      "maxLength": 180,
      "minLength": 16,
      "title": "Id"
    },
    "action": {
      "type": "string",
      "enum": [
        "register",
        "enroll",
        "assign",
        "revoke"
      ],
      "title": "Action"
    },
    "reason": {
      "type": "string",
      "maxLength": 500,
      "minLength": 3,
      "title": "Reason"
    },
    "institution_id": {
      "type": "string",
      "title": "Institution Id"
    },
    "program_id": {
      "type": "string",
      "title": "Program Id"
    },
    "course_id": {
      "type": "string",
      "title": "Course Id"
    },
    "version_id": {
      "type": "string",
      "title": "Version Id"
    },
    "person_id": {
      "anyOf": [
        {
          "type": "string",
          "maxLength": 36
        },
        {
          "type": "null"
        }
      ],
      "title": "Person Id"
    },
    "expected_revision": {
      "anyOf": [
        {
          "type": "integer",
          "minimum": 0.0
        },
        {
          "type": "null"
        }
      ],
      "title": "Expected Revision"
    },
    "identity_proof": {
      "anyOf": [
        {
          "type": "string",
          "maxLength": 2000
        },
        {
          "type": "null"
        }
      ],
      "title": "Identity Proof"
    },
    "registration": {
      "anyOf": [
        {
          "$ref": "#/components/schemas/RegisterRequest"
        },
        {
          "type": "null"
        }
      ]
    }
  },
  "additionalProperties": false,
  "type": "object",
  "required": [
    "id",
    "action",
    "reason",
    "institution_id",
    "program_id",
    "course_id",
    "version_id"
  ],
  "title": "Command"
}
```

<a id="schema-CourseCreate"></a>

## CourseCreate

| Campo | Obrigatório | Tipo | Default / limites |
| --- | --- | --- | --- |
| `course_id` | sim | string | minLength=1; maxLength=120; pattern="^[a-zA-Z0-9][a-zA-Z0-9_-]*$" |
| `program_id` | sim | string | minLength=1; maxLength=36 |
| `title` | sim | string | minLength=1; maxLength=240 |
| `author` | sim | string | minLength=1; maxLength=240 |

Schema exato:
```json
{
  "properties": {
    "course_id": {
      "type": "string",
      "maxLength": 120,
      "minLength": 1,
      "pattern": "^[a-zA-Z0-9][a-zA-Z0-9_-]*$",
      "title": "Course Id"
    },
    "program_id": {
      "type": "string",
      "maxLength": 36,
      "minLength": 1,
      "title": "Program Id"
    },
    "title": {
      "type": "string",
      "maxLength": 240,
      "minLength": 1,
      "title": "Title"
    },
    "author": {
      "type": "string",
      "maxLength": 240,
      "minLength": 1,
      "title": "Author"
    }
  },
  "additionalProperties": false,
  "type": "object",
  "required": [
    "course_id",
    "program_id",
    "title",
    "author"
  ],
  "title": "CourseCreate"
}
```

<a id="schema-CreatorMediaAnalytics"></a>

## CreatorMediaAnalytics

| Campo | Obrigatório | Tipo | Default / limites |
| --- | --- | --- | --- |
| `media_id` | sim | string | — |
| `started` | sim | integer | — |
| `unique_participants` | sim | integer | — |
| `qualified_completions` | sim | integer | — |
| `followups` | sim | integer | — |
| `saves` | sim | integer | — |
| `ratings` | sim | integer | — |
| `average_rating` | sim | number / null | — |

Schema exato:
```json
{
  "properties": {
    "media_id": {
      "type": "string",
      "title": "Media Id"
    },
    "started": {
      "type": "integer",
      "title": "Started"
    },
    "unique_participants": {
      "type": "integer",
      "title": "Unique Participants"
    },
    "qualified_completions": {
      "type": "integer",
      "title": "Qualified Completions"
    },
    "followups": {
      "type": "integer",
      "title": "Followups"
    },
    "saves": {
      "type": "integer",
      "title": "Saves"
    },
    "ratings": {
      "type": "integer",
      "title": "Ratings"
    },
    "average_rating": {
      "anyOf": [
        {
          "type": "number"
        },
        {
          "type": "null"
        }
      ],
      "title": "Average Rating"
    }
  },
  "type": "object",
  "required": [
    "media_id",
    "started",
    "unique_participants",
    "qualified_completions",
    "followups",
    "saves",
    "ratings",
    "average_rating"
  ],
  "title": "CreatorMediaAnalytics"
}
```

<a id="schema-DashboardSummary"></a>

## DashboardSummary

| Campo | Obrigatório | Tipo | Default / limites |
| --- | --- | --- | --- |
| `total_students` | sim | integer | — |
| `inactive_students` | sim | integer | — |
| `pending_students` | sim | integer | — |
| `below_expected_students` | sim | integer | — |
| `baseline_linked_students` | não | integer | default=0 |
| `confirmed_participations` | não | integer | default=0 |
| `open_mentorship_cases` | não | integer | default=0 |

Schema exato:
```json
{
  "properties": {
    "total_students": {
      "type": "integer",
      "title": "Total Students"
    },
    "inactive_students": {
      "type": "integer",
      "title": "Inactive Students"
    },
    "pending_students": {
      "type": "integer",
      "title": "Pending Students"
    },
    "below_expected_students": {
      "type": "integer",
      "title": "Below Expected Students"
    },
    "baseline_linked_students": {
      "type": "integer",
      "title": "Baseline Linked Students",
      "default": 0
    },
    "confirmed_participations": {
      "type": "integer",
      "title": "Confirmed Participations",
      "default": 0
    },
    "open_mentorship_cases": {
      "type": "integer",
      "title": "Open Mentorship Cases",
      "default": 0
    }
  },
  "type": "object",
  "required": [
    "total_students",
    "inactive_students",
    "pending_students",
    "below_expected_students"
  ],
  "title": "DashboardSummary"
}
```

<a id="schema-DraftUpdate"></a>

## DraftUpdate

| Campo | Obrigatório | Tipo | Default / limites |
| --- | --- | --- | --- |
| `version_id` | sim | string | minLength=1; maxLength=36 |
| `expected_revision` | sim | integer | minimum=1.0 |
| `title` | sim | string | minLength=1; maxLength=240 |
| `author` | sim | string | minLength=1; maxLength=240 |
| `sections` | sim | array de object | maxItems=500 |
| `downloadUrl` | não | string / null | maxLength=2000 |
| `thumbnailUrl` | não | string / null | maxLength=2000 |

Schema exato:
```json
{
  "properties": {
    "version_id": {
      "type": "string",
      "maxLength": 36,
      "minLength": 1,
      "title": "Version Id"
    },
    "expected_revision": {
      "type": "integer",
      "minimum": 1.0,
      "title": "Expected Revision"
    },
    "title": {
      "type": "string",
      "maxLength": 240,
      "minLength": 1,
      "title": "Title"
    },
    "author": {
      "type": "string",
      "maxLength": 240,
      "minLength": 1,
      "title": "Author"
    },
    "sections": {
      "items": {
        "additionalProperties": true,
        "type": "object"
      },
      "type": "array",
      "maxItems": 500,
      "title": "Sections"
    },
    "downloadUrl": {
      "anyOf": [
        {
          "type": "string",
          "maxLength": 2000
        },
        {
          "type": "null"
        }
      ],
      "title": "Downloadurl"
    },
    "thumbnailUrl": {
      "anyOf": [
        {
          "type": "string",
          "maxLength": 2000
        },
        {
          "type": "null"
        }
      ],
      "title": "Thumbnailurl"
    }
  },
  "additionalProperties": false,
  "type": "object",
  "required": [
    "version_id",
    "expected_revision",
    "title",
    "author",
    "sections"
  ],
  "title": "DraftUpdate"
}
```

<a id="schema-EditorialTransitionRequest"></a>

## EditorialTransitionRequest

| Campo | Obrigatório | Tipo | Default / limites |
| --- | --- | --- | --- |
| `reason` | sim | string | minLength=3; maxLength=500 |

Schema exato:
```json
{
  "properties": {
    "reason": {
      "type": "string",
      "maxLength": 500,
      "minLength": 3,
      "title": "Reason"
    }
  },
  "additionalProperties": false,
  "type": "object",
  "required": [
    "reason"
  ],
  "title": "EditorialTransitionRequest"
}
```

<a id="schema-EditorialTransitionResponse"></a>

## EditorialTransitionResponse

| Campo | Obrigatório | Tipo | Default / limites |
| --- | --- | --- | --- |
| `id` | sim | string | — |
| `media_id` | sim | string | — |
| `from_status` | sim | enum ["draft", "processing", "published", "blocked", "archived"] / null | — |
| `to_status` | sim | enum ["draft", "processing", "published", "blocked", "archived"] | — |
| `actor_user_id` | sim | string | — |
| `actor_role` | sim | string | — |
| `reason` | sim | string / null | — |
| `occurred_at` | sim | string (date-time) | — |

Schema exato:
```json
{
  "properties": {
    "id": {
      "type": "string",
      "title": "Id"
    },
    "media_id": {
      "type": "string",
      "title": "Media Id"
    },
    "from_status": {
      "anyOf": [
        {
          "type": "string",
          "enum": [
            "draft",
            "processing",
            "published",
            "blocked",
            "archived"
          ]
        },
        {
          "type": "null"
        }
      ],
      "title": "From Status"
    },
    "to_status": {
      "type": "string",
      "enum": [
        "draft",
        "processing",
        "published",
        "blocked",
        "archived"
      ],
      "title": "To Status"
    },
    "actor_user_id": {
      "type": "string",
      "title": "Actor User Id"
    },
    "actor_role": {
      "type": "string",
      "title": "Actor Role"
    },
    "reason": {
      "anyOf": [
        {
          "type": "string"
        },
        {
          "type": "null"
        }
      ],
      "title": "Reason"
    },
    "occurred_at": {
      "type": "string",
      "format": "date-time",
      "title": "Occurred At"
    }
  },
  "type": "object",
  "required": [
    "id",
    "media_id",
    "from_status",
    "to_status",
    "actor_user_id",
    "actor_role",
    "reason",
    "occurred_at"
  ],
  "title": "EditorialTransitionResponse"
}
```

<a id="schema-EligibleStudent"></a>

## EligibleStudent

| Campo | Obrigatório | Tipo | Default / limites |
| --- | --- | --- | --- |
| `user_id` | sim | string | — |
| `name` | sim | string | — |

Schema exato:
```json
{
  "properties": {
    "user_id": {
      "type": "string",
      "title": "User Id"
    },
    "name": {
      "type": "string",
      "title": "Name"
    }
  },
  "type": "object",
  "required": [
    "user_id",
    "name"
  ],
  "title": "EligibleStudent"
}
```

<a id="schema-EligibleStudentPage"></a>

## EligibleStudentPage

| Campo | Obrigatório | Tipo | Default / limites |
| --- | --- | --- | --- |
| `students` | sim | array de [EligibleStudent](SCHEMAS.md#schema-EligibleStudent) | — |
| `next_offset` | sim | integer / null | — |
| `occupancy` | não | integer | default=0 |
| `capacity_reference` | não | integer | default=30 |
| `capacity_warning` | não | boolean | default=false |

Schema exato:
```json
{
  "properties": {
    "students": {
      "items": {
        "$ref": "#/components/schemas/EligibleStudent"
      },
      "type": "array",
      "title": "Students"
    },
    "next_offset": {
      "anyOf": [
        {
          "type": "integer"
        },
        {
          "type": "null"
        }
      ],
      "title": "Next Offset"
    },
    "occupancy": {
      "type": "integer",
      "title": "Occupancy",
      "default": 0
    },
    "capacity_reference": {
      "type": "integer",
      "title": "Capacity Reference",
      "default": 30
    },
    "capacity_warning": {
      "type": "boolean",
      "title": "Capacity Warning",
      "default": false
    }
  },
  "type": "object",
  "required": [
    "students",
    "next_offset"
  ],
  "title": "EligibleStudentPage"
}
```

<a id="schema-EnrollmentCreate"></a>

## EnrollmentCreate

| Campo | Obrigatório | Tipo | Default / limites |
| --- | --- | --- | --- |
| `user_id` | sim | string | minLength=1; maxLength=36 |
| `program_id` | sim | string | minLength=1; maxLength=36 |
| `course_id` | sim | string | minLength=1; maxLength=120 |

Schema exato:
```json
{
  "properties": {
    "user_id": {
      "type": "string",
      "maxLength": 36,
      "minLength": 1,
      "title": "User Id"
    },
    "program_id": {
      "type": "string",
      "maxLength": 36,
      "minLength": 1,
      "title": "Program Id"
    },
    "course_id": {
      "type": "string",
      "maxLength": 120,
      "minLength": 1,
      "title": "Course Id"
    }
  },
  "additionalProperties": false,
  "type": "object",
  "required": [
    "user_id",
    "program_id",
    "course_id"
  ],
  "title": "EnrollmentCreate"
}
```

<a id="schema-EnrollmentResponse"></a>

## EnrollmentResponse

| Campo | Obrigatório | Tipo | Default / limites |
| --- | --- | --- | --- |
| `user_id` | sim | string | minLength=1; maxLength=36 |
| `program_id` | sim | string | minLength=1; maxLength=36 |
| `course_id` | sim | string | minLength=1; maxLength=120 |
| `id` | sim | string | — |
| `status` | sim | string | — |

Schema exato:
```json
{
  "properties": {
    "user_id": {
      "type": "string",
      "maxLength": 36,
      "minLength": 1,
      "title": "User Id"
    },
    "program_id": {
      "type": "string",
      "maxLength": 36,
      "minLength": 1,
      "title": "Program Id"
    },
    "course_id": {
      "type": "string",
      "maxLength": 120,
      "minLength": 1,
      "title": "Course Id"
    },
    "id": {
      "type": "string",
      "title": "Id"
    },
    "status": {
      "type": "string",
      "title": "Status"
    }
  },
  "additionalProperties": false,
  "type": "object",
  "required": [
    "user_id",
    "program_id",
    "course_id",
    "id",
    "status"
  ],
  "title": "EnrollmentResponse"
}
```

<a id="schema-EventCreate"></a>

## EventCreate

| Campo | Obrigatório | Tipo | Default / limites |
| --- | --- | --- | --- |
| `event_id` | sim | string | minLength=1; maxLength=180 |
| `event_type` | sim | enum ["lesson_started", "lesson_completed", "study_activity", "page_viewed", "resource_opened", "feature_used", "screen_engagement", "video_started", "video_checkpoint", "video_completed", "video_followup_completed", "video_saved"] | — |
| `course_id` | sim | string | minLength=1; maxLength=120 |
| `session_id` | sim | string | minLength=1; maxLength=160 |
| `occurred_at` | sim | string (date-time) | — |
| `active_seconds` | não | integer / null | minimum=1.0; maximum=60.0 |
| `payload` | não | object | additionalProperties={"type": "string"} |

Schema exato:
```json
{
  "properties": {
    "event_id": {
      "type": "string",
      "maxLength": 180,
      "minLength": 1,
      "title": "Event Id"
    },
    "event_type": {
      "type": "string",
      "enum": [
        "lesson_started",
        "lesson_completed",
        "study_activity",
        "page_viewed",
        "resource_opened",
        "feature_used",
        "screen_engagement",
        "video_started",
        "video_checkpoint",
        "video_completed",
        "video_followup_completed",
        "video_saved"
      ],
      "title": "Event Type"
    },
    "course_id": {
      "type": "string",
      "maxLength": 120,
      "minLength": 1,
      "title": "Course Id"
    },
    "session_id": {
      "type": "string",
      "maxLength": 160,
      "minLength": 1,
      "title": "Session Id"
    },
    "occurred_at": {
      "type": "string",
      "format": "date-time",
      "title": "Occurred At"
    },
    "active_seconds": {
      "anyOf": [
        {
          "type": "integer",
          "maximum": 60.0,
          "minimum": 1.0
        },
        {
          "type": "null"
        }
      ],
      "title": "Active Seconds"
    },
    "payload": {
      "additionalProperties": {
        "type": "string"
      },
      "type": "object",
      "title": "Payload"
    }
  },
  "additionalProperties": false,
  "type": "object",
  "required": [
    "event_id",
    "event_type",
    "course_id",
    "session_id",
    "occurred_at"
  ],
  "title": "EventCreate"
}
```

<a id="schema-EventPage"></a>

## EventPage

| Campo | Obrigatório | Tipo | Default / limites |
| --- | --- | --- | --- |
| `events` | sim | array de [EventResponse](SCHEMAS.md#schema-EventResponse) | — |
| `offset` | sim | integer | — |
| `limit` | sim | integer | — |

Schema exato:
```json
{
  "properties": {
    "events": {
      "items": {
        "$ref": "#/components/schemas/EventResponse"
      },
      "type": "array",
      "title": "Events"
    },
    "offset": {
      "type": "integer",
      "title": "Offset"
    },
    "limit": {
      "type": "integer",
      "title": "Limit"
    }
  },
  "type": "object",
  "required": [
    "events",
    "offset",
    "limit"
  ],
  "title": "EventPage"
}
```

<a id="schema-EventResponse"></a>

## EventResponse

| Campo | Obrigatório | Tipo | Default / limites |
| --- | --- | --- | --- |
| `event_id` | sim | string | — |
| `event_type` | sim | enum ["lesson_started", "lesson_completed", "study_activity", "page_viewed", "resource_opened", "feature_used", "screen_engagement", "video_started", "video_checkpoint", "video_completed", "video_followup_completed", "video_saved"] / const "assessment_completed" | — |
| `course_id` | sim | string | — |
| `session_id` | sim | string | — |
| `occurred_at` | sim | string (date-time) | — |
| `active_seconds` | sim | integer / null | — |
| `payload` | sim | object | additionalProperties=true |
| `sync_status` | sim | string | — |
| `validated_seconds` | sim | integer | — |

Schema exato:
```json
{
  "properties": {
    "event_id": {
      "type": "string",
      "title": "Event Id"
    },
    "event_type": {
      "anyOf": [
        {
          "type": "string",
          "enum": [
            "lesson_started",
            "lesson_completed",
            "study_activity",
            "page_viewed",
            "resource_opened",
            "feature_used",
            "screen_engagement",
            "video_started",
            "video_checkpoint",
            "video_completed",
            "video_followup_completed",
            "video_saved"
          ]
        },
        {
          "type": "string",
          "const": "assessment_completed"
        }
      ],
      "title": "Event Type"
    },
    "course_id": {
      "type": "string",
      "title": "Course Id"
    },
    "session_id": {
      "type": "string",
      "title": "Session Id"
    },
    "occurred_at": {
      "type": "string",
      "format": "date-time",
      "title": "Occurred At"
    },
    "active_seconds": {
      "anyOf": [
        {
          "type": "integer"
        },
        {
          "type": "null"
        }
      ],
      "title": "Active Seconds"
    },
    "payload": {
      "additionalProperties": true,
      "type": "object",
      "title": "Payload"
    },
    "sync_status": {
      "type": "string",
      "title": "Sync Status"
    },
    "validated_seconds": {
      "type": "integer",
      "title": "Validated Seconds"
    }
  },
  "type": "object",
  "required": [
    "event_id",
    "event_type",
    "course_id",
    "session_id",
    "occurred_at",
    "active_seconds",
    "payload",
    "sync_status",
    "validated_seconds"
  ],
  "title": "EventResponse"
}
```

<a id="schema-EvidenceCreate"></a>

## EvidenceCreate

| Campo | Obrigatório | Tipo | Default / limites |
| --- | --- | --- | --- |
| `kind` | sim | enum ["baseline", "attendance_sheet", "attendance_exception"] | — |
| `origin` | sim | string | minLength=1; maxLength=100; pattern="^[A-Za-z0-9_.:-]+$" |
| `document_reference` | sim | string | minLength=3; maxLength=240 |
| `document_digest` | sim | string | pattern="^[0-9a-f]{64}$" |
| `reason` | sim | string | minLength=3; maxLength=500 |
| `session_ids` | não | array de string | maxItems=100 |

Schema exato:
```json
{
  "properties": {
    "kind": {
      "type": "string",
      "enum": [
        "baseline",
        "attendance_sheet",
        "attendance_exception"
      ],
      "title": "Kind"
    },
    "origin": {
      "type": "string",
      "maxLength": 100,
      "minLength": 1,
      "pattern": "^[A-Za-z0-9_.:-]+$",
      "title": "Origin"
    },
    "document_reference": {
      "type": "string",
      "maxLength": 240,
      "minLength": 3,
      "title": "Document Reference"
    },
    "document_digest": {
      "type": "string",
      "pattern": "^[0-9a-f]{64}$",
      "title": "Document Digest"
    },
    "reason": {
      "type": "string",
      "maxLength": 500,
      "minLength": 3,
      "title": "Reason"
    },
    "session_ids": {
      "items": {
        "type": "string"
      },
      "type": "array",
      "maxItems": 100,
      "title": "Session Ids"
    }
  },
  "additionalProperties": false,
  "type": "object",
  "required": [
    "kind",
    "origin",
    "document_reference",
    "document_digest",
    "reason"
  ],
  "title": "EvidenceCreate"
}
```

<a id="schema-EvidenceItemCreate"></a>

## EvidenceItemCreate

| Campo | Obrigatório | Tipo | Default / limites |
| --- | --- | --- | --- |
| `item_digest` | sim | string | pattern="^[0-9a-f]{64,128}$" |
| `evidence_type` | sim | enum ["observation", "activity", "certificate", "message_metadata", "document_metadata"] | — |
| `occurred_at` | sim | string (date-time) | — |
| `user_id` | não | string / null | maxLength=36 |
| `session_id` | não | string / null | maxLength=36 |
| `object_reference` | não | string / null | maxLength=500 |
| `metadata` | não | object | additionalProperties={"type": "string"} |

Schema exato:
```json
{
  "properties": {
    "item_digest": {
      "type": "string",
      "pattern": "^[0-9a-f]{64,128}$",
      "title": "Item Digest"
    },
    "evidence_type": {
      "type": "string",
      "enum": [
        "observation",
        "activity",
        "certificate",
        "message_metadata",
        "document_metadata"
      ],
      "title": "Evidence Type"
    },
    "occurred_at": {
      "type": "string",
      "format": "date-time",
      "title": "Occurred At"
    },
    "user_id": {
      "anyOf": [
        {
          "type": "string",
          "maxLength": 36
        },
        {
          "type": "null"
        }
      ],
      "title": "User Id"
    },
    "session_id": {
      "anyOf": [
        {
          "type": "string",
          "maxLength": 36
        },
        {
          "type": "null"
        }
      ],
      "title": "Session Id"
    },
    "object_reference": {
      "anyOf": [
        {
          "type": "string",
          "maxLength": 500
        },
        {
          "type": "null"
        }
      ],
      "title": "Object Reference"
    },
    "metadata": {
      "additionalProperties": {
        "type": "string"
      },
      "type": "object",
      "title": "Metadata"
    }
  },
  "additionalProperties": false,
  "type": "object",
  "required": [
    "item_digest",
    "evidence_type",
    "occurred_at"
  ],
  "title": "EvidenceItemCreate"
}
```

<a id="schema-HTTPValidationError"></a>

## HTTPValidationError

| Campo | Obrigatório | Tipo | Default / limites |
| --- | --- | --- | --- |
| `detail` | não | array de [ValidationError](SCHEMAS.md#schema-ValidationError) | — |

Schema exato:
```json
{
  "properties": {
    "detail": {
      "items": {
        "$ref": "#/components/schemas/ValidationError"
      },
      "type": "array",
      "title": "Detail"
    }
  },
  "type": "object",
  "title": "HTTPValidationError"
}
```

<a id="schema-HoursResponse"></a>

## HoursResponse

| Campo | Obrigatório | Tipo | Default / limites |
| --- | --- | --- | --- |
| `user_id` | sim | string | — |
| `program_id` | sim | string | — |
| `course_id` | sim | string | — |
| `planned_hours` | sim | number | — |
| `validated_hours` | sim | number | — |
| `active_usage` | sim | number | — |

Schema exato:
```json
{
  "properties": {
    "user_id": {
      "type": "string",
      "title": "User Id"
    },
    "program_id": {
      "type": "string",
      "title": "Program Id"
    },
    "course_id": {
      "type": "string",
      "title": "Course Id"
    },
    "planned_hours": {
      "type": "number",
      "title": "Planned Hours"
    },
    "validated_hours": {
      "type": "number",
      "title": "Validated Hours"
    },
    "active_usage": {
      "type": "number",
      "title": "Active Usage"
    }
  },
  "type": "object",
  "required": [
    "user_id",
    "program_id",
    "course_id",
    "planned_hours",
    "validated_hours",
    "active_usage"
  ],
  "title": "HoursResponse"
}
```

<a id="schema-ImportCreate"></a>

## ImportCreate

| Campo | Obrigatório | Tipo | Default / limites |
| --- | --- | --- | --- |
| `source_type` | sim | enum ["whatsapp_export", "drive_metadata", "sharesheet", "manual_metadata"] | — |
| `source_digest` | sim | string | pattern="^[0-9a-f]{64,128}$" |
| `idempotency_key` | sim | string | minLength=8; maxLength=180; pattern="^[A-Za-z0-9_.:-]+$" |
| `retention_until` | sim | string (date-time) | — |
| `items` | sim | array de [EvidenceItemCreate](SCHEMAS.md#schema-EvidenceItemCreate) | minItems=1; maxItems=200 |

Schema exato:
```json
{
  "properties": {
    "source_type": {
      "type": "string",
      "enum": [
        "whatsapp_export",
        "drive_metadata",
        "sharesheet",
        "manual_metadata"
      ],
      "title": "Source Type"
    },
    "source_digest": {
      "type": "string",
      "pattern": "^[0-9a-f]{64,128}$",
      "title": "Source Digest"
    },
    "idempotency_key": {
      "type": "string",
      "maxLength": 180,
      "minLength": 8,
      "pattern": "^[A-Za-z0-9_.:-]+$",
      "title": "Idempotency Key"
    },
    "retention_until": {
      "type": "string",
      "format": "date-time",
      "title": "Retention Until"
    },
    "items": {
      "items": {
        "$ref": "#/components/schemas/EvidenceItemCreate"
      },
      "type": "array",
      "maxItems": 200,
      "minItems": 1,
      "title": "Items"
    }
  },
  "additionalProperties": false,
  "type": "object",
  "required": [
    "source_type",
    "source_digest",
    "idempotency_key",
    "retention_until",
    "items"
  ],
  "title": "ImportCreate"
}
```

<a id="schema-ImportResponse"></a>

## ImportResponse

| Campo | Obrigatório | Tipo | Default / limites |
| --- | --- | --- | --- |
| `id` | sim | string | — |
| `class_id` | sim | string | — |
| `source_type` | sim | string | — |
| `status` | sim | string | — |
| `retention_until` | sim | string (date-time) | — |
| `source_digest` | sim | string | — |
| `evidence_ids` | sim | array de string | — |

Schema exato:
```json
{
  "properties": {
    "id": {
      "type": "string",
      "title": "Id"
    },
    "class_id": {
      "type": "string",
      "title": "Class Id"
    },
    "source_type": {
      "type": "string",
      "title": "Source Type"
    },
    "status": {
      "type": "string",
      "title": "Status"
    },
    "retention_until": {
      "type": "string",
      "format": "date-time",
      "title": "Retention Until"
    },
    "source_digest": {
      "type": "string",
      "title": "Source Digest"
    },
    "evidence_ids": {
      "items": {
        "type": "string"
      },
      "type": "array",
      "title": "Evidence Ids"
    }
  },
  "type": "object",
  "required": [
    "id",
    "class_id",
    "source_type",
    "status",
    "retention_until",
    "source_digest",
    "evidence_ids"
  ],
  "title": "ImportResponse"
}
```

<a id="schema-InstitutionCreate"></a>

## InstitutionCreate

| Campo | Obrigatório | Tipo | Default / limites |
| --- | --- | --- | --- |
| `name` | sim | string | minLength=2; maxLength=240 |

Schema exato:
```json
{
  "properties": {
    "name": {
      "type": "string",
      "maxLength": 240,
      "minLength": 2,
      "title": "Name"
    }
  },
  "additionalProperties": false,
  "type": "object",
  "required": [
    "name"
  ],
  "title": "InstitutionCreate"
}
```

<a id="schema-InstitutionHierarchy"></a>

## InstitutionHierarchy

| Campo | Obrigatório | Tipo | Default / limites |
| --- | --- | --- | --- |
| `name` | sim | string | minLength=2; maxLength=240 |
| `id` | sim | string | — |
| `programs` | sim | array de [ProgramHierarchy](SCHEMAS.md#schema-ProgramHierarchy) | — |

Schema exato:
```json
{
  "properties": {
    "name": {
      "type": "string",
      "maxLength": 240,
      "minLength": 2,
      "title": "Name"
    },
    "id": {
      "type": "string",
      "title": "Id"
    },
    "programs": {
      "items": {
        "$ref": "#/components/schemas/ProgramHierarchy"
      },
      "type": "array",
      "title": "Programs"
    }
  },
  "additionalProperties": false,
  "type": "object",
  "required": [
    "name",
    "id",
    "programs"
  ],
  "title": "InstitutionHierarchy"
}
```

<a id="schema-InstitutionResponse"></a>

## InstitutionResponse

| Campo | Obrigatório | Tipo | Default / limites |
| --- | --- | --- | --- |
| `name` | sim | string | minLength=2; maxLength=240 |
| `id` | sim | string | — |

Schema exato:
```json
{
  "properties": {
    "name": {
      "type": "string",
      "maxLength": 240,
      "minLength": 2,
      "title": "Name"
    },
    "id": {
      "type": "string",
      "title": "Id"
    }
  },
  "additionalProperties": false,
  "type": "object",
  "required": [
    "name",
    "id"
  ],
  "title": "InstitutionResponse"
}
```

<a id="schema-LearningContext"></a>

## LearningContext

| Campo | Obrigatório | Tipo | Default / limites |
| --- | --- | --- | --- |
| `user_id` | sim | string | — |
| `organization_id` | sim | string | — |
| `program_id` | sim | string | — |
| `cohort_id` | sim | string | — |
| `membership_id` | sim | string | — |
| `role` | sim | const "student" | — |
| `course_id` | sim | string | — |
| `course_version_id` | sim | string | — |
| `enrollment_id` | sim | string | — |
| `legacy_enrollment_id` | sim | string | — |
| `permissions` | sim | array de string | — |

Schema exato:
```json
{
  "properties": {
    "user_id": {
      "type": "string",
      "title": "User Id"
    },
    "organization_id": {
      "type": "string",
      "title": "Organization Id"
    },
    "program_id": {
      "type": "string",
      "title": "Program Id"
    },
    "cohort_id": {
      "type": "string",
      "title": "Cohort Id"
    },
    "membership_id": {
      "type": "string",
      "title": "Membership Id"
    },
    "role": {
      "type": "string",
      "const": "student",
      "title": "Role"
    },
    "course_id": {
      "type": "string",
      "title": "Course Id"
    },
    "course_version_id": {
      "type": "string",
      "title": "Course Version Id"
    },
    "enrollment_id": {
      "type": "string",
      "title": "Enrollment Id"
    },
    "legacy_enrollment_id": {
      "type": "string",
      "title": "Legacy Enrollment Id"
    },
    "permissions": {
      "items": {
        "type": "string"
      },
      "type": "array",
      "title": "Permissions"
    }
  },
  "additionalProperties": false,
  "type": "object",
  "required": [
    "user_id",
    "organization_id",
    "program_id",
    "cohort_id",
    "membership_id",
    "role",
    "course_id",
    "course_version_id",
    "enrollment_id",
    "legacy_enrollment_id",
    "permissions"
  ],
  "title": "LearningContext"
}
```

<a id="schema-LearningContextSnapshot"></a>

## LearningContextSnapshot

| Campo | Obrigatório | Tipo | Default / limites |
| --- | --- | --- | --- |
| `context` | sim | [LearningContext](SCHEMAS.md#schema-LearningContext) | — |
| `progress` | sim | [StudentProgress](SCHEMAS.md#schema-StudentProgress) | — |
| `resolved_at` | sim | string (date-time) | — |
| `contract_version` | não | const "cohort-enrollment-v2" | default="cohort-enrollment-v2" |

Schema exato:
```json
{
  "properties": {
    "context": {
      "$ref": "#/components/schemas/LearningContext"
    },
    "progress": {
      "$ref": "#/components/schemas/StudentProgress"
    },
    "resolved_at": {
      "type": "string",
      "format": "date-time",
      "title": "Resolved At"
    },
    "contract_version": {
      "type": "string",
      "const": "cohort-enrollment-v2",
      "title": "Contract Version",
      "default": "cohort-enrollment-v2"
    }
  },
  "type": "object",
  "required": [
    "context",
    "progress",
    "resolved_at"
  ],
  "title": "LearningContextSnapshot"
}
```

<a id="schema-LedgerCreate"></a>

## LedgerCreate

| Campo | Obrigatório | Tipo | Default / limites |
| --- | --- | --- | --- |
| `creator_score_id` | sim | string | minLength=1; maxLength=36 |
| `entry_type` | sim | enum ["accrual", "reversal", "adjustment"] | — |
| `amount_minor` | sim | integer | minimum=-100000000.0; maximum=100000000.0 |
| `currency` | não | const "BRL" | default="BRL" |
| `idempotency_key` | sim | string | minLength=8; maxLength=180; pattern="^[A-Za-z0-9_.:-]+$" |
| `source_event_id` | sim | string | minLength=1; maxLength=180 |

Schema exato:
```json
{
  "properties": {
    "creator_score_id": {
      "type": "string",
      "maxLength": 36,
      "minLength": 1,
      "title": "Creator Score Id"
    },
    "entry_type": {
      "type": "string",
      "enum": [
        "accrual",
        "reversal",
        "adjustment"
      ],
      "title": "Entry Type"
    },
    "amount_minor": {
      "type": "integer",
      "maximum": 100000000.0,
      "minimum": -100000000.0,
      "title": "Amount Minor"
    },
    "currency": {
      "type": "string",
      "const": "BRL",
      "title": "Currency",
      "default": "BRL"
    },
    "idempotency_key": {
      "type": "string",
      "maxLength": 180,
      "minLength": 8,
      "pattern": "^[A-Za-z0-9_.:-]+$",
      "title": "Idempotency Key"
    },
    "source_event_id": {
      "type": "string",
      "maxLength": 180,
      "minLength": 1,
      "title": "Source Event Id"
    }
  },
  "additionalProperties": false,
  "type": "object",
  "required": [
    "creator_score_id",
    "entry_type",
    "amount_minor",
    "idempotency_key",
    "source_event_id"
  ],
  "title": "LedgerCreate"
}
```

<a id="schema-LedgerResponse"></a>

## LedgerResponse

| Campo | Obrigatório | Tipo | Default / limites |
| --- | --- | --- | --- |
| `id` | sim | string | — |
| `institution_id` | sim | string | — |
| `program_id` | sim | string | — |
| `creator_user_id` | sim | string | — |
| `media_id` | sim | string | — |
| `source_event_id` | sim | string | — |
| `rule_version` | sim | string | — |
| `entry_type` | sim | string | — |
| `amount_minor` | sim | integer | — |
| `currency` | sim | string | — |
| `status` | sim | const "simulated" | — |
| `idempotency_key` | sim | string | — |
| `calculation_snapshot` | sim | object | additionalProperties=true |
| `created_at` | sim | string (date-time) | — |

Schema exato:
```json
{
  "properties": {
    "id": {
      "type": "string",
      "title": "Id"
    },
    "institution_id": {
      "type": "string",
      "title": "Institution Id"
    },
    "program_id": {
      "type": "string",
      "title": "Program Id"
    },
    "creator_user_id": {
      "type": "string",
      "title": "Creator User Id"
    },
    "media_id": {
      "type": "string",
      "title": "Media Id"
    },
    "source_event_id": {
      "type": "string",
      "title": "Source Event Id"
    },
    "rule_version": {
      "type": "string",
      "title": "Rule Version"
    },
    "entry_type": {
      "type": "string",
      "title": "Entry Type"
    },
    "amount_minor": {
      "type": "integer",
      "title": "Amount Minor"
    },
    "currency": {
      "type": "string",
      "title": "Currency"
    },
    "status": {
      "type": "string",
      "const": "simulated",
      "title": "Status"
    },
    "idempotency_key": {
      "type": "string",
      "title": "Idempotency Key"
    },
    "calculation_snapshot": {
      "additionalProperties": true,
      "type": "object",
      "title": "Calculation Snapshot"
    },
    "created_at": {
      "type": "string",
      "format": "date-time",
      "title": "Created At"
    }
  },
  "type": "object",
  "required": [
    "id",
    "institution_id",
    "program_id",
    "creator_user_id",
    "media_id",
    "source_event_id",
    "rule_version",
    "entry_type",
    "amount_minor",
    "currency",
    "status",
    "idempotency_key",
    "calculation_snapshot",
    "created_at"
  ],
  "title": "LedgerResponse"
}
```

<a id="schema-LifecycleAction"></a>

## LifecycleAction

| Campo | Obrigatório | Tipo | Default / limites |
| --- | --- | --- | --- |
| `action` | sim | enum ["submit", "instructor_validate", "coordinator_sign"] | — |
| `expected_state` | sim | enum ["GENERATED", "PENDING_INSTRUCTOR_VALIDATION", "PENDING_COORDINATOR_SIGNATURE", "VALID"] | — |
| `document_reference` | não | string / null | minLength=3; maxLength=240 |
| `document_digest` | não | string / null | pattern="^[0-9a-f]{64}$" |

Schema exato:
```json
{
  "properties": {
    "action": {
      "type": "string",
      "enum": [
        "submit",
        "instructor_validate",
        "coordinator_sign"
      ],
      "title": "Action"
    },
    "expected_state": {
      "type": "string",
      "enum": [
        "GENERATED",
        "PENDING_INSTRUCTOR_VALIDATION",
        "PENDING_COORDINATOR_SIGNATURE",
        "VALID"
      ],
      "title": "Expected State"
    },
    "document_reference": {
      "anyOf": [
        {
          "type": "string",
          "maxLength": 240,
          "minLength": 3
        },
        {
          "type": "null"
        }
      ],
      "title": "Document Reference"
    },
    "document_digest": {
      "anyOf": [
        {
          "type": "string",
          "pattern": "^[0-9a-f]{64}$"
        },
        {
          "type": "null"
        }
      ],
      "title": "Document Digest"
    }
  },
  "additionalProperties": false,
  "type": "object",
  "required": [
    "action",
    "expected_state"
  ],
  "title": "LifecycleAction"
}
```

<a id="schema-LoginRequest"></a>

## LoginRequest

| Campo | Obrigatório | Tipo | Default / limites |
| --- | --- | --- | --- |
| `cpf` | sim | string (password) | writeOnly=true |
| `password` | sim | string (password) | writeOnly=true |

Schema exato:
```json
{
  "properties": {
    "cpf": {
      "type": "string",
      "format": "password",
      "title": "Cpf",
      "writeOnly": true
    },
    "password": {
      "type": "string",
      "format": "password",
      "title": "Password",
      "writeOnly": true
    }
  },
  "type": "object",
  "required": [
    "cpf",
    "password"
  ],
  "title": "LoginRequest"
}
```

<a id="schema-ManagedAccountCreate"></a>

## ManagedAccountCreate

| Campo | Obrigatório | Tipo | Default / limites |
| --- | --- | --- | --- |
| `name` | sim | string | minLength=2; maxLength=240 |
| `cpf` | sim | string (password) | writeOnly=true |
| `phone` | sim | string | minLength=10; maxLength=32 |
| `password` | sim | string (password) | writeOnly=true |
| `role` | sim | enum ["student", "teacher", "monitor", "creator", "coordinator", "program_operator", "finance", "admin"] | — |
| `program_id` | sim | string | minLength=1; maxLength=36 |

Schema exato:
```json
{
  "properties": {
    "name": {
      "type": "string",
      "maxLength": 240,
      "minLength": 2,
      "title": "Name"
    },
    "cpf": {
      "type": "string",
      "format": "password",
      "title": "Cpf",
      "writeOnly": true
    },
    "phone": {
      "type": "string",
      "maxLength": 32,
      "minLength": 10,
      "title": "Phone"
    },
    "password": {
      "type": "string",
      "format": "password",
      "title": "Password",
      "writeOnly": true
    },
    "role": {
      "type": "string",
      "enum": [
        "student",
        "teacher",
        "monitor",
        "creator",
        "coordinator",
        "program_operator",
        "finance",
        "admin"
      ],
      "title": "Role"
    },
    "program_id": {
      "type": "string",
      "maxLength": 36,
      "minLength": 1,
      "title": "Program Id"
    }
  },
  "additionalProperties": false,
  "type": "object",
  "required": [
    "name",
    "cpf",
    "phone",
    "password",
    "role",
    "program_id"
  ],
  "title": "ManagedAccountCreate",
  "description": "Admin-only account creation with its program membership in one transaction."
}
```

<a id="schema-ManagedAccountResponse"></a>

## ManagedAccountResponse

| Campo | Obrigatório | Tipo | Default / limites |
| --- | --- | --- | --- |
| `id` | sim | string | — |
| `name` | sim | string | — |
| `role` | sim | enum ["student", "teacher", "monitor", "creator", "coordinator", "program_operator", "finance", "admin"] | — |
| `program_id` | sim | string | — |
| `membership_status` | sim | string | — |

Schema exato:
```json
{
  "properties": {
    "id": {
      "type": "string",
      "title": "Id"
    },
    "name": {
      "type": "string",
      "title": "Name"
    },
    "role": {
      "type": "string",
      "enum": [
        "student",
        "teacher",
        "monitor",
        "creator",
        "coordinator",
        "program_operator",
        "finance",
        "admin"
      ],
      "title": "Role"
    },
    "program_id": {
      "type": "string",
      "title": "Program Id"
    },
    "membership_status": {
      "type": "string",
      "title": "Membership Status"
    }
  },
  "type": "object",
  "required": [
    "id",
    "name",
    "role",
    "program_id",
    "membership_status"
  ],
  "title": "ManagedAccountResponse"
}
```

<a id="schema-MediaCreate"></a>

## MediaCreate

| Campo | Obrigatório | Tipo | Default / limites |
| --- | --- | --- | --- |
| `institution_id` | sim | string | minLength=1; maxLength=36 |
| `program_id` | sim | string | minLength=1; maxLength=36 |
| `course_id` | sim | string | minLength=1; maxLength=120 |
| `module_id` | sim | string | pattern="^[a-z0-9][a-z0-9_.-]{0,79}$" |
| `creator_user_id` | não | string / null | maxLength=36 |
| `title` | sim | string | minLength=2; maxLength=240 |
| `description` | não | string | default=""; maxLength=4000 |
| `competency_id` | sim | string | pattern="^[a-z0-9][a-z0-9_.-]{0,79}$" |
| `provider` | sim | enum ["youtube", "cloudflare_stream", "external_hls"] | — |
| `provider_asset_id` | sim | string | minLength=1; maxLength=500 |
| `duration_seconds` | sim | integer | maximum=86400.0; exclusiveMinimum=0.0 |
| `thumbnail_url` | não | string / null | maxLength=500 |
| `captions` | não | array de [Caption](SCHEMAS.md#schema-Caption) | maxItems=20 |
| `visibility` | não | enum ["public", "unlisted", "enrolled", "institution"] | default="enrolled" |
| `offline_policy` | não | enum ["forbidden", "allowed"] | default="forbidden" |
| `master_drive_file_id` | não | string / null | maxLength=240 |
| `rights_confirmed` | não | boolean | default=false |
| `followup_activity_id` | sim | string | pattern="^[a-z0-9][a-z0-9_.-]{0,79}$" |

Schema exato:
```json
{
  "properties": {
    "institution_id": {
      "type": "string",
      "maxLength": 36,
      "minLength": 1,
      "title": "Institution Id"
    },
    "program_id": {
      "type": "string",
      "maxLength": 36,
      "minLength": 1,
      "title": "Program Id"
    },
    "course_id": {
      "type": "string",
      "maxLength": 120,
      "minLength": 1,
      "title": "Course Id"
    },
    "module_id": {
      "type": "string",
      "pattern": "^[a-z0-9][a-z0-9_.-]{0,79}$",
      "title": "Module Id"
    },
    "creator_user_id": {
      "anyOf": [
        {
          "type": "string",
          "maxLength": 36
        },
        {
          "type": "null"
        }
      ],
      "title": "Creator User Id"
    },
    "title": {
      "type": "string",
      "maxLength": 240,
      "minLength": 2,
      "title": "Title"
    },
    "description": {
      "type": "string",
      "maxLength": 4000,
      "title": "Description",
      "default": ""
    },
    "competency_id": {
      "type": "string",
      "pattern": "^[a-z0-9][a-z0-9_.-]{0,79}$",
      "title": "Competency Id"
    },
    "provider": {
      "type": "string",
      "enum": [
        "youtube",
        "cloudflare_stream",
        "external_hls"
      ],
      "title": "Provider"
    },
    "provider_asset_id": {
      "type": "string",
      "maxLength": 500,
      "minLength": 1,
      "title": "Provider Asset Id"
    },
    "duration_seconds": {
      "type": "integer",
      "maximum": 86400.0,
      "exclusiveMinimum": 0.0,
      "title": "Duration Seconds"
    },
    "thumbnail_url": {
      "anyOf": [
        {
          "type": "string",
          "maxLength": 500
        },
        {
          "type": "null"
        }
      ],
      "title": "Thumbnail Url"
    },
    "captions": {
      "items": {
        "$ref": "#/components/schemas/Caption"
      },
      "type": "array",
      "maxItems": 20,
      "title": "Captions"
    },
    "visibility": {
      "type": "string",
      "enum": [
        "public",
        "unlisted",
        "enrolled",
        "institution"
      ],
      "title": "Visibility",
      "default": "enrolled"
    },
    "offline_policy": {
      "type": "string",
      "enum": [
        "forbidden",
        "allowed"
      ],
      "title": "Offline Policy",
      "default": "forbidden"
    },
    "master_drive_file_id": {
      "anyOf": [
        {
          "type": "string",
          "maxLength": 240
        },
        {
          "type": "null"
        }
      ],
      "title": "Master Drive File Id"
    },
    "rights_confirmed": {
      "type": "boolean",
      "title": "Rights Confirmed",
      "default": false
    },
    "followup_activity_id": {
      "type": "string",
      "pattern": "^[a-z0-9][a-z0-9_.-]{0,79}$",
      "title": "Followup Activity Id"
    }
  },
  "additionalProperties": false,
  "type": "object",
  "required": [
    "institution_id",
    "program_id",
    "course_id",
    "module_id",
    "title",
    "competency_id",
    "provider",
    "provider_asset_id",
    "duration_seconds",
    "followup_activity_id"
  ],
  "title": "MediaCreate"
}
```

<a id="schema-MediaPage"></a>

## MediaPage

| Campo | Obrigatório | Tipo | Default / limites |
| --- | --- | --- | --- |
| `media` | sim | array de [MediaResponse](SCHEMAS.md#schema-MediaResponse) | — |

Schema exato:
```json
{
  "properties": {
    "media": {
      "items": {
        "$ref": "#/components/schemas/MediaResponse"
      },
      "type": "array",
      "title": "Media"
    }
  },
  "type": "object",
  "required": [
    "media"
  ],
  "title": "MediaPage"
}
```

<a id="schema-MediaPatch"></a>

## MediaPatch

| Campo | Obrigatório | Tipo | Default / limites |
| --- | --- | --- | --- |
| `title` | não | string / null | minLength=2; maxLength=240 |
| `description` | não | string / null | maxLength=4000 |
| `competency_id` | não | string / null | pattern="^[a-z0-9][a-z0-9_.-]{0,79}$" |
| `provider` | não | enum ["youtube", "cloudflare_stream", "external_hls"] / null | — |
| `provider_asset_id` | não | string / null | minLength=1; maxLength=500 |
| `duration_seconds` | não | integer / null | maximum=86400.0; exclusiveMinimum=0.0 |
| `thumbnail_url` | não | string / null | maxLength=500 |
| `captions` | não | array de [Caption](SCHEMAS.md#schema-Caption) / null | maxItems=20 |
| `visibility` | não | enum ["public", "unlisted", "enrolled", "institution"] / null | — |
| `offline_policy` | não | enum ["forbidden", "allowed"] / null | — |
| `master_drive_file_id` | não | string / null | maxLength=240 |
| `rights_confirmed` | não | boolean / null | — |
| `followup_activity_id` | não | string / null | pattern="^[a-z0-9][a-z0-9_.-]{0,79}$" |

Schema exato:
```json
{
  "properties": {
    "title": {
      "anyOf": [
        {
          "type": "string",
          "maxLength": 240,
          "minLength": 2
        },
        {
          "type": "null"
        }
      ],
      "title": "Title"
    },
    "description": {
      "anyOf": [
        {
          "type": "string",
          "maxLength": 4000
        },
        {
          "type": "null"
        }
      ],
      "title": "Description"
    },
    "competency_id": {
      "anyOf": [
        {
          "type": "string",
          "pattern": "^[a-z0-9][a-z0-9_.-]{0,79}$"
        },
        {
          "type": "null"
        }
      ],
      "title": "Competency Id"
    },
    "provider": {
      "anyOf": [
        {
          "type": "string",
          "enum": [
            "youtube",
            "cloudflare_stream",
            "external_hls"
          ]
        },
        {
          "type": "null"
        }
      ],
      "title": "Provider"
    },
    "provider_asset_id": {
      "anyOf": [
        {
          "type": "string",
          "maxLength": 500,
          "minLength": 1
        },
        {
          "type": "null"
        }
      ],
      "title": "Provider Asset Id"
    },
    "duration_seconds": {
      "anyOf": [
        {
          "type": "integer",
          "maximum": 86400.0,
          "exclusiveMinimum": 0.0
        },
        {
          "type": "null"
        }
      ],
      "title": "Duration Seconds"
    },
    "thumbnail_url": {
      "anyOf": [
        {
          "type": "string",
          "maxLength": 500
        },
        {
          "type": "null"
        }
      ],
      "title": "Thumbnail Url"
    },
    "captions": {
      "anyOf": [
        {
          "items": {
            "$ref": "#/components/schemas/Caption"
          },
          "type": "array",
          "maxItems": 20
        },
        {
          "type": "null"
        }
      ],
      "title": "Captions"
    },
    "visibility": {
      "anyOf": [
        {
          "type": "string",
          "enum": [
            "public",
            "unlisted",
            "enrolled",
            "institution"
          ]
        },
        {
          "type": "null"
        }
      ],
      "title": "Visibility"
    },
    "offline_policy": {
      "anyOf": [
        {
          "type": "string",
          "enum": [
            "forbidden",
            "allowed"
          ]
        },
        {
          "type": "null"
        }
      ],
      "title": "Offline Policy"
    },
    "master_drive_file_id": {
      "anyOf": [
        {
          "type": "string",
          "maxLength": 240
        },
        {
          "type": "null"
        }
      ],
      "title": "Master Drive File Id"
    },
    "rights_confirmed": {
      "anyOf": [
        {
          "type": "boolean"
        },
        {
          "type": "null"
        }
      ],
      "title": "Rights Confirmed"
    },
    "followup_activity_id": {
      "anyOf": [
        {
          "type": "string",
          "pattern": "^[a-z0-9][a-z0-9_.-]{0,79}$"
        },
        {
          "type": "null"
        }
      ],
      "title": "Followup Activity Id"
    }
  },
  "additionalProperties": false,
  "type": "object",
  "title": "MediaPatch"
}
```

<a id="schema-MediaRatingRequest"></a>

## MediaRatingRequest

| Campo | Obrigatório | Tipo | Default / limites |
| --- | --- | --- | --- |
| `rating` | sim | integer | minimum=1.0; maximum=5.0 |

Schema exato:
```json
{
  "properties": {
    "rating": {
      "type": "integer",
      "maximum": 5.0,
      "minimum": 1.0,
      "title": "Rating"
    }
  },
  "additionalProperties": false,
  "type": "object",
  "required": [
    "rating"
  ],
  "title": "MediaRatingRequest"
}
```

<a id="schema-MediaRatingResponse"></a>

## MediaRatingResponse

| Campo | Obrigatório | Tipo | Default / limites |
| --- | --- | --- | --- |
| `media_id` | sim | string | — |
| `rating` | sim | integer | — |
| `submitted_at` | sim | string (date-time) | — |
| `updated_at` | sim | string (date-time) | — |

Schema exato:
```json
{
  "properties": {
    "media_id": {
      "type": "string",
      "title": "Media Id"
    },
    "rating": {
      "type": "integer",
      "title": "Rating"
    },
    "submitted_at": {
      "type": "string",
      "format": "date-time",
      "title": "Submitted At"
    },
    "updated_at": {
      "type": "string",
      "format": "date-time",
      "title": "Updated At"
    }
  },
  "type": "object",
  "required": [
    "media_id",
    "rating",
    "submitted_at",
    "updated_at"
  ],
  "title": "MediaRatingResponse"
}
```

<a id="schema-MediaResponse"></a>

## MediaResponse

| Campo | Obrigatório | Tipo | Default / limites |
| --- | --- | --- | --- |
| `id` | sim | string | — |
| `institution_id` | sim | string | — |
| `program_id` | sim | string | — |
| `course_id` | sim | string | — |
| `module_id` | sim | string | — |
| `creator_user_id` | sim | string | — |
| `title` | sim | string | — |
| `description` | sim | string | — |
| `competency_id` | sim | string | — |
| `provider` | sim | enum ["youtube", "cloudflare_stream", "external_hls"] | — |
| `duration_seconds` | sim | integer | — |
| `thumbnail_url` | sim | string / null | — |
| `captions` | sim | array de object | — |
| `visibility` | sim | enum ["public", "unlisted", "enrolled", "institution"] | — |
| `offline_policy` | sim | enum ["forbidden", "allowed"] | — |
| `status` | sim | enum ["draft", "processing", "published", "blocked", "archived"] | — |
| `followup_activity_id` | sim | string | — |
| `playback_url` | sim | string / null | — |
| `published_at` | sim | string (date-time) / null | — |

Schema exato:
```json
{
  "properties": {
    "id": {
      "type": "string",
      "title": "Id"
    },
    "institution_id": {
      "type": "string",
      "title": "Institution Id"
    },
    "program_id": {
      "type": "string",
      "title": "Program Id"
    },
    "course_id": {
      "type": "string",
      "title": "Course Id"
    },
    "module_id": {
      "type": "string",
      "title": "Module Id"
    },
    "creator_user_id": {
      "type": "string",
      "title": "Creator User Id"
    },
    "title": {
      "type": "string",
      "title": "Title"
    },
    "description": {
      "type": "string",
      "title": "Description"
    },
    "competency_id": {
      "type": "string",
      "title": "Competency Id"
    },
    "provider": {
      "type": "string",
      "enum": [
        "youtube",
        "cloudflare_stream",
        "external_hls"
      ],
      "title": "Provider"
    },
    "duration_seconds": {
      "type": "integer",
      "title": "Duration Seconds"
    },
    "thumbnail_url": {
      "anyOf": [
        {
          "type": "string"
        },
        {
          "type": "null"
        }
      ],
      "title": "Thumbnail Url"
    },
    "captions": {
      "items": {
        "additionalProperties": {
          "type": "string"
        },
        "type": "object"
      },
      "type": "array",
      "title": "Captions"
    },
    "visibility": {
      "type": "string",
      "enum": [
        "public",
        "unlisted",
        "enrolled",
        "institution"
      ],
      "title": "Visibility"
    },
    "offline_policy": {
      "type": "string",
      "enum": [
        "forbidden",
        "allowed"
      ],
      "title": "Offline Policy"
    },
    "status": {
      "type": "string",
      "enum": [
        "draft",
        "processing",
        "published",
        "blocked",
        "archived"
      ],
      "title": "Status"
    },
    "followup_activity_id": {
      "type": "string",
      "title": "Followup Activity Id"
    },
    "playback_url": {
      "anyOf": [
        {
          "type": "string"
        },
        {
          "type": "null"
        }
      ],
      "title": "Playback Url"
    },
    "published_at": {
      "anyOf": [
        {
          "type": "string",
          "format": "date-time"
        },
        {
          "type": "null"
        }
      ],
      "title": "Published At"
    }
  },
  "type": "object",
  "required": [
    "id",
    "institution_id",
    "program_id",
    "course_id",
    "module_id",
    "creator_user_id",
    "title",
    "description",
    "competency_id",
    "provider",
    "duration_seconds",
    "thumbnail_url",
    "captions",
    "visibility",
    "offline_policy",
    "status",
    "followup_activity_id",
    "playback_url",
    "published_at"
  ],
  "title": "MediaResponse"
}
```

<a id="schema-MembershipCreate"></a>

## MembershipCreate

| Campo | Obrigatório | Tipo | Default / limites |
| --- | --- | --- | --- |
| `user_id` | sim | string | minLength=1; maxLength=36 |
| `role` | sim | enum ["student", "teacher", "monitor", "creator", "coordinator", "program_operator", "finance", "admin"] | — |

Schema exato:
```json
{
  "properties": {
    "user_id": {
      "type": "string",
      "maxLength": 36,
      "minLength": 1,
      "title": "User Id"
    },
    "role": {
      "type": "string",
      "enum": [
        "student",
        "teacher",
        "monitor",
        "creator",
        "coordinator",
        "program_operator",
        "finance",
        "admin"
      ],
      "title": "Role"
    }
  },
  "additionalProperties": false,
  "type": "object",
  "required": [
    "user_id",
    "role"
  ],
  "title": "MembershipCreate"
}
```

<a id="schema-MembershipResponse"></a>

## MembershipResponse

| Campo | Obrigatório | Tipo | Default / limites |
| --- | --- | --- | --- |
| `user_id` | sim | string | minLength=1; maxLength=36 |
| `role` | sim | enum ["student", "teacher", "monitor", "creator", "coordinator", "program_operator", "finance", "admin"] | — |
| `program_id` | sim | string | — |
| `status` | sim | string | — |

Schema exato:
```json
{
  "properties": {
    "user_id": {
      "type": "string",
      "maxLength": 36,
      "minLength": 1,
      "title": "User Id"
    },
    "role": {
      "type": "string",
      "enum": [
        "student",
        "teacher",
        "monitor",
        "creator",
        "coordinator",
        "program_operator",
        "finance",
        "admin"
      ],
      "title": "Role"
    },
    "program_id": {
      "type": "string",
      "title": "Program Id"
    },
    "status": {
      "type": "string",
      "title": "Status"
    }
  },
  "additionalProperties": false,
  "type": "object",
  "required": [
    "user_id",
    "role",
    "program_id",
    "status"
  ],
  "title": "MembershipResponse"
}
```

<a id="schema-MonitorExceptionItem"></a>

## MonitorExceptionItem

| Campo | Obrigatório | Tipo | Default / limites |
| --- | --- | --- | --- |
| `user_id` | sim | string | — |
| `name` | sim | string | — |
| `alerts` | sim | array de [StudentAlert](SCHEMAS.md#schema-StudentAlert) | — |

Schema exato:
```json
{
  "properties": {
    "user_id": {
      "type": "string",
      "title": "User Id"
    },
    "name": {
      "type": "string",
      "title": "Name"
    },
    "alerts": {
      "items": {
        "$ref": "#/components/schemas/StudentAlert"
      },
      "type": "array",
      "title": "Alerts"
    }
  },
  "type": "object",
  "required": [
    "user_id",
    "name",
    "alerts"
  ],
  "title": "MonitorExceptionItem"
}
```

<a id="schema-MonitorExceptionsResponse"></a>

## MonitorExceptionsResponse

| Campo | Obrigatório | Tipo | Default / limites |
| --- | --- | --- | --- |
| `generated_at` | sim | string (date-time) | — |
| `total_students` | sim | integer | — |
| `attention_students` | sim | integer | — |
| `students` | sim | array de [MonitorExceptionItem](SCHEMAS.md#schema-MonitorExceptionItem) | — |

Schema exato:
```json
{
  "properties": {
    "generated_at": {
      "type": "string",
      "format": "date-time",
      "title": "Generated At"
    },
    "total_students": {
      "type": "integer",
      "title": "Total Students"
    },
    "attention_students": {
      "type": "integer",
      "title": "Attention Students"
    },
    "students": {
      "items": {
        "$ref": "#/components/schemas/MonitorExceptionItem"
      },
      "type": "array",
      "title": "Students"
    }
  },
  "type": "object",
  "required": [
    "generated_at",
    "total_students",
    "attention_students",
    "students"
  ],
  "title": "MonitorExceptionsResponse"
}
```

<a id="schema-OfficialAttendanceCreate"></a>

## OfficialAttendanceCreate

| Campo | Obrigatório | Tipo | Default / limites |
| --- | --- | --- | --- |
| `status` | sim | enum ["VALID", "ABSENT", "JUSTIFIED_ABSENCE", "PENDING_MAKEUP"] | — |
| `makeup_session_id` | não | string / null | minLength=1; maxLength=36 |
| `expected_revision` | sim | integer | minimum=0.0 |
| `reason` | sim | string | minLength=3; maxLength=500 |
| `idempotency_key` | sim | string | minLength=8; maxLength=180; pattern="^[A-Za-z0-9_.:-]+$" |

Schema exato:
```json
{
  "properties": {
    "status": {
      "type": "string",
      "enum": [
        "VALID",
        "ABSENT",
        "JUSTIFIED_ABSENCE",
        "PENDING_MAKEUP"
      ],
      "title": "Status"
    },
    "makeup_session_id": {
      "anyOf": [
        {
          "type": "string",
          "maxLength": 36,
          "minLength": 1
        },
        {
          "type": "null"
        }
      ],
      "title": "Makeup Session Id"
    },
    "expected_revision": {
      "type": "integer",
      "minimum": 0.0,
      "title": "Expected Revision"
    },
    "reason": {
      "type": "string",
      "maxLength": 500,
      "minLength": 3,
      "title": "Reason"
    },
    "idempotency_key": {
      "type": "string",
      "maxLength": 180,
      "minLength": 8,
      "pattern": "^[A-Za-z0-9_.:-]+$",
      "title": "Idempotency Key"
    }
  },
  "additionalProperties": false,
  "type": "object",
  "required": [
    "status",
    "expected_revision",
    "reason",
    "idempotency_key"
  ],
  "title": "OfficialAttendanceCreate"
}
```

<a id="schema-PersonLookup"></a>

## PersonLookup

| Campo | Obrigatório | Tipo | Default / limites |
| --- | --- | --- | --- |
| `person_id` | sim | string | minLength=1; maxLength=36 |
| `identity_proof` | não | string / null | maxLength=2000 |

Schema exato:
```json
{
  "properties": {
    "person_id": {
      "type": "string",
      "maxLength": 36,
      "minLength": 1,
      "title": "Person Id"
    },
    "identity_proof": {
      "anyOf": [
        {
          "type": "string",
          "maxLength": 2000
        },
        {
          "type": "null"
        }
      ],
      "title": "Identity Proof"
    }
  },
  "additionalProperties": false,
  "type": "object",
  "required": [
    "person_id"
  ],
  "title": "PersonLookup"
}
```

<a id="schema-PlanClassCommand"></a>

## PlanClassCommand

| Campo | Obrigatório | Tipo | Default / limites |
| --- | --- | --- | --- |
| `id` | sim | string | minLength=16; maxLength=180 |
| `reason` | sim | string | minLength=3; maxLength=500 |
| `institution_id` | sim | string | minLength=1; maxLength=36 |
| `program_id` | sim | string | minLength=1; maxLength=36 |
| `course_id` | sim | string | minLength=1; maxLength=120 |
| `version_id` | sim | string | minLength=1; maxLength=36 |
| `expected_revision` | sim | integer | minimum=0.0 |
| `name` | sim | string | minLength=2; maxLength=240 |
| `offer_municipality` | sim | string | minLength=2; maxLength=240 |
| `offer_location` | sim | string | minLength=2; maxLength=500 |
| `start_date` | sim | string (date) | — |
| `end_date` | sim | string (date) | — |

Schema exato:
```json
{
  "properties": {
    "id": {
      "type": "string",
      "maxLength": 180,
      "minLength": 16,
      "title": "Id"
    },
    "reason": {
      "type": "string",
      "maxLength": 500,
      "minLength": 3,
      "title": "Reason"
    },
    "institution_id": {
      "type": "string",
      "maxLength": 36,
      "minLength": 1,
      "title": "Institution Id"
    },
    "program_id": {
      "type": "string",
      "maxLength": 36,
      "minLength": 1,
      "title": "Program Id"
    },
    "course_id": {
      "type": "string",
      "maxLength": 120,
      "minLength": 1,
      "title": "Course Id"
    },
    "version_id": {
      "type": "string",
      "maxLength": 36,
      "minLength": 1,
      "title": "Version Id"
    },
    "expected_revision": {
      "type": "integer",
      "minimum": 0.0,
      "title": "Expected Revision"
    },
    "name": {
      "type": "string",
      "maxLength": 240,
      "minLength": 2,
      "title": "Name"
    },
    "offer_municipality": {
      "type": "string",
      "maxLength": 240,
      "minLength": 2,
      "title": "Offer Municipality"
    },
    "offer_location": {
      "type": "string",
      "maxLength": 500,
      "minLength": 2,
      "title": "Offer Location"
    },
    "start_date": {
      "type": "string",
      "format": "date",
      "title": "Start Date"
    },
    "end_date": {
      "type": "string",
      "format": "date",
      "title": "End Date"
    }
  },
  "additionalProperties": false,
  "type": "object",
  "required": [
    "id",
    "reason",
    "institution_id",
    "program_id",
    "course_id",
    "version_id",
    "expected_revision",
    "name",
    "offer_municipality",
    "offer_location",
    "start_date",
    "end_date"
  ],
  "title": "PlanClassCommand"
}
```

<a id="schema-PlaybackAuthorizationResponse"></a>

## PlaybackAuthorizationResponse

| Campo | Obrigatório | Tipo | Default / limites |
| --- | --- | --- | --- |
| `media_id` | sim | string | — |
| `playback_url` | sim | string | — |
| `expires_at` | sim | string (date-time) | — |
| `token_type` | não | const "media_playback" | default="media_playback" |

Schema exato:
```json
{
  "properties": {
    "media_id": {
      "type": "string",
      "title": "Media Id"
    },
    "playback_url": {
      "type": "string",
      "title": "Playback Url"
    },
    "expires_at": {
      "type": "string",
      "format": "date-time",
      "title": "Expires At"
    },
    "token_type": {
      "type": "string",
      "const": "media_playback",
      "title": "Token Type",
      "default": "media_playback"
    }
  },
  "type": "object",
  "required": [
    "media_id",
    "playback_url",
    "expires_at"
  ],
  "title": "PlaybackAuthorizationResponse"
}
```

<a id="schema-PolicyCreate"></a>

## PolicyCreate

| Campo | Obrigatório | Tipo | Default / limites |
| --- | --- | --- | --- |
| `course_version_id` | sim | string | minLength=1; maxLength=36 |
| `formal_hours` | sim | const 80 | — |
| `session_ids` | sim | array de string | minItems=1; maxItems=100 |
| `checkpoints` | sim | array de [CheckpointConfig](SCHEMAS.md#schema-CheckpointConfig) | minItems=1; maxItems=100 |
| `operational_owner_id` | sim | string | minLength=1; maxLength=36 |

Schema exato:
```json
{
  "properties": {
    "course_version_id": {
      "type": "string",
      "maxLength": 36,
      "minLength": 1,
      "title": "Course Version Id"
    },
    "formal_hours": {
      "type": "integer",
      "const": 80,
      "title": "Formal Hours"
    },
    "session_ids": {
      "items": {
        "type": "string"
      },
      "type": "array",
      "maxItems": 100,
      "minItems": 1,
      "title": "Session Ids"
    },
    "checkpoints": {
      "items": {
        "$ref": "#/components/schemas/CheckpointConfig"
      },
      "type": "array",
      "maxItems": 100,
      "minItems": 1,
      "title": "Checkpoints"
    },
    "operational_owner_id": {
      "type": "string",
      "maxLength": 36,
      "minLength": 1,
      "title": "Operational Owner Id"
    }
  },
  "additionalProperties": false,
  "type": "object",
  "required": [
    "course_version_id",
    "formal_hours",
    "session_ids",
    "checkpoints",
    "operational_owner_id"
  ],
  "title": "PolicyCreate"
}
```

<a id="schema-PrepareClassCommand"></a>

## PrepareClassCommand

| Campo | Obrigatório | Tipo | Default / limites |
| --- | --- | --- | --- |
| `id` | sim | string | minLength=16; maxLength=180 |
| `reason` | sim | string | minLength=3; maxLength=500 |
| `institution_id` | sim | string | minLength=1; maxLength=36 |
| `program_id` | sim | string | minLength=1; maxLength=36 |
| `course_id` | sim | string | minLength=1; maxLength=120 |
| `version_id` | sim | string | minLength=1; maxLength=36 |
| `teacher_id` | sim | string | minLength=1; maxLength=36 |
| `monitor_ids` | não | array de string | — |
| `name` | sim | string | minLength=2; maxLength=240 |
| `offer_municipality` | sim | string | minLength=2; maxLength=240 |
| `offer_location` | sim | string | minLength=2; maxLength=500 |
| `start_date` | sim | string (date) | — |
| `end_date` | sim | string (date) | — |

Schema exato:
```json
{
  "properties": {
    "id": {
      "type": "string",
      "maxLength": 180,
      "minLength": 16,
      "title": "Id"
    },
    "reason": {
      "type": "string",
      "maxLength": 500,
      "minLength": 3,
      "title": "Reason"
    },
    "institution_id": {
      "type": "string",
      "maxLength": 36,
      "minLength": 1,
      "title": "Institution Id"
    },
    "program_id": {
      "type": "string",
      "maxLength": 36,
      "minLength": 1,
      "title": "Program Id"
    },
    "course_id": {
      "type": "string",
      "maxLength": 120,
      "minLength": 1,
      "title": "Course Id"
    },
    "version_id": {
      "type": "string",
      "maxLength": 36,
      "minLength": 1,
      "title": "Version Id"
    },
    "teacher_id": {
      "type": "string",
      "maxLength": 36,
      "minLength": 1,
      "title": "Teacher Id"
    },
    "monitor_ids": {
      "items": {
        "type": "string"
      },
      "type": "array",
      "title": "Monitor Ids"
    },
    "name": {
      "type": "string",
      "maxLength": 240,
      "minLength": 2,
      "title": "Name"
    },
    "offer_municipality": {
      "type": "string",
      "maxLength": 240,
      "minLength": 2,
      "title": "Offer Municipality"
    },
    "offer_location": {
      "type": "string",
      "maxLength": 500,
      "minLength": 2,
      "title": "Offer Location"
    },
    "start_date": {
      "type": "string",
      "format": "date",
      "title": "Start Date"
    },
    "end_date": {
      "type": "string",
      "format": "date",
      "title": "End Date"
    }
  },
  "additionalProperties": false,
  "type": "object",
  "required": [
    "id",
    "reason",
    "institution_id",
    "program_id",
    "course_id",
    "version_id",
    "teacher_id",
    "name",
    "offer_municipality",
    "offer_location",
    "start_date",
    "end_date"
  ],
  "title": "PrepareClassCommand"
}
```

<a id="schema-PresenceCreate"></a>

## PresenceCreate

| Campo | Obrigatório | Tipo | Default / limites |
| --- | --- | --- | --- |
| `status` | sim | enum ["confirmed_present", "justified_absence", "absent"] | — |
| `expected_revision` | sim | integer | minimum=0.0 |
| `reason` | sim | string | minLength=3; maxLength=500 |
| `idempotency_key` | sim | string | minLength=8; maxLength=180; pattern="^[A-Za-z0-9_.:-]+$" |

Schema exato:
```json
{
  "properties": {
    "status": {
      "type": "string",
      "enum": [
        "confirmed_present",
        "justified_absence",
        "absent"
      ],
      "title": "Status"
    },
    "expected_revision": {
      "type": "integer",
      "minimum": 0.0,
      "title": "Expected Revision"
    },
    "reason": {
      "type": "string",
      "maxLength": 500,
      "minLength": 3,
      "title": "Reason"
    },
    "idempotency_key": {
      "type": "string",
      "maxLength": 180,
      "minLength": 8,
      "pattern": "^[A-Za-z0-9_.:-]+$",
      "title": "Idempotency Key"
    }
  },
  "additionalProperties": false,
  "type": "object",
  "required": [
    "status",
    "expected_revision",
    "reason",
    "idempotency_key"
  ],
  "title": "PresenceCreate"
}
```

<a id="schema-ProgramCreate"></a>

## ProgramCreate

| Campo | Obrigatório | Tipo | Default / limites |
| --- | --- | --- | --- |
| `institution_id` | sim | string | minLength=1; maxLength=36 |
| `name` | sim | string | minLength=2; maxLength=240 |

Schema exato:
```json
{
  "properties": {
    "institution_id": {
      "type": "string",
      "maxLength": 36,
      "minLength": 1,
      "title": "Institution Id"
    },
    "name": {
      "type": "string",
      "maxLength": 240,
      "minLength": 2,
      "title": "Name"
    }
  },
  "additionalProperties": false,
  "type": "object",
  "required": [
    "institution_id",
    "name"
  ],
  "title": "ProgramCreate"
}
```

<a id="schema-ProgramHierarchy"></a>

## ProgramHierarchy

| Campo | Obrigatório | Tipo | Default / limites |
| --- | --- | --- | --- |
| `institution_id` | sim | string | minLength=1; maxLength=36 |
| `name` | sim | string | minLength=2; maxLength=240 |
| `id` | sim | string | — |
| `course_ids` | sim | array de string | — |
| `memberships` | sim | array de [MembershipResponse](SCHEMAS.md#schema-MembershipResponse) | — |

Schema exato:
```json
{
  "properties": {
    "institution_id": {
      "type": "string",
      "maxLength": 36,
      "minLength": 1,
      "title": "Institution Id"
    },
    "name": {
      "type": "string",
      "maxLength": 240,
      "minLength": 2,
      "title": "Name"
    },
    "id": {
      "type": "string",
      "title": "Id"
    },
    "course_ids": {
      "items": {
        "type": "string"
      },
      "type": "array",
      "title": "Course Ids"
    },
    "memberships": {
      "items": {
        "$ref": "#/components/schemas/MembershipResponse"
      },
      "type": "array",
      "title": "Memberships"
    }
  },
  "additionalProperties": false,
  "type": "object",
  "required": [
    "institution_id",
    "name",
    "id",
    "course_ids",
    "memberships"
  ],
  "title": "ProgramHierarchy"
}
```

<a id="schema-ProgramResponse"></a>

## ProgramResponse

| Campo | Obrigatório | Tipo | Default / limites |
| --- | --- | --- | --- |
| `institution_id` | sim | string | minLength=1; maxLength=36 |
| `name` | sim | string | minLength=2; maxLength=240 |
| `id` | sim | string | — |

Schema exato:
```json
{
  "properties": {
    "institution_id": {
      "type": "string",
      "maxLength": 36,
      "minLength": 1,
      "title": "Institution Id"
    },
    "name": {
      "type": "string",
      "maxLength": 240,
      "minLength": 2,
      "title": "Name"
    },
    "id": {
      "type": "string",
      "title": "Id"
    }
  },
  "additionalProperties": false,
  "type": "object",
  "required": [
    "institution_id",
    "name",
    "id"
  ],
  "title": "ProgramResponse"
}
```

<a id="schema-PublicCourseCatalog"></a>

## PublicCourseCatalog

| Campo | Obrigatório | Tipo | Default / limites |
| --- | --- | --- | --- |
| `courses` | sim | array de [PublicCourseProjection](SCHEMAS.md#schema-PublicCourseProjection) | — |
| `offset` | sim | integer | — |
| `limit` | sim | integer | — |
| `total` | sim | integer | — |

Schema exato:
```json
{
  "properties": {
    "courses": {
      "items": {
        "$ref": "#/components/schemas/PublicCourseProjection"
      },
      "type": "array",
      "title": "Courses"
    },
    "offset": {
      "type": "integer",
      "title": "Offset"
    },
    "limit": {
      "type": "integer",
      "title": "Limit"
    },
    "total": {
      "type": "integer",
      "title": "Total"
    }
  },
  "type": "object",
  "required": [
    "courses",
    "offset",
    "limit",
    "total"
  ],
  "title": "PublicCourseCatalog"
}
```

<a id="schema-PublicCourseProjection"></a>

## PublicCourseProjection

| Campo | Obrigatório | Tipo | Default / limites |
| --- | --- | --- | --- |
| `slug` | sim | string | — |
| `title` | sim | string | — |
| `status` | sim | const "published" | — |
| `published_version_label` | sim | string | — |
| `updated_at` | sim | string (date-time) | — |
| `summary` | não | string / null | — |
| `cover_public_url` | não | string / null | — |
| `public_workload_text` | não | string / null | — |
| `public_audience_text` | não | string / null | — |

Schema exato:
```json
{
  "properties": {
    "slug": {
      "type": "string",
      "title": "Slug"
    },
    "title": {
      "type": "string",
      "title": "Title"
    },
    "status": {
      "type": "string",
      "const": "published",
      "title": "Status"
    },
    "published_version_label": {
      "type": "string",
      "title": "Published Version Label"
    },
    "updated_at": {
      "type": "string",
      "format": "date-time",
      "title": "Updated At"
    },
    "summary": {
      "anyOf": [
        {
          "type": "string"
        },
        {
          "type": "null"
        }
      ],
      "title": "Summary"
    },
    "cover_public_url": {
      "anyOf": [
        {
          "type": "string"
        },
        {
          "type": "null"
        }
      ],
      "title": "Cover Public Url"
    },
    "public_workload_text": {
      "anyOf": [
        {
          "type": "string"
        },
        {
          "type": "null"
        }
      ],
      "title": "Public Workload Text"
    },
    "public_audience_text": {
      "anyOf": [
        {
          "type": "string"
        },
        {
          "type": "null"
        }
      ],
      "title": "Public Audience Text"
    }
  },
  "type": "object",
  "required": [
    "slug",
    "title",
    "status",
    "published_version_label",
    "updated_at"
  ],
  "title": "PublicCourseProjection"
}
```

<a id="schema-PublicUser"></a>

## PublicUser

| Campo | Obrigatório | Tipo | Default / limites |
| --- | --- | --- | --- |
| `id` | sim | string | — |
| `name` | sim | string | — |
| `role` | sim | string | — |

Schema exato:
```json
{
  "properties": {
    "id": {
      "type": "string",
      "title": "Id"
    },
    "name": {
      "type": "string",
      "title": "Name"
    },
    "role": {
      "type": "string",
      "title": "Role"
    }
  },
  "type": "object",
  "required": [
    "id",
    "name",
    "role"
  ],
  "title": "PublicUser"
}
```

<a id="schema-PublishedBlockAnswerKeyItem"></a>

## PublishedBlockAnswerKeyItem

| Campo | Obrigatório | Tipo | Default / limites |
| --- | --- | --- | --- |
| `correct_indices` | sim | array de integer | — |
| `explanation` | sim | string | — |
| `graded` | sim | boolean | — |

Schema exato:
```json
{
  "properties": {
    "correct_indices": {
      "items": {
        "type": "integer"
      },
      "type": "array",
      "title": "Correct Indices"
    },
    "explanation": {
      "type": "string",
      "title": "Explanation"
    },
    "graded": {
      "type": "boolean",
      "title": "Graded"
    }
  },
  "type": "object",
  "required": [
    "correct_indices",
    "explanation",
    "graded"
  ],
  "title": "PublishedBlockAnswerKeyItem"
}
```

<a id="schema-RefreshRequest"></a>

## RefreshRequest

| Campo | Obrigatório | Tipo | Default / limites |
| --- | --- | --- | --- |
| `refresh_token` | sim | string (password) | writeOnly=true |

Schema exato:
```json
{
  "properties": {
    "refresh_token": {
      "type": "string",
      "format": "password",
      "title": "Refresh Token",
      "writeOnly": true
    }
  },
  "type": "object",
  "required": [
    "refresh_token"
  ],
  "title": "RefreshRequest"
}
```

<a id="schema-RegisterRequest"></a>

## RegisterRequest

| Campo | Obrigatório | Tipo | Default / limites |
| --- | --- | --- | --- |
| `name` | sim | string | minLength=2; maxLength=240 |
| `cpf` | sim | string (password) | writeOnly=true |
| `phone` | sim | string | minLength=10; maxLength=32 |
| `password` | sim | string (password) | writeOnly=true |
| `activation_token` | não | string (password) / null | writeOnly=true |

Schema exato:
```json
{
  "properties": {
    "name": {
      "type": "string",
      "maxLength": 240,
      "minLength": 2,
      "title": "Name"
    },
    "cpf": {
      "type": "string",
      "format": "password",
      "title": "Cpf",
      "writeOnly": true
    },
    "phone": {
      "type": "string",
      "maxLength": 32,
      "minLength": 10,
      "title": "Phone"
    },
    "password": {
      "type": "string",
      "format": "password",
      "title": "Password",
      "writeOnly": true
    },
    "activation_token": {
      "anyOf": [
        {
          "type": "string",
          "format": "password",
          "writeOnly": true
        },
        {
          "type": "null"
        }
      ],
      "title": "Activation Token"
    }
  },
  "type": "object",
  "required": [
    "name",
    "cpf",
    "phone",
    "password"
  ],
  "title": "RegisterRequest"
}
```

<a id="schema-ReportResponse"></a>

## ReportResponse

| Campo | Obrigatório | Tipo | Default / limites |
| --- | --- | --- | --- |
| `id` | sim | string | — |
| `class_id` | sim | string | — |
| `session_id` | sim | string | — |
| `generated_at` | sim | string (date-time) | — |
| `report_digest` | sim | string | — |
| `summary` | sim | object | additionalProperties=true |

Schema exato:
```json
{
  "properties": {
    "id": {
      "type": "string",
      "title": "Id"
    },
    "class_id": {
      "type": "string",
      "title": "Class Id"
    },
    "session_id": {
      "type": "string",
      "title": "Session Id"
    },
    "generated_at": {
      "type": "string",
      "format": "date-time",
      "title": "Generated At"
    },
    "report_digest": {
      "type": "string",
      "title": "Report Digest"
    },
    "summary": {
      "additionalProperties": true,
      "type": "object",
      "title": "Summary"
    }
  },
  "type": "object",
  "required": [
    "id",
    "class_id",
    "session_id",
    "generated_at",
    "report_digest",
    "summary"
  ],
  "title": "ReportResponse"
}
```

<a id="schema-RequestCreate"></a>

## RequestCreate

| Campo | Obrigatório | Tipo | Default / limites |
| --- | --- | --- | --- |
| `enrollment_id` | sim | string | minLength=1; maxLength=36 |
| `course_version_id` | sim | string | minLength=1; maxLength=36 |
| `class_id` | não | string / null | minLength=1; maxLength=36 |

Schema exato:
```json
{
  "properties": {
    "enrollment_id": {
      "type": "string",
      "maxLength": 36,
      "minLength": 1,
      "title": "Enrollment Id"
    },
    "course_version_id": {
      "type": "string",
      "maxLength": 36,
      "minLength": 1,
      "title": "Course Version Id"
    },
    "class_id": {
      "anyOf": [
        {
          "type": "string",
          "maxLength": 36,
          "minLength": 1
        },
        {
          "type": "null"
        }
      ],
      "title": "Class Id"
    }
  },
  "additionalProperties": false,
  "type": "object",
  "required": [
    "enrollment_id",
    "course_version_id"
  ],
  "title": "RequestCreate"
}
```

<a id="schema-RevisionAction"></a>

## RevisionAction

| Campo | Obrigatório | Tipo | Default / limites |
| --- | --- | --- | --- |
| `expected_revision` | sim | integer | minimum=1.0 |

Schema exato:
```json
{
  "properties": {
    "expected_revision": {
      "type": "integer",
      "minimum": 1.0,
      "title": "Expected Revision"
    }
  },
  "additionalProperties": false,
  "type": "object",
  "required": [
    "expected_revision"
  ],
  "title": "RevisionAction"
}
```

<a id="schema-ScoreRequest"></a>

## ScoreRequest

| Campo | Obrigatório | Tipo | Default / limites |
| --- | --- | --- | --- |
| `media_id` | sim | string | minLength=1; maxLength=36 |
| `window_start` | sim | string (date-time) | — |
| `window_end` | sim | string (date-time) | — |

Schema exato:
```json
{
  "properties": {
    "media_id": {
      "type": "string",
      "maxLength": 36,
      "minLength": 1,
      "title": "Media Id"
    },
    "window_start": {
      "type": "string",
      "format": "date-time",
      "title": "Window Start"
    },
    "window_end": {
      "type": "string",
      "format": "date-time",
      "title": "Window End"
    }
  },
  "additionalProperties": false,
  "type": "object",
  "required": [
    "media_id",
    "window_start",
    "window_end"
  ],
  "title": "ScoreRequest"
}
```

<a id="schema-ScoreResponse"></a>

## ScoreResponse

| Campo | Obrigatório | Tipo | Default / limites |
| --- | --- | --- | --- |
| `id` | sim | string | — |
| `creator_user_id` | sim | string | — |
| `media_id` | sim | string | — |
| `program_id` | sim | string | — |
| `rule_version` | sim | string | — |
| `window_start` | sim | string (date-time) | — |
| `window_end` | sim | string (date-time) | — |
| `score_basis_points` | sim | integer | — |
| `calculation_snapshot` | sim | object | additionalProperties=true |
| `created_at` | sim | string (date-time) | — |

Schema exato:
```json
{
  "properties": {
    "id": {
      "type": "string",
      "title": "Id"
    },
    "creator_user_id": {
      "type": "string",
      "title": "Creator User Id"
    },
    "media_id": {
      "type": "string",
      "title": "Media Id"
    },
    "program_id": {
      "type": "string",
      "title": "Program Id"
    },
    "rule_version": {
      "type": "string",
      "title": "Rule Version"
    },
    "window_start": {
      "type": "string",
      "format": "date-time",
      "title": "Window Start"
    },
    "window_end": {
      "type": "string",
      "format": "date-time",
      "title": "Window End"
    },
    "score_basis_points": {
      "type": "integer",
      "title": "Score Basis Points"
    },
    "calculation_snapshot": {
      "additionalProperties": true,
      "type": "object",
      "title": "Calculation Snapshot"
    },
    "created_at": {
      "type": "string",
      "format": "date-time",
      "title": "Created At"
    }
  },
  "type": "object",
  "required": [
    "id",
    "creator_user_id",
    "media_id",
    "program_id",
    "rule_version",
    "window_start",
    "window_end",
    "score_basis_points",
    "calculation_snapshot",
    "created_at"
  ],
  "title": "ScoreResponse"
}
```

<a id="schema-Search"></a>

## Search

| Campo | Obrigatório | Tipo | Default / limites |
| --- | --- | --- | --- |
| `query` | sim | string | minLength=2; maxLength=100 |

Schema exato:
```json
{
  "properties": {
    "query": {
      "type": "string",
      "maxLength": 100,
      "minLength": 2,
      "title": "Query"
    }
  },
  "additionalProperties": false,
  "type": "object",
  "required": [
    "query"
  ],
  "title": "Search"
}
```

<a id="schema-SessionCreate"></a>

## SessionCreate

| Campo | Obrigatório | Tipo | Default / limites |
| --- | --- | --- | --- |
| `starts_at` | sim | string (date-time) | — |
| `ends_at` | sim | string (date-time) | — |

Schema exato:
```json
{
  "properties": {
    "starts_at": {
      "type": "string",
      "format": "date-time",
      "title": "Starts At"
    },
    "ends_at": {
      "type": "string",
      "format": "date-time",
      "title": "Ends At"
    }
  },
  "additionalProperties": false,
  "type": "object",
  "required": [
    "starts_at",
    "ends_at"
  ],
  "title": "SessionCreate"
}
```

<a id="schema-SessionPage"></a>

## SessionPage

| Campo | Obrigatório | Tipo | Default / limites |
| --- | --- | --- | --- |
| `sessions` | sim | array de [SessionView](SCHEMAS.md#schema-SessionView) | — |
| `total` | sim | integer | — |
| `limit` | sim | integer | — |
| `offset` | sim | integer | — |

Schema exato:
```json
{
  "properties": {
    "sessions": {
      "items": {
        "$ref": "#/components/schemas/SessionView"
      },
      "type": "array",
      "title": "Sessions"
    },
    "total": {
      "type": "integer",
      "title": "Total"
    },
    "limit": {
      "type": "integer",
      "title": "Limit"
    },
    "offset": {
      "type": "integer",
      "title": "Offset"
    }
  },
  "type": "object",
  "required": [
    "sessions",
    "total",
    "limit",
    "offset"
  ],
  "title": "SessionPage"
}
```

<a id="schema-SessionResponse"></a>

## SessionResponse

| Campo | Obrigatório | Tipo | Default / limites |
| --- | --- | --- | --- |
| `id` | sim | string | — |
| `class_id` | sim | string | — |
| `starts_at` | sim | string (date-time) | — |
| `ends_at` | sim | string (date-time) | — |
| `status` | sim | string | — |
| `token_expires_at` | sim | string (date-time) | — |
| `token_version` | sim | integer | — |
| `checkin_token` | não | string / null | — |
| `checkin_code` | não | string / null | — |

Schema exato:
```json
{
  "properties": {
    "id": {
      "type": "string",
      "title": "Id"
    },
    "class_id": {
      "type": "string",
      "title": "Class Id"
    },
    "starts_at": {
      "type": "string",
      "format": "date-time",
      "title": "Starts At"
    },
    "ends_at": {
      "type": "string",
      "format": "date-time",
      "title": "Ends At"
    },
    "status": {
      "type": "string",
      "title": "Status"
    },
    "token_expires_at": {
      "type": "string",
      "format": "date-time",
      "title": "Token Expires At"
    },
    "token_version": {
      "type": "integer",
      "title": "Token Version"
    },
    "checkin_token": {
      "anyOf": [
        {
          "type": "string"
        },
        {
          "type": "null"
        }
      ],
      "title": "Checkin Token"
    },
    "checkin_code": {
      "anyOf": [
        {
          "type": "string"
        },
        {
          "type": "null"
        }
      ],
      "title": "Checkin Code"
    }
  },
  "type": "object",
  "required": [
    "id",
    "class_id",
    "starts_at",
    "ends_at",
    "status",
    "token_expires_at",
    "token_version"
  ],
  "title": "SessionResponse"
}
```

<a id="schema-SessionView"></a>

## SessionView

| Campo | Obrigatório | Tipo | Default / limites |
| --- | --- | --- | --- |
| `id` | sim | string | — |
| `class_id` | sim | string | — |
| `starts_at` | sim | string (date-time) | — |
| `ends_at` | sim | string (date-time) | — |
| `status` | sim | enum ["open", "closed"] | — |
| `token_expires_at` | sim | string (date-time) | — |
| `token_version` | sim | integer | — |

Schema exato:
```json
{
  "properties": {
    "id": {
      "type": "string",
      "title": "Id"
    },
    "class_id": {
      "type": "string",
      "title": "Class Id"
    },
    "starts_at": {
      "type": "string",
      "format": "date-time",
      "title": "Starts At"
    },
    "ends_at": {
      "type": "string",
      "format": "date-time",
      "title": "Ends At"
    },
    "status": {
      "type": "string",
      "enum": [
        "open",
        "closed"
      ],
      "title": "Status"
    },
    "token_expires_at": {
      "type": "string",
      "format": "date-time",
      "title": "Token Expires At"
    },
    "token_version": {
      "type": "integer",
      "title": "Token Version"
    }
  },
  "type": "object",
  "required": [
    "id",
    "class_id",
    "starts_at",
    "ends_at",
    "status",
    "token_expires_at",
    "token_version"
  ],
  "title": "SessionView"
}
```

<a id="schema-StudentAlert"></a>

## StudentAlert

| Campo | Obrigatório | Tipo | Default / limites |
| --- | --- | --- | --- |
| `code` | sim | enum ["inactive_7_days", "required_activity_pending", "below_expected_hours"] | — |

Schema exato:
```json
{
  "properties": {
    "code": {
      "type": "string",
      "enum": [
        "inactive_7_days",
        "required_activity_pending",
        "below_expected_hours"
      ],
      "title": "Code"
    }
  },
  "type": "object",
  "required": [
    "code"
  ],
  "title": "StudentAlert"
}
```

<a id="schema-StudentProgress"></a>

## StudentProgress

| Campo | Obrigatório | Tipo | Default / limites |
| --- | --- | --- | --- |
| `user_id` | sim | string | — |
| `name` | sim | string | — |
| `enrollment_id` | sim | string | — |
| `context_enrollment_id` | não | string / null | — |
| `status` | sim | string | — |
| `planned_hours` | sim | number | — |
| `validated_hours` | sim | number | — |
| `progress_percent` | sim | number | — |
| `last_activity_at` | sim | string (date-time) / null | — |
| `inactive_days` | sim | integer | — |
| `alerts` | sim | array de [StudentAlert](SCHEMAS.md#schema-StudentAlert) | — |
| `baseline_linked` | não | boolean | default=false |
| `confirmed_sessions` | não | integer | default=0 |
| `open_mentorship_cases` | não | integer | default=0 |

Schema exato:
```json
{
  "properties": {
    "user_id": {
      "type": "string",
      "title": "User Id"
    },
    "name": {
      "type": "string",
      "title": "Name"
    },
    "enrollment_id": {
      "type": "string",
      "title": "Enrollment Id"
    },
    "context_enrollment_id": {
      "anyOf": [
        {
          "type": "string"
        },
        {
          "type": "null"
        }
      ],
      "title": "Context Enrollment Id"
    },
    "status": {
      "type": "string",
      "title": "Status"
    },
    "planned_hours": {
      "type": "number",
      "title": "Planned Hours"
    },
    "validated_hours": {
      "type": "number",
      "title": "Validated Hours"
    },
    "progress_percent": {
      "type": "number",
      "title": "Progress Percent"
    },
    "last_activity_at": {
      "anyOf": [
        {
          "type": "string",
          "format": "date-time"
        },
        {
          "type": "null"
        }
      ],
      "title": "Last Activity At"
    },
    "inactive_days": {
      "type": "integer",
      "title": "Inactive Days"
    },
    "alerts": {
      "items": {
        "$ref": "#/components/schemas/StudentAlert"
      },
      "type": "array",
      "title": "Alerts"
    },
    "baseline_linked": {
      "type": "boolean",
      "title": "Baseline Linked",
      "default": false
    },
    "confirmed_sessions": {
      "type": "integer",
      "title": "Confirmed Sessions",
      "default": 0
    },
    "open_mentorship_cases": {
      "type": "integer",
      "title": "Open Mentorship Cases",
      "default": 0
    }
  },
  "type": "object",
  "required": [
    "user_id",
    "name",
    "enrollment_id",
    "status",
    "planned_hours",
    "validated_hours",
    "progress_percent",
    "last_activity_at",
    "inactive_days",
    "alerts"
  ],
  "title": "StudentProgress"
}
```

<a id="schema-SyncQueueStatus"></a>

## SyncQueueStatus

| Campo | Obrigatório | Tipo | Default / limites |
| --- | --- | --- | --- |
| `pending` | sim | integer | — |
| `processing` | sim | integer | — |
| `synced` | sim | integer | — |
| `failed` | sim | integer | — |
| `exhausted` | sim | integer | — |
| `last_success_at` | sim | string (date-time) / null | — |
| `last_failure_at` | sim | string (date-time) / null | — |

Schema exato:
```json
{
  "properties": {
    "pending": {
      "type": "integer",
      "title": "Pending"
    },
    "processing": {
      "type": "integer",
      "title": "Processing"
    },
    "synced": {
      "type": "integer",
      "title": "Synced"
    },
    "failed": {
      "type": "integer",
      "title": "Failed"
    },
    "exhausted": {
      "type": "integer",
      "title": "Exhausted"
    },
    "last_success_at": {
      "anyOf": [
        {
          "type": "string",
          "format": "date-time"
        },
        {
          "type": "null"
        }
      ],
      "title": "Last Success At"
    },
    "last_failure_at": {
      "anyOf": [
        {
          "type": "string",
          "format": "date-time"
        },
        {
          "type": "null"
        }
      ],
      "title": "Last Failure At"
    }
  },
  "type": "object",
  "required": [
    "pending",
    "processing",
    "synced",
    "failed",
    "exhausted",
    "last_success_at",
    "last_failure_at"
  ],
  "title": "SyncQueueStatus"
}
```

<a id="schema-TeamClassCommand"></a>

## TeamClassCommand

| Campo | Obrigatório | Tipo | Default / limites |
| --- | --- | --- | --- |
| `id` | sim | string | minLength=16; maxLength=180 |
| `reason` | sim | string | minLength=3; maxLength=500 |
| `institution_id` | sim | string | minLength=1; maxLength=36 |
| `program_id` | sim | string | minLength=1; maxLength=36 |
| `course_id` | sim | string | minLength=1; maxLength=120 |
| `version_id` | sim | string | minLength=1; maxLength=36 |
| `expected_revision` | sim | integer | minimum=0.0 |
| `teacher_id` | sim | string | minLength=1; maxLength=36 |
| `monitor_ids` | não | array de string | — |

Schema exato:
```json
{
  "properties": {
    "id": {
      "type": "string",
      "maxLength": 180,
      "minLength": 16,
      "title": "Id"
    },
    "reason": {
      "type": "string",
      "maxLength": 500,
      "minLength": 3,
      "title": "Reason"
    },
    "institution_id": {
      "type": "string",
      "maxLength": 36,
      "minLength": 1,
      "title": "Institution Id"
    },
    "program_id": {
      "type": "string",
      "maxLength": 36,
      "minLength": 1,
      "title": "Program Id"
    },
    "course_id": {
      "type": "string",
      "maxLength": 120,
      "minLength": 1,
      "title": "Course Id"
    },
    "version_id": {
      "type": "string",
      "maxLength": 36,
      "minLength": 1,
      "title": "Version Id"
    },
    "expected_revision": {
      "type": "integer",
      "minimum": 0.0,
      "title": "Expected Revision"
    },
    "teacher_id": {
      "type": "string",
      "maxLength": 36,
      "minLength": 1,
      "title": "Teacher Id"
    },
    "monitor_ids": {
      "items": {
        "type": "string"
      },
      "type": "array",
      "title": "Monitor Ids"
    }
  },
  "additionalProperties": false,
  "type": "object",
  "required": [
    "id",
    "reason",
    "institution_id",
    "program_id",
    "course_id",
    "version_id",
    "expected_revision",
    "teacher_id"
  ],
  "title": "TeamClassCommand"
}
```

<a id="schema-TokenResponse"></a>

## TokenResponse

| Campo | Obrigatório | Tipo | Default / limites |
| --- | --- | --- | --- |
| `access_token` | sim | string | — |
| `refresh_token` | sim | string | — |
| `token_type` | não | string | default="bearer" |
| `expires_in` | sim | integer | — |
| `user` | sim | [PublicUser](SCHEMAS.md#schema-PublicUser) | — |

Schema exato:
```json
{
  "properties": {
    "access_token": {
      "type": "string",
      "title": "Access Token"
    },
    "refresh_token": {
      "type": "string",
      "title": "Refresh Token"
    },
    "token_type": {
      "type": "string",
      "title": "Token Type",
      "default": "bearer"
    },
    "expires_in": {
      "type": "integer",
      "title": "Expires In"
    },
    "user": {
      "$ref": "#/components/schemas/PublicUser"
    }
  },
  "type": "object",
  "required": [
    "access_token",
    "refresh_token",
    "expires_in",
    "user"
  ],
  "title": "TokenResponse"
}
```

<a id="schema-TransitionClassCommand"></a>

## TransitionClassCommand

| Campo | Obrigatório | Tipo | Default / limites |
| --- | --- | --- | --- |
| `id` | sim | string | minLength=16; maxLength=180 |
| `reason` | sim | string | minLength=3; maxLength=500 |
| `institution_id` | sim | string | minLength=1; maxLength=36 |
| `program_id` | sim | string | minLength=1; maxLength=36 |
| `course_id` | sim | string | minLength=1; maxLength=120 |
| `version_id` | sim | string | minLength=1; maxLength=36 |
| `expected_revision` | sim | integer | minimum=0.0 |
| `target_status` | sim | enum ["active", "closed"] | — |

Schema exato:
```json
{
  "properties": {
    "id": {
      "type": "string",
      "maxLength": 180,
      "minLength": 16,
      "title": "Id"
    },
    "reason": {
      "type": "string",
      "maxLength": 500,
      "minLength": 3,
      "title": "Reason"
    },
    "institution_id": {
      "type": "string",
      "maxLength": 36,
      "minLength": 1,
      "title": "Institution Id"
    },
    "program_id": {
      "type": "string",
      "maxLength": 36,
      "minLength": 1,
      "title": "Program Id"
    },
    "course_id": {
      "type": "string",
      "maxLength": 120,
      "minLength": 1,
      "title": "Course Id"
    },
    "version_id": {
      "type": "string",
      "maxLength": 36,
      "minLength": 1,
      "title": "Version Id"
    },
    "expected_revision": {
      "type": "integer",
      "minimum": 0.0,
      "title": "Expected Revision"
    },
    "target_status": {
      "type": "string",
      "enum": [
        "active",
        "closed"
      ],
      "title": "Target Status"
    }
  },
  "additionalProperties": false,
  "type": "object",
  "required": [
    "id",
    "reason",
    "institution_id",
    "program_id",
    "course_id",
    "version_id",
    "expected_revision",
    "target_status"
  ],
  "title": "TransitionClassCommand"
}
```

<a id="schema-UsageCount"></a>

## UsageCount

| Campo | Obrigatório | Tipo | Default / limites |
| --- | --- | --- | --- |
| `course_id` | sim | string | — |
| `event_type` | sim | enum ["page_viewed", "resource_opened", "feature_used"] | — |
| `target_id` | sim | string | — |
| `count` | sim | integer | — |
| `unique_users` | sim | integer | — |
| `last_occurred_at` | sim | string (date-time) | — |

Schema exato:
```json
{
  "properties": {
    "course_id": {
      "type": "string",
      "title": "Course Id"
    },
    "event_type": {
      "type": "string",
      "enum": [
        "page_viewed",
        "resource_opened",
        "feature_used"
      ],
      "title": "Event Type"
    },
    "target_id": {
      "type": "string",
      "title": "Target Id"
    },
    "count": {
      "type": "integer",
      "title": "Count"
    },
    "unique_users": {
      "type": "integer",
      "title": "Unique Users"
    },
    "last_occurred_at": {
      "type": "string",
      "format": "date-time",
      "title": "Last Occurred At"
    }
  },
  "type": "object",
  "required": [
    "course_id",
    "event_type",
    "target_id",
    "count",
    "unique_users",
    "last_occurred_at"
  ],
  "title": "UsageCount"
}
```

<a id="schema-UsageSummary"></a>

## UsageSummary

| Campo | Obrigatório | Tipo | Default / limites |
| --- | --- | --- | --- |
| `period_start` | sim | string (date-time) | — |
| `period_end` | sim | string (date-time) | — |
| `items` | sim | array de [UsageCount](SCHEMAS.md#schema-UsageCount) | — |

Schema exato:
```json
{
  "properties": {
    "period_start": {
      "type": "string",
      "format": "date-time",
      "title": "Period Start"
    },
    "period_end": {
      "type": "string",
      "format": "date-time",
      "title": "Period End"
    },
    "items": {
      "items": {
        "$ref": "#/components/schemas/UsageCount"
      },
      "type": "array",
      "title": "Items"
    }
  },
  "type": "object",
  "required": [
    "period_start",
    "period_end",
    "items"
  ],
  "title": "UsageSummary"
}
```

<a id="schema-ValidationError"></a>

## ValidationError

| Campo | Obrigatório | Tipo | Default / limites |
| --- | --- | --- | --- |
| `loc` | sim | array de string / integer | — |
| `msg` | sim | string | — |
| `type` | sim | string | — |
| `input` | não | qualquer JSON | — |
| `ctx` | não | object | — |

Schema exato:
```json
{
  "properties": {
    "loc": {
      "items": {
        "anyOf": [
          {
            "type": "string"
          },
          {
            "type": "integer"
          }
        ]
      },
      "type": "array",
      "title": "Location"
    },
    "msg": {
      "type": "string",
      "title": "Message"
    },
    "type": {
      "type": "string",
      "title": "Error Type"
    },
    "input": {
      "title": "Input"
    },
    "ctx": {
      "type": "object",
      "title": "Context"
    }
  },
  "type": "object",
  "required": [
    "loc",
    "msg",
    "type"
  ],
  "title": "ValidationError"
}
```

<a id="schema-VersionAction"></a>

## VersionAction

| Campo | Obrigatório | Tipo | Default / limites |
| --- | --- | --- | --- |
| `version_id` | sim | string | minLength=1; maxLength=36 |
| `expected_revision` | sim | integer | minimum=1.0 |

Schema exato:
```json
{
  "properties": {
    "version_id": {
      "type": "string",
      "maxLength": 36,
      "minLength": 1,
      "title": "Version Id"
    },
    "expected_revision": {
      "type": "integer",
      "minimum": 1.0,
      "title": "Expected Revision"
    }
  },
  "additionalProperties": false,
  "type": "object",
  "required": [
    "version_id",
    "expected_revision"
  ],
  "title": "VersionAction"
}
```

<a id="schema-VersionFork"></a>

## VersionFork

| Campo | Obrigatório | Tipo | Default / limites |
| --- | --- | --- | --- |
| `source_version_id` | sim | string | minLength=1; maxLength=36 |

Schema exato:
```json
{
  "properties": {
    "source_version_id": {
      "type": "string",
      "maxLength": 36,
      "minLength": 1,
      "title": "Source Version Id"
    }
  },
  "additionalProperties": false,
  "type": "object",
  "required": [
    "source_version_id"
  ],
  "title": "VersionFork"
}
```

<a id="schema-WorkloadUpdate"></a>

## WorkloadUpdate

| Campo | Obrigatório | Tipo | Default / limites |
| --- | --- | --- | --- |
| `planned_hours` | sim | number | maximum=10000.0; exclusiveMinimum=0.0 |

Schema exato:
```json
{
  "properties": {
    "planned_hours": {
      "type": "number",
      "maximum": 10000.0,
      "exclusiveMinimum": 0.0,
      "title": "Planned Hours"
    }
  },
  "additionalProperties": false,
  "type": "object",
  "required": [
    "planned_hours"
  ],
  "title": "WorkloadUpdate"
}
```

<a id="schema-app__certificate_requests__ReviewCreate"></a>

## app__certificate_requests__ReviewCreate

| Campo | Obrigatório | Tipo | Default / limites |
| --- | --- | --- | --- |
| `expected_revision` | sim | integer | minimum=1.0 |
| `decision` | sim | enum ["approve", "reject"] | — |
| `reason` | sim | string | minLength=3; maxLength=500 |

Schema exato:
```json
{
  "properties": {
    "expected_revision": {
      "type": "integer",
      "minimum": 1.0,
      "title": "Expected Revision"
    },
    "decision": {
      "type": "string",
      "enum": [
        "approve",
        "reject"
      ],
      "title": "Decision"
    },
    "reason": {
      "type": "string",
      "maxLength": 500,
      "minLength": 3,
      "title": "Reason"
    }
  },
  "additionalProperties": false,
  "type": "object",
  "required": [
    "expected_revision",
    "decision",
    "reason"
  ],
  "title": "ReviewCreate"
}
```

<a id="schema-app__evidence__ReviewCreate"></a>

## app__evidence__ReviewCreate

| Campo | Obrigatório | Tipo | Default / limites |
| --- | --- | --- | --- |
| `decision` | sim | enum ["accepted", "rejected"] | — |
| `reason_code` | sim | enum ["verified", "unrelated", "insufficient", "duplicate", "corrected"] | — |

Schema exato:
```json
{
  "properties": {
    "decision": {
      "type": "string",
      "enum": [
        "accepted",
        "rejected"
      ],
      "title": "Decision"
    },
    "reason_code": {
      "type": "string",
      "enum": [
        "verified",
        "unrelated",
        "insufficient",
        "duplicate",
        "corrected"
      ],
      "title": "Reason Code"
    }
  },
  "additionalProperties": false,
  "type": "object",
  "required": [
    "decision",
    "reason_code"
  ],
  "title": "ReviewCreate"
}
```
