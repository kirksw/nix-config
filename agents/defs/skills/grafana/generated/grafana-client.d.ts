// Generated on 2026-08-10T19:33:04.687Z by mcporter@0.13.3
// Server: grafana
// Source: /Users/kisw/.config/nix-agents/pi/bases/work/settings/mcporter.json
// Transport: HTTP https://mcp-grafana.lunar.tech/mcp

import type { CallResult } from 'mcporter';

export interface GrafanaTools {
  /**
   * Manage Grafana alerting routing configuration, including notification policies, contact points and
   * time intervals.
   * Notification policies define how alerts are grouped, routed, and which contact points receive them.
   * Time intervals define active/mute periods for alert notifications.
   * When to use:
   * - Understanding how alerts are routed to contact points/receivers
   * - Debugging why an alert went to a specific receiver
   * - Checking grouping, timing, or mute interval settings
   * When NOT to use:
   * - Checking alert rule configuration or state (use alerting_manage_rules)
   *
   * @param contact_point_title? Title of the contact point to retrieve (required for get_contact_point
   *                             operation)
   * @param datasource_uid? Optional: UID of an Alertmanager-compatible datasource to query for
   *                        receivers. If omitted, returns Grafana-managed contact points. Only used with
   *                        get_contact_points.
   * @param limit? The maximum number of results to return. Default is 100. Only used with
   *               get_contact_points.
   * @param name? Filter contact points by name (exact match). Only used with get_contact_points.
   * @param operation The operation to perform: 'get_notification_policies' to retrieve the notification
   *                  policy tree, 'get_contact_points' to list all contact points, 'get_contact_point'
   *                  to get a specific contact point by name, 'get_time_intervals' to list all time
   *                  intervals, 'get_time_interval' to get a specific time interval by name
   * @param time_interval_name? Name of the time interval to retrieve (required for get_time_interval
   *                            operation)
   */
  alerting_manage_routing(contact_point_title?: string, datasource_uid?: string, limit?: number, name?: string, operation: "get_notification_policies" | "get_contact_points" | "get_contact_point" | "get_time_intervals" | "get_time_interval"): Promise<CallResult>;
  // optional (1): time_interval_name

  /**
   * List and inspect Grafana alert rules with filtering capabilities.
   * When to use:
   * - Understanding why an alert is or isn't firing
   * - Auditing alert rule configuration (queries, conditions, labels, notification settings)
   * - Finding alert rules by state, folder, group, or name
   * - Comparing rule versions to see what changed
   * When NOT to use:
   * - Checking how alerts are routed to receivers (use alerting_manage_routing)
   * - Modifying or creating alert rules (read-only tool)
   *
   * @param datasource_uid? Optional: UID of a Prometheus or Loki datasource to query for
   *                        datasource-managed alert rules. If omitted, returns Grafana-managed rules.
   * @param folder_uid? Filter by exact folder UID (for 'list' operation). Mutually exclusive with
   *                    search_folder.
   * @param label_selectors? Prometheus-style selectors to filter alert rules by labels. Each string is a
   *                         selector e.g. '{severity="critical", team=~"backend.*"}'. All selectors must
   *                         match (AND).
   * @param limit_alerts? Limit alert instances per rule. For list: 0 omits alerts. For get: <=0 defaults
   *                      to 200. Max 200.
   * @param matchers? Label matchers to filter alert instances. Each string is a Prometheus-style matcher
   *                  e.g. 'severity="critical"', 'env!="dev"', 'team=~"backend.*"'. Requires Grafana
   *                  12.4+.
   * @param operation The operation to perform: 'list' to search/filter rules, 'get' to retrieve full
   *                  rule details (state + configuration) by UID, or 'versions' to get the version
   *                  history of a rule
   * @param rule_group? Filter by exact rule group name (for 'list' operation)
   * @param rule_limit? Maximum number of rules to return (default 200, max 200). Requires Grafana 12.4+
   *                    (for 'list' operation)
   * @param rule_type? Filter by rule type (for 'list' operation)
   * @param rule_uid? The UID of the alert rule (required for 'get' and 'versions' operations)
   * @param search_folder? Search folders by path using partial matching (for 'list' operation). Requires
   *                       Grafana 12.4+. Mutually exclusive with folder_uid.
   * @param search_rule_name? Search alert rule names/titles using partial matching. Requires Grafana
   *                          12.4+ (for 'list' operation)
   * @param states? Filter by alert state: firing, pending, normal, recovering, nodata, error (for 'list'
   *                operation)
   */
  alerting_manage_rules(datasource_uid?: string, folder_uid?: string, label_selectors?: string[], limit_alerts?: number, operation: "list" | "get" | "versions"): Promise<CallResult>;
  // optional (8): matchers, rule_group, rule_limit, rule_type, rule_uid, ...

