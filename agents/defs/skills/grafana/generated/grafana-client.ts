// Generated on 2026-08-10T19:33:04.687Z by mcporter@0.13.3
// Server: grafana
// Source: /Users/kisw/.config/nix-agents/pi/bases/work/settings/mcporter.json
// Transport: HTTP https://mcp-grafana.lunar.tech/mcp

import { createRuntime, createServerProxy, wrapCallResult } from 'mcporter';
import type { GrafanaTools } from './grafana-client';

type RuntimeInstance = Awaited<ReturnType<typeof createRuntime>>;
export type GrafanaClient = GrafanaTools & { close(): Promise<void> };

export interface CreateClientOptions {
  runtime?: RuntimeInstance;
  configPath?: string;
  rootDir?: string;
}

export async function createGrafanaClient(options: CreateClientOptions = {}): Promise<GrafanaClient> {
  const runtime = options.runtime ?? (await createRuntime({
    configPath: options.configPath,
    rootDir: options.rootDir,
  }));
  const ownsRuntime = !options.runtime;
  const proxy = createServerProxy(runtime, "grafana");
  const client: GrafanaClient = {
    async alerting_manage_routing(params: Parameters<GrafanaTools["alerting_manage_routing"]>[0]) {
      const tool = proxy.alertingManageRouting as (args: Parameters<GrafanaTools["alerting_manage_routing"]>[0]) => Promise<unknown>;
      const raw = await tool(params);
      return wrapCallResult(raw).callResult;
    },

    async alerting_manage_rules(params: Parameters<GrafanaTools["alerting_manage_rules"]>[0]) {
      const tool = proxy.alertingManageRules as (args: Parameters<GrafanaTools["alerting_manage_rules"]>[0]) => Promise<unknown>;
      const raw = await tool(params);
      return wrapCallResult(raw).callResult;
    },

    async check_datasources_health(params: Parameters<GrafanaTools["check_datasources_health"]>[0]) {
      const tool = proxy.checkDatasourcesHealth as (args: Parameters<GrafanaTools["check_datasources_health"]>[0]) => Promise<unknown>;
      const raw = await tool(params);
      return wrapCallResult(raw).callResult;
    },

    async generate_deeplink(params: Parameters<GrafanaTools["generate_deeplink"]>[0]) {
      const tool = proxy.generateDeeplink as (args: Parameters<GrafanaTools["generate_deeplink"]>[0]) => Promise<unknown>;
      const raw = await tool(params);
      return wrapCallResult(raw).callResult;
    },

    async get_annotation_tags(params: Parameters<GrafanaTools["get_annotation_tags"]>[0]) {
      const tool = proxy.getAnnotationTags as (args: Parameters<GrafanaTools["get_annotation_tags"]>[0]) => Promise<unknown>;
      const raw = await tool(params);
      return wrapCallResult(raw).callResult;
    },

    async get_annotations(params: Parameters<GrafanaTools["get_annotations"]>[0]) {
      const tool = proxy.getAnnotations as (args: Parameters<GrafanaTools["get_annotations"]>[0]) => Promise<unknown>;
      const raw = await tool(params);
      return wrapCallResult(raw).callResult;
    },

    async get_dashboard_by_uid(params: Parameters<GrafanaTools["get_dashboard_by_uid"]>[0]) {
      const tool = proxy.getDashboardByUid as (args: Parameters<GrafanaTools["get_dashboard_by_uid"]>[0]) => Promise<unknown>;
      const raw = await tool(params);
      return wrapCallResult(raw).callResult;
    },

    async get_dashboard_panel_queries(params: Parameters<GrafanaTools["get_dashboard_panel_queries"]>[0]) {
      const tool = proxy.getDashboardPanelQueries as (args: Parameters<GrafanaTools["get_dashboard_panel_queries"]>[0]) => Promise<unknown>;
      const raw = await tool(params);
      return wrapCallResult(raw).callResult;
    },

    async get_dashboard_property(params: Parameters<GrafanaTools["get_dashboard_property"]>[0]) {
      const tool = proxy.getDashboardProperty as (args: Parameters<GrafanaTools["get_dashboard_property"]>[0]) => Promise<unknown>;
      const raw = await tool(params);
      return wrapCallResult(raw).callResult;
    },

    async get_dashboard_summary(params: Parameters<GrafanaTools["get_dashboard_summary"]>[0]) {
      const tool = proxy.getDashboardSummary as (args: Parameters<GrafanaTools["get_dashboard_summary"]>[0]) => Promise<unknown>;
      const raw = await tool(params);
      return wrapCallResult(raw).callResult;
    },

    async get_datasource(params: Parameters<GrafanaTools["get_datasource"]>[0]) {
      const tool = proxy.getDatasource as (args: Parameters<GrafanaTools["get_datasource"]>[0]) => Promise<unknown>;
      const raw = await tool(params);
      return wrapCallResult(raw).callResult;
    },

    async list_datasources(params: Parameters<GrafanaTools["list_datasources"]>[0]) {
      const tool = proxy.listDatasources as (args: Parameters<GrafanaTools["list_datasources"]>[0]) => Promise<unknown>;
      const raw = await tool(params);
      return wrapCallResult(raw).callResult;
    },

    async list_prometheus_label_names(params: Parameters<GrafanaTools["list_prometheus_label_names"]>[0]) {
      const tool = proxy.listPrometheusLabelNames as (args: Parameters<GrafanaTools["list_prometheus_label_names"]>[0]) => Promise<unknown>;
      const raw = await tool(params);
      return wrapCallResult(raw).callResult;
    },

    async list_prometheus_label_values(params: Parameters<GrafanaTools["list_prometheus_label_values"]>[0]) {
      const tool = proxy.listPrometheusLabelValues as (args: Parameters<GrafanaTools["list_prometheus_label_values"]>[0]) => Promise<unknown>;
      const raw = await tool(params);
      return wrapCallResult(raw).callResult;
    },

    async list_prometheus_metric_metadata(params: Parameters<GrafanaTools["list_prometheus_metric_metadata"]>[0]) {
      const tool = proxy.listPrometheusMetricMetadata as (args: Parameters<GrafanaTools["list_prometheus_metric_metadata"]>[0]) => Promise<unknown>;
      const raw = await tool(params);
      return wrapCallResult(raw).callResult;
    },

    async list_prometheus_metric_names(params: Parameters<GrafanaTools["list_prometheus_metric_names"]>[0]) {
      const tool = proxy.listPrometheusMetricNames as (args: Parameters<GrafanaTools["list_prometheus_metric_names"]>[0]) => Promise<unknown>;
      const raw = await tool(params);
      return wrapCallResult(raw).callResult;
    },

    async list_pyroscope_label_names(params: Parameters<GrafanaTools["list_pyroscope_label_names"]>[0]) {
      const tool = proxy.listPyroscopeLabelNames as (args: Parameters<GrafanaTools["list_pyroscope_label_names"]>[0]) => Promise<unknown>;
      const raw = await tool(params);
      return wrapCallResult(raw).callResult;
    },

    async list_pyroscope_label_values(params: Parameters<GrafanaTools["list_pyroscope_label_values"]>[0]) {
      const tool = proxy.listPyroscopeLabelValues as (args: Parameters<GrafanaTools["list_pyroscope_label_values"]>[0]) => Promise<unknown>;
      const raw = await tool(params);
      return wrapCallResult(raw).callResult;
    },

    async list_pyroscope_profile_types(params: Parameters<GrafanaTools["list_pyroscope_profile_types"]>[0]) {
      const tool = proxy.listPyroscopeProfileTypes as (args: Parameters<GrafanaTools["list_pyroscope_profile_types"]>[0]) => Promise<unknown>;
      const raw = await tool(params);
      return wrapCallResult(raw).callResult;
    },

    async query_prometheus(params: Parameters<GrafanaTools["query_prometheus"]>[0]) {
      const tool = proxy.queryPrometheus as (args: Parameters<GrafanaTools["query_prometheus"]>[0]) => Promise<unknown>;
      const raw = await tool(params);
      return wrapCallResult(raw).callResult;
    },

    async query_prometheus_histogram(params: Parameters<GrafanaTools["query_prometheus_histogram"]>[0]) {
      const tool = proxy.queryPrometheusHistogram as (args: Parameters<GrafanaTools["query_prometheus_histogram"]>[0]) => Promise<unknown>;
      const raw = await tool(params);
      return wrapCallResult(raw).callResult;
    },

    async query_pyroscope(params: Parameters<GrafanaTools["query_pyroscope"]>[0]) {
      const tool = proxy.queryPyroscope as (args: Parameters<GrafanaTools["query_pyroscope"]>[0]) => Promise<unknown>;
      const raw = await tool(params);
      return wrapCallResult(raw).callResult;
    },

    async search_dashboards(params: Parameters<GrafanaTools["search_dashboards"]>[0]) {
      const tool = proxy.searchDashboards as (args: Parameters<GrafanaTools["search_dashboards"]>[0]) => Promise<unknown>;
      const raw = await tool(params);
      return wrapCallResult(raw).callResult;
    },

    async search_folders(params: Parameters<GrafanaTools["search_folders"]>[0]) {
      const tool = proxy.searchFolders as (args: Parameters<GrafanaTools["search_folders"]>[0]) => Promise<unknown>;
      const raw = await tool(params);
      return wrapCallResult(raw).callResult;
    },

    async "tempo_docs-traceql"(params: Parameters<GrafanaTools["tempo_docs-traceql"]>[0]) {
      const tool = proxy.tempoDocsTraceql as (args: Parameters<GrafanaTools["tempo_docs-traceql"]>[0]) => Promise<unknown>;
      const raw = await tool(params);
      return wrapCallResult(raw).callResult;
    },

    async "tempo_get-attribute-names"(params: Parameters<GrafanaTools["tempo_get-attribute-names"]>[0]) {
      const tool = proxy.tempoGetAttributeNames as (args: Parameters<GrafanaTools["tempo_get-attribute-names"]>[0]) => Promise<unknown>;
      const raw = await tool(params);
      return wrapCallResult(raw).callResult;
    },

    async "tempo_get-attribute-values"(params: Parameters<GrafanaTools["tempo_get-attribute-values"]>[0]) {
      const tool = proxy.tempoGetAttributeValues as (args: Parameters<GrafanaTools["tempo_get-attribute-values"]>[0]) => Promise<unknown>;
      const raw = await tool(params);
      return wrapCallResult(raw).callResult;
    },

    async "tempo_get-trace"(params: Parameters<GrafanaTools["tempo_get-trace"]>[0]) {
      const tool = proxy.tempoGetTrace as (args: Parameters<GrafanaTools["tempo_get-trace"]>[0]) => Promise<unknown>;
      const raw = await tool(params);
      return wrapCallResult(raw).callResult;
    },

    async "tempo_traceql-metrics-instant"(params: Parameters<GrafanaTools["tempo_traceql-metrics-instant"]>[0]) {
      const tool = proxy.tempoTraceqlMetricsInstant as (args: Parameters<GrafanaTools["tempo_traceql-metrics-instant"]>[0]) => Promise<unknown>;
      const raw = await tool(params);
      return wrapCallResult(raw).callResult;
    },

    async "tempo_traceql-metrics-range"(params: Parameters<GrafanaTools["tempo_traceql-metrics-range"]>[0]) {
      const tool = proxy.tempoTraceqlMetricsRange as (args: Parameters<GrafanaTools["tempo_traceql-metrics-range"]>[0]) => Promise<unknown>;
      const raw = await tool(params);
      return wrapCallResult(raw).callResult;
    },

    async "tempo_traceql-search"(params: Parameters<GrafanaTools["tempo_traceql-search"]>[0]) {
      const tool = proxy.tempoTraceqlSearch as (args: Parameters<GrafanaTools["tempo_traceql-search"]>[0]) => Promise<unknown>;
      const raw = await tool(params);
      return wrapCallResult(raw).callResult;
    },

    async close() {
      if (ownsRuntime) {
        await runtime.close("grafana").catch(() => {});
      }
    },
  };
  return client;
}

