import assert from "node:assert/strict";
import test from "node:test";
import {
  agenticosEndAttributes,
  agenticosStartAttributes,
  classifySqlError,
} from "./agenticos-attributes.ts";

const OBJECTIVE = "urn:uuid:123e4567-e89b-42d3-a456-426614174000";
const RECORD = "urn:uuid:123e4567-e89b-42d3-a456-426614174001";

test("start attributes are scoped to agenticOS and exclude SQL text", () => {
  assert.deepEqual(agenticosStartAttributes("read", { limit: 10 }), {});

  const attributes = agenticosStartAttributes("agenticos_query_graph_sql", {
    sql: "SELECT secret FROM objectives",
    scope: "instance",
    limit: 25,
  });
  assert.deepEqual(attributes, {
    "agenticos.tool_name": "agenticos_query_graph_sql",
    "agenticos.mutation": false,
    "agenticos.sql_scope": "instance",
    "agenticos.sql_limit": 25,
  });
  assert.equal(Object.values(attributes).includes("SELECT secret FROM objectives"), false);
});

test("SQL success attributes use structured result details", () => {
  const attributes = agenticosEndAttributes(
    "agenticos_query_graph_sql",
    {},
    {
      details: {
        columns: ["resource", "work_status"],
        rows: [{ resource: OBJECTIVE }],
        truncated: true,
      },
    },
    false,
  );

  assert.deepEqual(attributes, {
    "agenticos.is_error": false,
    "agenticos.sql_row_count": 1,
    "agenticos.sql_column_count": 2,
    "agenticos.sql_truncated": true,
  });
});

test("SQL errors expose only a stable code and bounded category", () => {
  const attributes = agenticosEndAttributes(
    "agenticos_query_graph_sql",
    { sql: "SELECT private_identifier FROM private_table" },
    {
      isError: true,
      details: {
        code: "AOS_INPUT",
        message: "Binder Error: Referenced column private_identifier not found in FROM clause",
      },
    },
    false,
  );

  assert.deepEqual(attributes, {
    "agenticos.is_error": true,
    "agenticos.error_code": "AOS_INPUT",
    "agenticos.sql_error_class": "unknown_column",
  });
  assert.equal(JSON.stringify(attributes).includes("private_identifier"), false);
});

test("SQL error classification covers safe categories", () => {
  assert.equal(classifySqlError("Catalog Error: Table with name missing does not exist"), "unknown_relation");
  assert.equal(classifySqlError("Parser Error: syntax error at or near FROM"), "syntax");
  assert.equal(classifySqlError("sql must begin with SELECT or WITH"), "read_only_rejected");
  assert.equal(classifySqlError("External access is disabled"), "external_access_rejected");
  assert.equal(classifySqlError("DuckDB could not execute sql: internal failure"), "other");
  assert.equal(classifySqlError(undefined), undefined);
});

test("mutation attributes come only from structured metadata", () => {
  const attributes = agenticosEndAttributes(
    "agenticos_update_work_status",
    { resource: RECORD, work_status: "completed" },
    {
      details: {
        record: { resource: RECORD, type: "objective", work_status: "completed" },
        validation: { pass: true },
        affected: [{ resource: RECORD }],
        assessment: { kind: "no_action", rationale: "not exported" },
      },
    },
    false,
  );

  assert.deepEqual(attributes, {
    "agenticos.is_error": false,
    "agenticos.record_resource": RECORD,
    "agenticos.record_type": "objective",
    "agenticos.work_status": "completed",
    "agenticos.validation_pass": true,
    "agenticos.affected_count": 1,
    "agenticos.assessment_kind": "no_action",
  });
});

test("attach and context attributes count omitted records", () => {
  assert.deepEqual(agenticosStartAttributes("agenticos_attach_objective", {
    objective_resource: OBJECTIVE,
  }), {
    "agenticos.tool_name": "agenticos_attach_objective",
    "agenticos.mutation": true,
    "agenticos.objective_resource": OBJECTIVE,
  });

  const attributes = agenticosEndAttributes(
    "agenticos_get_objective_context",
    { objective_resource: OBJECTIVE },
    {
      details: {
        truncated: true,
        omitted: { knowledge: [RECORD], artifacts: [], parents: [OBJECTIVE, RECORD] },
      },
    },
    false,
  );
  assert.deepEqual(attributes, {
    "agenticos.is_error": false,
    "agenticos.objective_resource": OBJECTIVE,
    "agenticos.context_truncated": true,
    "agenticos.context_omitted_count": 3,
  });
});

test("malformed and string-only results remain safe", () => {
  assert.deepEqual(
    agenticosEndAttributes("agenticos_query_graph_sql", {}, "AOS_INPUT: secret", true),
    { "agenticos.is_error": true },
  );

  const attributes = agenticosEndAttributes(
    "agenticos_create_goal",
    {},
    {
      isError: true,
      details: {
        code: "AOS_INPUT-secret",
        record: { resource: "not-a-resource", type: "secret payload" },
        affected: Number.MAX_SAFE_INTEGER,
      },
    },
    false,
  );
  assert.deepEqual(attributes, { "agenticos.is_error": true });
});