  /**
   * Check datasource health. Filter by type or UIDs; omit both to check all.
   *
   * @param offset? Number to skip for pagination
   * @param type? Plugin type filter; omit to check all
   * @param uids? UIDs to check
   */
  check_datasources_health(offset?: number, type?: string, uids?: string[]): Promise<CallResult>;

  /**
   * Generate deeplink URLs for Grafana resources. Supports dashboards (requires dashboardUid or
   * provisioningPreview), panels (requires dashboardUid or provisioningPreview, plus panelId), and
   * Explore queries (requires datasourceUid and optionally queries). For dashboard and panel links,
   * provisioningPreview points at a dashboard staged on a provisioning repository branch (e.g. a
   * git-sync PR preview). In read-only mode, shorten=true is accepted but ignored and the full deeplink
   * is returned.
   *
   * @param dashboardUid? Dashboard UID (for stored dashboards). Mutually exclusive with
   *                      provisioningPreview for dashboard and panel types.
   * @param datasourceUid? Datasource UID (required for explore type)
   * @param panelId? Panel ID (required for panel type)
   * @param provisioningPreview? Identifies a dashboard staged on a provisioning repository branch (e.g.
   *                             a git-sync PR preview). Mutually exclusive with dashboardUid for
   *                             dashboard and panel types.
   * @param queries? List of query objects for explore links (e.g. [{"refId":"A","expr":"up"}])
   * @param queryParams? Additional URL query parameters (for dashboard/panel types)
   * @param resourceType Type of resource: dashboard, panel, or explore
   * @param shorten? If true, try to shorten the generated URL to /goto/<uid>. If shortening fails,
   *                 return the original deeplink.
   * @param timeRange? Time range for the link
   */
  generate_deeplink(dashboardUid?: string, datasourceUid?: string, panelId?: number, provisioningPreview?: Record<string, unknown>, resourceType: string): Promise<CallResult>;
  // optional (4): queries, queryParams, shorten, timeRange

  /**
   * Returns annotation tags with optional filtering by tag name. Only the provided filters are applied.
   *
   * @param limit? Max results, default 100
   * @param tag? Optional filter by tag name
   */
  get_annotation_tags(limit?: string, tag?: string): Promise<CallResult>;

  /**
   * Fetch Grafana annotations using filters such as dashboard UID, time range and tags.
   *
   * @param alertUid? Filter by alert UID
   * @param dashboardUid? Filter by dashboard UID
   * @param from? Epoch ms start time
   * @param limit? Max results default 100
   * @param matchAny? If true, match any tag (OR). If false, match all tags (AND). Default: false
   * @param panelId? Filter by panel ID
   * @param tags? Filter by tags. Multiple tags allowed; use matchAny to control AND/OR logic
   * @param to? Epoch ms end time
   * @param type? annotation or alert
   * @param userId? Filter by creator user ID
   */
  get_annotations(alertUid?: string, dashboardUid?: string, from?: number, limit?: number, matchAny?: boolean): Promise<CallResult>;
  // optional (5): panelId, tags, to, type, userId

