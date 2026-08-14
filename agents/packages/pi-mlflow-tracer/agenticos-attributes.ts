type SpanAttributeValue = string | boolean | number;
export type SpanAttributes = Record<string, SpanAttributeValue>;

const AGENTICOS_PREFIX = "agenticos_";
const MAX_COUNT = 1_000_000;
const MAX_TOOL_NAME_LENGTH = 128;
const MAX_CATEGORY_LENGTH = 64;
const AOS_ERROR_CODE = /^AOS_[A-Z0-9_]{1,60}$/;
const RESOURCE = /^urn:uuid:[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const CATEGORY = /^[a-z][a-z0-9_]{0,63}$/;

function record(value: unknown): Record<string, unknown> | undefined {
  return value !== null && typeof value === "object" && !Array.isArray(value)
    ? value as Record<string, unknown>
    : undefined;
}

function boundedString(value: unknown, maxLength: number): string | undefined {
  return typeof value === "string" && value.length > 0 && value.length <= maxLength
    ? value
    : undefined;
}

function boundedCount(value: unknown, maximum = MAX_COUNT): number | undefined {
  return typeof value === "number"
    && Number.isSafeInteger(value)
    && value >= 0
    && value <= maximum
    ? value
    : undefined;
}

function arrayCount(value: unknown): number | undefined {
  return Array.isArray(value) ? Math.min(value.length, MAX_COUNT) : boundedCount(value);
}

function resultDetails(result: unknown): Record<string, unknown> | undefined {
  return record(record(result)?.details);
}

function mutationTool(toolName: string): boolean {
  return /^agenticos_(?:create|update|capture|attach|detach|status|link)(?:_|$)/.test(toolName);
}

function omittedCount(value: unknown): number | undefined {
  const direct = boundedCount(value);
  if (direct !== undefined) return direct;

  const groups = record(value);
  if (!groups) return undefined;

  let total = 0;
  let found = false;
  for (const key of ["knowledge", "artifacts", "parents"]) {
    const count = arrayCount(groups[key]);
    if (count === undefined) continue;
    found = true;
    total = Math.min(MAX_COUNT, total + count);
  }
  return found ? total : undefined;
}

function setCategory(attributes: SpanAttributes, key: string, value: unknown): void {
  const bounded = boundedString(value, MAX_CATEGORY_LENGTH);
  if (bounded !== undefined && CATEGORY.test(bounded)) attributes[key] = bounded;
}

function setResource(attributes: SpanAttributes, key: string, value: unknown): void {
  const bounded = boundedString(value, 64);
  if (bounded !== undefined && RESOURCE.test(bounded)) attributes[key] = bounded;
}

/** Classify a structured SQL error without exposing its message or identifiers. */
export function classifySqlError(message: unknown): string | undefined {
  if (typeof message !== "string" || message.length === 0) return undefined;
  const normalized = message.slice(0, 4096).toLowerCase();

  if (/referenced column|unknown column|column(?: name)? .* (?:does not exist|not found)|binder error.*column/.test(normalized)) {
    return "unknown_column";
  }
  if (/unknown relation|table(?: with name)? .* (?:does not exist|not found)|catalog error.*table/.test(normalized)) {
    return "unknown_relation";
  }
  if (/parser error|parse error|syntax error/.test(normalized)) return "syntax";
  if (/external access|external_access|external file|filesystem access|network access/.test(normalized)) {
    return "external_access_rejected";
  }
  if (
    /read.only|must begin with select or with|exactly one statement|without a semicolon|operation or function .* not available to graph queries/.test(normalized)
  ) {
    return "read_only_rejected";
  }
  return "other";
}

/** Attributes known before an agenticOS tool executes. */
export function agenticosStartAttributes(toolName: string, args: unknown): SpanAttributes {
  if (!toolName.startsWith(AGENTICOS_PREFIX)) return {};

  try {
    const attributes: SpanAttributes = {
      "agenticos.mutation": mutationTool(toolName),
    };
    const boundedToolName = boundedString(toolName, MAX_TOOL_NAME_LENGTH);
    if (boundedToolName) attributes["agenticos.tool_name"] = boundedToolName;
    const input = record(args);

    if (toolName === "agenticos_query_graph_sql" && input) {
      if (input.scope === "default" || input.scope === "instance") {
        attributes["agenticos.sql_scope"] = input.scope;
      }
      const limit = boundedCount(input.limit, 1000);
      if (limit !== undefined && limit >= 1) attributes["agenticos.sql_limit"] = limit;
    }

    if (/^agenticos_(?:attach|detach|get_objective_context)(?:_|$)/.test(toolName)) {
      setResource(attributes, "agenticos.objective_resource", input?.objective_resource);
    }

    return attributes;
  } catch {
    return {};
  }
}

/** Attributes available after an agenticOS tool returns. */
export function agenticosEndAttributes(
  toolName: string,
  args: unknown,
  result: unknown,
  eventIsError: boolean,
): SpanAttributes {
  if (!toolName.startsWith(AGENTICOS_PREFIX)) return {};

  try {
    const resultObject = record(result);
    const details = resultDetails(result);
    const isError = eventIsError || resultObject?.isError === true;
    const attributes: SpanAttributes = { "agenticos.is_error": isError };

    const errorCode = boundedString(details?.code, MAX_CATEGORY_LENGTH);
    if (errorCode && AOS_ERROR_CODE.test(errorCode)) attributes["agenticos.error_code"] = errorCode;

    if (toolName === "agenticos_query_graph_sql") {
      const rows = arrayCount(details?.rows);
      const columns = arrayCount(details?.columns);
      if (rows !== undefined) attributes["agenticos.sql_row_count"] = rows;
      if (columns !== undefined) attributes["agenticos.sql_column_count"] = columns;
      if (typeof details?.truncated === "boolean") attributes["agenticos.sql_truncated"] = details.truncated;
      if (isError) {
        const errorClass = classifySqlError(details?.message);
        if (errorClass) attributes["agenticos.sql_error_class"] = errorClass;
      }
    }

    if (mutationTool(toolName) && details) {
      const recordResult = record(details.record);
      setResource(attributes, "agenticos.record_resource", recordResult?.resource);
      setCategory(attributes, "agenticos.record_type", recordResult?.type);
      setCategory(attributes, "agenticos.work_status", recordResult?.work_status);

      const validation = record(details.validation);
      if (typeof validation?.pass === "boolean") attributes["agenticos.validation_pass"] = validation.pass;

      const affected = arrayCount(details.affected);
      if (affected !== undefined) attributes["agenticos.affected_count"] = affected;

      const assessment = record(details.assessment);
      setCategory(attributes, "agenticos.assessment_kind", assessment?.kind);
    }

    if (/^agenticos_(?:attach|detach|get_objective_context)(?:_|$)/.test(toolName)) {
      const input = record(args);
      setResource(
        attributes,
        "agenticos.objective_resource",
        details?.objective_resource ?? input?.objective_resource,
      );
      if (typeof details?.truncated === "boolean") {
        attributes["agenticos.context_truncated"] = details.truncated;
      }
      const omitted = omittedCount(details?.omitted);
      if (omitted !== undefined) attributes["agenticos.context_omitted_count"] = omitted;
    }

    return attributes;
  } catch {
    return { "agenticos.is_error": Boolean(eventIsError) };
  }
}