  /**
   * Retrieves the complete dashboard, including panels, variables, and settings, for a specific
   * dashboard identified by its UID. The response includes 'apiVersion' and 'isV2': when 'isV2' is true
   * the dashboard uses the v2 schema (panels live under 'elements' keyed by name, arranged by 'layout';
   * variables under 'variables'), otherwise it is classic v1 ('panels[]' with 'templating.list').
   * WARNING: Large dashboards can consume significant context window space. Consider using
   * get_dashboard_summary for overview or get_dashboard_property for specific data instead.
   *
   * @param uid The UID of the dashboard
   */
  get_dashboard_by_uid(uid: string): Promise<CallResult>;

  /**
   * Retrieve panel queries from a Grafana dashboard. Supports all datasource types (Prometheus, Loki,
   * CloudWatch, SQL, etc.) and row-nested panels. Optionally filter to a specific panel by ID with
   * `panelId`. Optionally provide `variables` for template variable substitution, which populates
   * `processedQuery` and `requiredVariables` fields. Returns an array of objects with fields: title,
   * query (raw expression), datasource (object with uid and type), and optionally processedQuery, refId,
   * and requiredVariables.
   *
   * @param panelId? Optional panel ID to filter to a specific panel
   * @param uid The UID of the dashboard
   * @param variables? Optional variable substitutions (e.g., {"job": "api-server"})
   */
  get_dashboard_panel_queries(panelId?: number, uid: string, variables?: Record<string, unknown>): Promise<CallResult>;

  /**
   * Get specific parts of a dashboard using JSONPath expressions to minimize context window usage.
   * JSONPath targets the dashboard's native schema. Classic v1 paths: '$.title' (title)\,
   * '$.panels[*].title' (all panel titles)\, '$.panels[0]' (first panel)\, '$.templating.list'
   * (variables)\, '$.annotations.list' (saved dashboard annotation queries/definitions)\, '$.tags'
   * (tags)\, '$.panels[*].targets[*].expr' (all queries). v2 dashboards (see isV2 from
   * get_dashboard_by_uid) use different paths: '$.title'\, '$.elements' (panels\, keyed by name)\,
   * '$.variables' (variables)\, '$.annotations'. Use this instead of get_dashboard_by_uid when you only
   * need specific dashboard properties.
   *
   * @param jsonPath JSONPath expression to extract specific data (e.g., '$.panels[0].title' for first
   *                 panel title, '$.panels[*].title' for all panel titles, '$.templating.list' for
   *                 variables, '$.annotations.list' for saved dashboard annotation queries/definitions)
   * @param uid The UID of the dashboard
   */
  get_dashboard_property(jsonPath: string, uid: string): Promise<CallResult>;

  /**
   * Get a compact summary of a dashboard including title\, panel count\, panel types\, variables\, and
   * other metadata without the full JSON. Use this for dashboard overview and planning modifications
   * without consuming large context windows.
   *
   * @param uid The UID of the dashboard
   */
  get_dashboard_summary(uid: string): Promise<CallResult>;

  /**
   * Retrieves detailed information about a specific datasource by UID or name. Returns the full
   * datasource model, including name, type, URL, access settings, JSON data, and secure JSON field
   * status. Provide either uid or name; uid takes priority if both are given.
   *
   * @param name? The name of the datasource. Used if UID is not provided.
   * @param uid? The UID of the datasource. If provided, takes priority over name.
   */
  get_datasource(name?: string, uid?: string): Promise<CallResult>;

  /**
   * List all configured datasources in Grafana. Use this to discover available datasources and their
   * UIDs. Supports filtering by type and pagination.
   *
   * @param limit? Maximum number of datasources to return (max 100)
   * @param offset? Number of datasources to skip for pagination
   * @param type? The type of datasources to search for. For example, 'prometheus', 'loki', 'tempo',
   *              etc...
   */
  list_datasources(limit?: number, offset?: number, type?: string): Promise<CallResult>;

  /**
   * List label names in a PromQL-compatible datasource (Prometheus, Thanos, Mimir, Cloud Monitoring,
   * etc.). Allows filtering by series selectors and time range.
   *
   * @param datasourceUid The UID of the datasource to query
   * @param endRfc3339? Optionally, the end time of the time range to filter the results by. Supports
   *                    RFC3339 or relative time (e.g. 'now')
   * @param limit? Optionally, the maximum number of results to return
   * @param matches? Optionally, a list of label matchers to filter the results by
   * @param projectName? GCP project name to query (Cloud Monitoring datasources only). Overrides or
   *                     substitutes the defaultProject configured on the datasource.
   * @param startRfc3339? Optionally, the start time of the time range to filter the results by. Supports
   *                      RFC3339 or relative time (e.g. 'now-1h')
   */
  list_prometheus_label_names(datasourceUid: string, endRfc3339?: string, limit?: number, matches?: Record<string, unknown>[], projectName?: string): Promise<CallResult>;
  // optional (1): startRfc3339

  /**
   * Use after list_prometheus_metric_names to find label values for filtering queries. Gets the values
   * for a specific label name in a PromQL-compatible datasource (Prometheus, Thanos, Mimir, Cloud
   * Monitoring, etc.). Allows filtering by series selectors and time range.
   *
   * @param datasourceUid The UID of the datasource to query
   * @param endRfc3339? Optionally, the end time of the query. Supports RFC3339 or relative time (e.g.
   *                    'now')
   * @param labelName The name of the label to query
   * @param limit? Optionally, the maximum number of results to return
   * @param matches? Optionally, a list of selectors to filter the results by
   * @param projectName? GCP project name to query (Cloud Monitoring datasources only). Overrides or
   *                     substitutes the defaultProject configured on the datasource.
   * @param startRfc3339? Optionally, the start time of the query. Supports RFC3339 or relative time
   *                      (e.g. 'now-1h')
   */
  list_prometheus_label_values(datasourceUid: string, endRfc3339?: string, labelName: string, limit?: number, matches?: Record<string, unknown>[]): Promise<CallResult>;
  // optional (2): projectName, startRfc3339

  /**
   * List Prometheus metric metadata. Returns metadata about metrics currently scraped from targets.
   * Note: This endpoint is experimental.
   *
   * @param datasourceUid The UID of the datasource to query
   * @param limit? The maximum number of metrics to return
   * @param limitPerMetric? The maximum number of metrics to return per metric
   * @param metric? The metric to query
   * @param projectName? GCP project name to query (Cloud Monitoring datasources only). Overrides or
   *                     substitutes the defaultProject configured on the datasource.
   */
  list_prometheus_metric_metadata(datasourceUid: string, limit?: number, limitPerMetric?: number, metric?: string, projectName?: string): Promise<CallResult>;

  /**
   * DISCOVERY: Call this first to find available metrics before querying. Lists metric names in a
   * PromQL-compatible datasource (Prometheus, Thanos, Mimir, Cloud Monitoring, etc.). Retrieves all
   * metric names and filters them using the provided regex. Supports pagination and an optional time
   * range to restrict results to metrics active within that window.
   *
   * @param datasourceUid The UID of the datasource to query
   * @param endRfc3339? Optionally, the end time of the time range to filter the results by. Supports
   *                    RFC3339 or relative time (e.g. 'now')
   * @param limit? The maximum number of results to return
   * @param page? The page number to return
   * @param projectName? GCP project name to query (Cloud Monitoring datasources only). Overrides or
   *                     substitutes the defaultProject configured on the datasource.
   * @param regex? The regex to match against the metric names
   * @param startRfc3339? Optionally, the start time of the time range to filter the results by. Supports
   *                      RFC3339 or relative time (e.g. 'now-1h')
   */
  list_prometheus_metric_names(datasourceUid: string, endRfc3339?: string, limit?: number, page?: number, projectName?: string): Promise<CallResult>;
  // optional (2): regex, startRfc3339

  /**
   * Lists all available label names (keys) found in profiles within a specified Pyroscope datasource,
   * time range, and
   * optional label matchers. Label matchers are typically used to qualify a service name
   * ({service_name="foo"}). Returns a
   * list of unique label strings (e.g., ["app", "env", "pod"]). Label names with double underscores
   * (e.g. __name__) are
   * internal and rarely useful to users. If the time range is not provided, it defaults to the last
   * hour.
   *
   * @param data_source_uid The UID of the datasource to query
   * @param end_rfc_3339? Optionally, the end time of the query in RFC3339 format or relative time (e.g.
   *                      'now') (defaults to now)
   * @param start_rfc_3339? Optionally, the start time of the query in RFC3339 format or relative time
   *                        (e.g. 'now-1h') (defaults to 1 hour ago)
   */
  list_pyroscope_label_names(data_source_uid: string, end_rfc_3339?: string, matchers?: string, start_rfc_3339?: string): Promise<CallResult>;

  /**
   * Lists all available label values for a particular label name found in profiles within a specified
   * Pyroscope datasource,
   * time range, and optional label matchers. Label matchers are typically used to qualify a service name
   * ({service_name="foo"}).
   * Returns a list of unique label strings (e.g. for label name "env": ["dev", "staging", "prod"]). If
   * the time range
   * is not provided, it defaults to the last hour.
   *
   * @param data_source_uid The UID of the datasource to query
   * @param end_rfc_3339? Optionally, the end time of the query in RFC3339 format or relative time (e.g.
   *                      'now') (defaults to now)
   * @param matchers? Optionally, Prometheus style matchers used to filter the result set (defaults to:
   *                  {})
   * @param name A label name
   * @param start_rfc_3339? Optionally, the start time of the query in RFC3339 format or relative time
   *                        (e.g. 'now-1h') (defaults to 1 hour ago)
   */
  list_pyroscope_label_values(data_source_uid: string, end_rfc_3339?: string, matchers?: string, name: string, start_rfc_3339?: string): Promise<CallResult>;

  /**
   * Lists all available profile types available in a specified Pyroscope datasource and time range.
   * Returns a list of all
   * available profile types (example profile type: "process_cpu:cpu:nanoseconds:cpu:nanoseconds"). A
   * profile type has the
   * following structure: <name>:<sample type>:<sample unit>:<period type>:<period unit>. Not all profile
   * types are available
   * for every service. If the time range is not provided, it defaults to the last hour.
   *
   * @param data_source_uid The UID of the datasource to query
   * @param end_rfc_3339? Optionally, the end time of the query in RFC3339 format or relative time (e.g.
   *                      'now') (defaults to now)
   * @param start_rfc_3339? Optionally, the start time of the query in RFC3339 format or relative time
   *                        (e.g. 'now-1h') (defaults to 1 hour ago)
   */
  list_pyroscope_profile_types(data_source_uid: string, end_rfc_3339?: string, start_rfc_3339?: string): Promise<CallResult>;

  /**
   * WORKFLOW: list_prometheus_metric_names -> list_prometheus_label_values -> query_prometheus. Query a
   * PromQL-compatible datasource (Prometheus, Thanos, Mimir, Cloud Monitoring, etc.) using a PromQL
   * expression. Supports instant queries (single point) and range queries (time range). Time: RFC3339 or
   * relative expressions like 'now'\, 'now-1h'.
   *
   * @param datasourceUid The UID of the datasource to query
   * @param endTime The end time. Supported formats are RFC3339 or relative to now (e.g. 'now',
   *                'now-1.5h', 'now-2h45m'). Valid time units are 'ns', 'us' (or 'µs'), 'ms', 's', 'm',
   *                'h', 'd'.
   * @param expr The PromQL expression to query
   * @param projectName? GCP project name to query (Cloud Monitoring datasources only). Overrides or
   *                     substitutes the defaultProject configured on the datasource.
   * @param queryType? The type of query to use. Either 'range' or 'instant'
   * @param startTime? The start time. Required if queryType is 'range', ignored if queryType is
   *                   'instant' Supported formats are RFC3339 or relative to now (e.g. 'now',
   *                   'now-1.5h', 'now-2h45m'). Valid time units are 'ns', 'us' (or 'µs'), 'ms', 's',
   *                   'm', 'h', 'd'.
   * @param stepSeconds? The time series step size in seconds. Required if queryType is 'range', ignored
   *                     if queryType is 'instant'
   */
  query_prometheus(datasourceUid: string, endTime: string, expr: string, projectName?: string, queryType?: string): Promise<CallResult>;
  // optional (2): startTime, stepSeconds

  /**
   * Query Prometheus histogram percentiles. DISCOVER FIRST: Use list_prometheus_metric_names with
   * regex='.*_bucket$' to find histograms.
   * Generates histogram_quantile PromQL. Example: metric='http_duration', percentile=95,
   * labels='job="api"'
   * Time formats: 'now-1h', '2026-02-02T19:00:00Z', '1738519200000' (Unix ms)
   *
   * @param datasourceUid The UID of the Prometheus datasource
   * @param endTime? End time (default: now). Supports RFC3339, relative, or Unix ms.
   * @param labels? Label selector (e.g. job="api", service="gateway")
   * @param metric Base histogram metric name (without _bucket suffix)
   * @param percentile Percentile to calculate (e.g. 50, 90, 95, 99)
   * @param projectName? GCP project name to query (Cloud Monitoring datasources only). Overrides or
   *                     substitutes the defaultProject configured on the datasource.
   * @param rateInterval? Rate interval for the query (default: 5m)
   * @param startTime? Start time (default: now-1h). Supports RFC3339, relative (now-1h), or Unix ms.
   * @param stepSeconds? Step size in seconds for range query (default: 60)
   */
  query_prometheus_histogram(datasourceUid: string, endTime?: string, labels?: string, metric: string, percentile: number): Promise<CallResult>;
  // optional (4): projectName, rateInterval, startTime, stepSeconds

  /**
   * Unified Pyroscope query tool for fetching profiles or metrics from Pyroscope. Profile data shows
   * WHICH functions consume resources; metrics data
   * shows WHEN consumption spiked. Use query_type="both" for complete analysis in one call.
   * query_type options (extends Grafana's PyroscopeQueryType):
   * - "profile": returns DOT-format call graph
   * - "metrics": returns time-series data points
   * - "both" (default): returns both profile and metrics in one response
   *
   * @param data_source_uid The UID of the datasource to query
   * @param end_rfc_3339? End time in RFC3339 or relative time (e.g. 'now') (defaults to now)
   * @param group_by? Labels to group metrics series by
   * @param matchers? Prometheus style matchers (defaults to: {})
   * @param max_node_depth? Max depth for profile call graph (default: 100)
   * @param profile_type The profile type, use list_pyroscope_profile_types to discover available types
   * @param query_type? Query type: "profile" (flamegraph), "metrics" (time-series), or "both" (default).
   *                    Use "both" for complete analysis
   * @param start_rfc_3339? Start time in RFC3339 or relative time (e.g. 'now-1h') (defaults to 1 hour
   *                        ago)
   * @param step? Seconds between metrics data points (default: auto)
   */
  query_pyroscope(data_source_uid: string, end_rfc_3339?: string, group_by?: string[], matchers?: string, profile_type: string): Promise<CallResult>;
  // optional (4): max_node_depth, query_type, start_rfc_3339, step

  /**
   * Search for Grafana dashboards by a query string. Returns a list of matching dashboards with details
   * like title, UID, folder, tags, and URL.
   *
   * @param limit? Maximum number of results to return (max 100)
   * @param page? Page number for pagination (1-indexed)
   * @param query? The query to search for
   */
  search_dashboards(limit?: number, page?: number, query?: string): Promise<CallResult>;

  /**
   * Search for Grafana folders by a query string. Returns matching folders with details like title, UID,
   * and URL.
   *
   * @param query? The query to search for
   */
  search_folders(query?: string): Promise<CallResult>;

  /**
   * Documentation on TraceQL search. Best for retrieval of traces. This covers basic attributes all the
   * way through aggregates, pipelining, structural queries, and more. Includes examples.
   *
   * @param datasourceUid UID of the tempo datasource to query
   * @param name The type of TraceQL documentation to retrieve
   */
  "tempo_docs-traceql"(datasourceUid: string, name: "basic" | "aggregates" | "structural" | "metrics"): Promise<CallResult>;

  /**
   * Get a list of available attribute names that can be used in TraceQL queries. This is useful for
   * finding the names of attributes that can be used in a query.
   *
   * @param datasourceUid UID of the tempo datasource to query
   * @param scope? Optional scope to filter attributes by (span, resource, event, link, instrumentation).
   *               If not provided, returns all attributes.
   */
  "tempo_get-attribute-names"(datasourceUid: string, scope?: string): Promise<CallResult>;

  /**
   * Get a list of values for a fully scoped attribute name. This is useful for finding the values of a
   * specific attribute. i.e. you can find all the services in the data by asking for
   * resource.service.name
   *
   * @param datasourceUid UID of the tempo datasource to query
   * @param filter-query? Filter query to apply to the attribute values. It can only have one spanset and
   *                      only &&'ed conditions like { <cond> && <cond> && ... }.This is useful for
   *                      filtering the values to a specific set of values. i.e. you can find all
   *                      endpoints for a given service by asking for span.http.endpoint and filtering
   *                      resource.service.name.
   * @param name The attribute name to get values for (e.g. 'span.http.method', 'resource.service.name')
   */
  "tempo_get-attribute-values"(datasourceUid: string, filter-query?: string, name: string): Promise<CallResult>;

  /**
   * Retrieve a specific trace by ID
   *
   * @param datasourceUid UID of the tempo datasource to query
   * @param trace_id Trace ID to retrieve
   */
  "tempo_get-trace"(datasourceUid: string, trace_id: string): Promise<CallResult>;

  /**
   * Retrieve a single metric value given a TraceQL metrics query. The value is at the current instant or
   * end. Most metrics questions can be answered with instant values.
   *
   * @param datasourceUid UID of the tempo datasource to query
   * @param end? End time for the search (RFC3339 format). If not provided will search the past 1 hour.
   *             If provided, must be after start.
   * @param query TraceQL query string.
   * @param start? Start time for the search (RFC3339 format). If not provided will search the past 1
   *               hour. If provided, must be before end.
   */
  "tempo_traceql-metrics-instant"(datasourceUid: string, end?: string, query: string, start?: string): Promise<CallResult>;

  /**
   * Retrieve a metric series given a TraceQL metrics query. The series ranges from start to end.
   *
   * @param datasourceUid UID of the tempo datasource to query
   * @param end? End time for the search (RFC3339 format). If not provided will search the past 1 hour.
   *             If provided, must be after start.
   * @param query TraceQL metrics query string.
   * @param start? Start time for the search (RFC3339 format). If not provided will search the past 1
   *               hour. If provided, must be before end.
   */
  "tempo_traceql-metrics-range"(datasourceUid: string, end?: string, query: string, start?: string): Promise<CallResult>;

  /**
   * Search for traces using TraceQL queries
   *
   * @param datasourceUid UID of the tempo datasource to query
   * @param end? End time for the search (RFC3339 format). If not provided will search the past 1 hour.
   *             If provided, must be after start.
   * @param query TraceQL query string
   * @param start? Start time for the search (RFC3339 format). If not provided will search the past 1
   *               hour. If provided, must be before end.
   */
  "tempo_traceql-search"(datasourceUid: string, end?: string, query: string, start?: string): Promise<CallResult>;
}

