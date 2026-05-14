{{/* vim: set filetype=mustache: */}}

{{/*
Expand the name of the chart.
*/}}
{{- define "nginx-ingress.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "nginx-ingress.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Create a default fully qualified controller name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
*/}}
{{- define "nginx-ingress.controller.fullname" -}}
{{- printf "%s-%s" (include "nginx-ingress.fullname" .) .Values.controller.name | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Create a default fully qualified controller service name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
*/}}
{{- define "nginx-ingress.controller.service.name" -}}
{{- default (include "nginx-ingress.controller.fullname" .) .Values.serviceNameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "nginx-ingress.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "nginx-ingress.labels" -}}
helm.sh/chart: {{ include "nginx-ingress.chart" . }}
{{ include "nginx-ingress.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Pod labels
*/}}
{{- define "nginx-ingress.podLabels" -}}
{{- include "nginx-ingress.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
{{- if .Values.controller.pod.extraLabels }}
{{ toYaml .Values.controller.pod.extraLabels }}
{{- end }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "nginx-ingress.selectorLabels" -}}
{{- if .Values.controller.selectorLabels -}}
{{ toYaml .Values.controller.selectorLabels }}
{{- else -}}
app.kubernetes.io/name: {{ include "nginx-ingress.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}
{{- end -}}

{{/*
Expand the name of the configmap.
*/}}
{{- define "nginx-ingress.configName" -}}
{{- if .Values.controller.customConfigMap -}}
{{ .Values.controller.customConfigMap }}
{{- else -}}
{{- default (include "nginx-ingress.fullname" .) .Values.controller.config.name -}}
{{- end -}}
{{- end -}}

{{/*
Expand leader election lock name.
*/}}
{{- define "nginx-ingress.leaderElectionName" -}}
{{- if .Values.controller.reportIngressStatus.leaderElectionLockName -}}
{{ .Values.controller.reportIngressStatus.leaderElectionLockName }}
{{- else -}}
{{- printf "%s-%s" (include "nginx-ingress.fullname" .) "leader-election" -}}
{{- end -}}
{{- end -}}

{{/*
Expand service account name.
*/}}
{{- define "nginx-ingress.serviceAccountName" -}}
{{- default (include "nginx-ingress.fullname" .) .Values.controller.serviceAccount.name -}}
{{- end -}}

{{/*
Expand default TLS name.
*/}}
{{- define "nginx-ingress.defaultTLSName" -}}
{{- printf "%s-%s" (include "nginx-ingress.fullname" .) "default-server-tls" -}}
{{- end -}}

{{/*
Expand wildcard TLS name.
*/}}
{{- define "nginx-ingress.wildcardTLSName" -}}
{{- printf "%s-%s" (include "nginx-ingress.fullname" .) "wildcard-tls" -}}
{{- end -}}

{{- define "nginx-ingress.tag" -}}
{{- default .Chart.AppVersion .Values.config.images.controller.tag -}}
{{- end -}}

{{/*
Expand image name.
*/}}
{{- define "nginx-ingress.image" -}}
{{ include "nginx-ingress.image-digest-or-tag" (dict "image" .Values.config.images.controller "default" .Chart.AppVersion ) }}
{{- end -}}

{{/*
Accepts an image struct like .Values.config.images.controller along with a default value to use
if the digest or tag is not set. Can be called like:
include "nginx-ingress.image-digest-or-tag" (dict "image" .Values.config.images.controller "default" .Chart.AppVersion
*/}}
{{- define "nginx-ingress.image-digest-or-tag" -}}
{{- if .image.digest -}}
{{- printf "%s@%s" .image.repository .image.digest -}}
{{- else -}}
{{- printf "%s:%s" .image.repository (default .default .image.tag) -}}
{{- end -}}
{{- end -}}

{{- define "nginx-ingress.prometheus.serviceName" -}}
{{- printf "%s-%s" (include "nginx-ingress.fullname" .) "prometheus-service"  -}}
{{- end -}}

{{/*
return if readOnlyRootFilesystem is enabled or not.
*/}}
{{- define "nginx-ingress.readOnlyRootFilesystem" -}}
{{- if or .Values.controller.readOnlyRootFilesystem (and .Values.controller.securityContext .Values.controller.securityContext.readOnlyRootFilesystem) -}}
true
{{- else -}}
false
{{- end -}}
{{- end -}}

{{/*
Validate the globalConfiguration.customName value format.
Ensures exactly one '/' separator for proper namespace/name parsing.
*/}}
{{- define "nginx-ingress.globalConfiguration.validateCustomName" -}}
{{- if .Values.controller.globalConfiguration.customName }}
{{- $parts := splitList "/" .Values.controller.globalConfiguration.customName }}
{{- if ne (len $parts) 2 }}
{{- fail "globalConfiguration.customName must contain exactly one '/' separator in namespace/name format (e.g., \"my-namespace/my-global-config\")" }}
{{- end }}
{{- if or (eq (index $parts 0) "") (eq (index $parts 1) "") }}
{{- fail "globalConfiguration.customName namespace and name parts cannot be empty (e.g., \"my-namespace/my-global-config\")" }}
{{- end }}
{{- end }}
{{- end -}}

{{/*
Create the global configuration custom name from the globalConfiguration.customName value.
*/}}
{{- define "nginx-ingress.globalConfiguration.customName" -}}
{{- include "nginx-ingress.globalConfiguration.validateCustomName" . -}}
{{- $parts := splitList "/" .Values.controller.globalConfiguration.customName -}}
{{- index $parts 1 -}}
{{- end -}}

{{/*
Create the global configuration custom namespace from the globalConfiguration.customName value.
*/}}
{{- define "nginx-ingress.globalConfiguration.customNamespace" -}}
{{- include "nginx-ingress.globalConfiguration.validateCustomName" . -}}
{{- $parts := splitList "/" .Values.controller.globalConfiguration.customName -}}
{{- index $parts 0 -}}
{{- end -}}

{{/*
Build the args for the service binary.
*/}}
{{- define "nginx-ingress.args" -}}
{{- if and .Values.controller.debug .Values.controller.debug.enable }}
- --listen=:2345
- --headless=true
- --log=true
- --log-output=debugger,debuglineerr,gdbwire,lldbout,rpc,dap,fncall,minidump,stack
- --accept-multiclient
- --api-version=2
- exec
- ./nginx-ingress
{{- if .Values.controller.debug.continue }}
- --continue
{{- end }}
- --
{{- end }}
- -nginx-reload-timeout={{ .Values.controller.nginxReloadTimeout }}
- -nginx-configmaps=$(POD_NAMESPACE)/{{ include "nginx-ingress.configName" . }}
{{- if .Values.controller.defaultTLS.secret }}
- -default-server-tls-secret={{ .Values.controller.defaultTLS.secret }}
{{ else if and (.Values.controller.defaultTLS.cert) (.Values.controller.defaultTLS.key) }}
- -default-server-tls-secret=$(POD_NAMESPACE)/{{ include "nginx-ingress.defaultTLSName" . }}
{{- end }}
- -ingress-class={{ .Values.controller.ingressClass.name }}
{{- if .Values.controller.watchNamespace }}
- -watch-namespace={{ .Values.controller.watchNamespace }}
{{- end }}
{{- if .Values.controller.watchNamespaceLabel }}
- -watch-namespace-label={{ .Values.controller.watchNamespaceLabel }}
{{- end }}
{{- if .Values.controller.watchSecretNamespace }}
- -watch-secret-namespace={{ .Values.controller.watchSecretNamespace }}
{{- end }}
- -health-status={{ .Values.controller.healthStatus }}
- -health-status-uri={{ .Values.controller.healthStatusURI }}
- -nginx-debug={{ .Values.controller.nginxDebug }}
- -log-level={{ .Values.controller.logLevel }}
- -log-format={{ .Values.controller.logFormat }}
- -enable-config-safety={{ .Values.controller.enableConfigSafety }}
- -nginx-status={{ .Values.controller.nginxStatus.enable }}
{{- if .Values.controller.nginxStatus.enable }}
- -nginx-status-port={{ .Values.controller.nginxStatus.port }}
- -nginx-status-allow-cidrs={{ .Values.controller.nginxStatus.allowCidrs }}
{{- end }}
{{- if .Values.controller.reportIngressStatus.enable }}
- -report-ingress-status
{{- if .Values.controller.reportIngressStatus.ingressLink }}
- -ingresslink={{ .Values.controller.reportIngressStatus.ingressLink }}
{{- else if .Values.controller.reportIngressStatus.externalService }}
- -external-service={{ .Values.controller.reportIngressStatus.externalService }}
{{- else if and (.Values.controller.service.create) (eq .Values.controller.service.type "LoadBalancer") }}
- -external-service={{ include "nginx-ingress.controller.service.name" . }}
{{- end }}
{{- end }}
- -enable-leader-election={{ .Values.controller.reportIngressStatus.enableLeaderElection }}
{{- if .Values.controller.reportIngressStatus.enableLeaderElection }}
- -leader-election-lock-name={{ include "nginx-ingress.leaderElectionName" . }}
{{- end }}
{{- if .Values.controller.wildcardTLS.secret }}
- -wildcard-tls-secret={{ .Values.controller.wildcardTLS.secret }}
{{- else if and .Values.controller.wildcardTLS.cert .Values.controller.wildcardTLS.key }}
- -wildcard-tls-secret=$(POD_NAMESPACE)/{{ include "nginx-ingress.wildcardTLSName" . }}
{{- end }}
- -enable-prometheus-metrics={{ .Values.prometheus.create }}
- -prometheus-metrics-listen-port={{ .Values.prometheus.port }}
- -prometheus-tls-secret={{ .Values.prometheus.secret }}
- -enable-custom-resources={{ .Values.controller.enableCustomResources }}
- -enable-snippets={{ .Values.controller.enableSnippets }}
- -disable-ipv6={{ .Values.controller.disableIPV6 }}
{{- if .Values.controller.directiveAutoAdjust }}
- -enable-directive-autoadjust={{ .Values.controller.directiveAutoAdjust }}
{{- end }}
{{- if .Values.controller.enableCustomResources }}
- -enable-tls-passthrough={{ .Values.controller.enableTLSPassthrough }}
{{- if .Values.controller.enableTLSPassthrough }}
- -tls-passthrough-port={{ .Values.controller.tlsPassthroughPort }}
{{- end }}
- -enable-cert-manager={{ .Values.controller.enableCertManager }}
- -enable-external-dns={{ .Values.controller.enableExternalDNS }}
- -default-http-listener-port={{ .Values.controller.defaultHTTPListenerPort}}
- -default-https-listener-port={{ .Values.controller.defaultHTTPSListenerPort}}
{{- if and .Values.controller.globalConfiguration.create (not .Values.controller.globalConfiguration.customName) }}
- -global-configuration=$(POD_NAMESPACE)/{{ include "nginx-ingress.controller.fullname" . }}
{{- else if .Values.controller.globalConfiguration.customName }}
- -global-configuration={{ .Values.controller.globalConfiguration.customName }}
{{- end }}
{{- end }}
- -ready-status={{ .Values.controller.readyStatus.enable }}
- -ready-status-port={{ .Values.controller.readyStatus.port }}
- -enable-latency-metrics={{ .Values.controller.enableLatencyMetrics }}
- -ssl-dynamic-reload={{ .Values.controller.enableSSLDynamicReload }}
- -enable-telemetry-reporting={{ .Values.controller.telemetryReporting.enable}}
{{- end -}}

{{/*
Volumes for controller.
*/}}
{{- define "nginx-ingress.volumes" -}}
{{- $volumesSet := "false" }}
volumes:
{{- if eq (include "nginx-ingress.volumeEntries" .) "" -}}
{{ toYaml list | printf " %s" }}
{{- else }}
{{ include "nginx-ingress.volumeEntries" . }}
{{- end -}}
{{- end -}}

{{/*
List of volumes for controller.
*/}}
{{- define "nginx-ingress.volumeEntries" -}}
{{- if eq (include "nginx-ingress.readOnlyRootFilesystem" .) "true" }}
- name: nginx-etc
  emptyDir: {}
- name: nginx-lib
  emptyDir: {}
- name: nginx-state
  emptyDir: {}
- name: nginx-log
  emptyDir: {}
- name: nginx-cache
  emptyDir: {}
{{- end }}
{{- if .Values.controller.volumes }}
{{ toYaml .Values.controller.volumes }}
{{- end }}
{{- if .Values.config.wallarm.enabled }}
{{ include "nginx-ingress.wallarm.volumes" . }}
{{- end -}}
{{- end -}}

{{/*
Volume mounts for controller.
*/}}
{{- define "nginx-ingress.volumeMounts" -}}
{{- $volumesSet := "false" }}
volumeMounts:
{{- if eq (include "nginx-ingress.volumeMountEntries" .) "" -}}
{{ toYaml list | printf " %s" }}
{{- else }}
{{ include "nginx-ingress.volumeMountEntries" . }}
{{- end -}}
{{- end -}}
{{- define "nginx-ingress.volumeMountEntries" -}}
{{- if eq (include "nginx-ingress.readOnlyRootFilesystem" .) "true" }}
- mountPath: /etc/nginx
  name: nginx-etc
- mountPath: /var/cache/nginx
  name: nginx-cache
- mountPath: /var/lib/nginx
  name: nginx-lib
- mountPath: /var/lib/nginx/state
  name: nginx-state
- mountPath: /var/log/nginx
  name: nginx-log
{{- end }}
{{- if .Values.controller.volumeMounts }}
{{ toYaml .Values.controller.volumeMounts }}
{{- end }}
{{- if .Values.config.wallarm.enabled }}
{{ include "nginx-ingress.wallarm.volumeMounts" . }}
{{- end -}}
{{- end -}}

{{/*
Wallarm helper templates
*/}}

{{/*
Get specific paths
*/}}
{{- define "wallarm.path" -}}
{{- printf "/opt/wallarm/etc/wallarm" -}}
{{- end -}}

{{- define "wallarm-acl.path" -}}
{{- printf "/opt/wallarm/var/lib/wallarm-acl" -}}
{{- end -}}

{{- define "wallarm-cache.path" -}}
{{- printf "/opt/wallarm/var/lib/nginx/wallarm" -}}
{{- end -}}

{{- define "wallarm-apifw.path" -}}
{{- printf "/opt/wallarm/var/lib/wallarm-api" -}}
{{- end -}}

{{- define "ingress-nginx.wallarmPostanalyticsPort" -}}3313{{- end -}}
{{- define "ingress-nginx.wallarmPostanalyticsHealthPort" -}}5005{{- end -}}

{{- define "wallarm.credentials" -}}
- name: WALLARM_API_HOST
  value: {{ .Values.config.wallarm.api.host | quote }}
- name: WALLARM_API_PORT
  value: {{ .Values.config.wallarm.api.port | toString | quote }}
{{- if hasKey .Values.config.wallarm.api "ssl" }}
- name: WALLARM_API_USE_SSL
  value: {{ .Values.config.wallarm.api.ssl | toString | quote }}
{{- end }}
{{- if hasKey .Values.config.wallarm "caverify" }}
- name: WALLARM_API_CA_VERIFY
  value: {{ .Values.config.wallarm.api.caverify | toString | quote }}
{{- end }}
- name: WALLARM_API_TOKEN_PATH
  value: "/secrets/wallarm/token"
- name: WALLARM_COMPONENT_NAME
  value: wallarm-new-ingress-controller
- name: WALLARM_COMPONENT_VERSION
  value: {{ .Chart.Version | quote }}
{{- end -}}

{{- define "ingress-nginx.wallarmSecret" -}}{{ include "nginx-ingress.fullname" . }}-wallarm-token{{- end -}}

{{- define "ingress-nginx.wallarmTokenVolume" -}}
- name: wallarm-token
  secret:
    secretName: {{ ternary .Values.config.wallarm.api.existingSecret.secretName (include "ingress-nginx.wallarmSecret" .) .Values.config.wallarm.api.existingSecret.enabled }}
    items:
      - key: {{ ternary .Values.config.wallarm.api.existingSecret.secretKey "token" .Values.config.wallarm.api.existingSecret.enabled }}
        path: {{ ternary .Values.config.wallarm.api.existingSecret.secretKey "token" .Values.config.wallarm.api.existingSecret.enabled }}
{{- end -}}

{{/*
Wallarm token secret name
*/}}
{{- define "nginx-ingress.wallarm.tokenSecretName" -}}
{{- if .Values.config.wallarm.api.existingSecret.enabled }}
{{- .Values.config.wallarm.api.existingSecret.secretName }}
{{- else }}
{{- printf "%s-wallarm-token" (include "nginx-ingress.fullname" .) }}
{{- end }}
{{- end }}

{{/*
Wallarm token secret key
*/}}
{{- define "nginx-ingress.wallarm.tokenSecretKey" -}}
{{- if .Values.config.wallarm.api.existingSecret.enabled }}
{{- .Values.config.wallarm.api.existingSecret.secretKey }}
{{- else -}}
token
{{- end }}
{{- end }}

{{/*
Wallarm postanalytics service name (for use in controller args)
*/}}
{{- define "nginx-ingress.wallarm.postanalyticsServiceName" -}}
{{- printf "%s-wallarm-postanalytics" (include "nginx-ingress.fullname" .) }}
{{- end }}

# taken from default baked-in controller container defaults
{{- define "nginx-ingress.wallarm.defaultSecurityContext" -}}
securityContext:
  allowPrivilegeEscalation: false
  readOnlyRootFilesystem: false
  runAsUser: 101 #nginx
  runAsNonRoot: true
  capabilities:
    drop:
    - ALL
    add:
    - NET_BIND_SERVICE
{{- end }}

{{/*
Wallarm wd init container — runs "wd ctl init" to register node and sync data before main containers start.
Accepts a dict with:
  - context: the root context (.)
  - wdConfig: the wd configuration object containing resources, securityContext, extraEnvs
*/}}
{{- define "nginx-ingress.wallarm.wdInitContainer" -}}
- name: wd-init
  image: {{ .context.Values.config.images.helper.repository }}:{{ .context.Values.config.images.helper.tag }}
  imagePullPolicy: {{ .context.Values.config.images.helper.pullPolicy }}
  args: ["/opt/wallarm/usr/bin/wd", "ctl", "init", "--config", "/etc/wallarm/wd.yaml"]
  env:
  {{- include "wallarm.credentials" .context | nindent 2 }}
  - name: WALLARM_NODE_NAME
    valueFrom:
      fieldRef:
        fieldPath: metadata.name
  - name: WALLARM_SYNCNODE_OWNER
    value: www-data
  - name: WALLARM_SYNCNODE_GROUP
    value: www-data
  - name: WALLARM_LABELS
    value: "group={{ .context.Values.config.wallarm.api.nodeGroup }}"
  {{- with .wdConfig.extraEnvs }}
    {{- toYaml . | nindent 2 }}
  {{- end }}
  volumeMounts:
  - name: wd-config
    mountPath: /etc/wallarm/wd.yaml
    subPath: wd.yaml
    readOnly: true
  - name: wallarm
    mountPath: {{ include "wallarm.path" .context }}
  - name: wallarm-acl
    mountPath: {{ include "wallarm-acl.path" .context }}
  - name: wallarm-token
    mountPath: /secrets/wallarm/token
    subPath: {{ include "nginx-ingress.wallarm.tokenSecretKey" .context }}
    readOnly: true
{{- if .wdConfig.securityContext }}
  securityContext:
{{ toYaml .wdConfig.securityContext | indent 4 }}
{{- else }}
  {{ include "nginx-ingress.wallarm.defaultSecurityContext" (dict "context" .context) | nindent 2 }}
{{- end }}
  {{- with .wdConfig.resources }}
  resources:
    {{- toYaml . | nindent 4 }}
  {{- end }}
{{- end }}

{{/*
Wallarm wd (process manager) container template.
Accepts a dict with:
  - context: the root context (.)
  - wdConfig: the wd configuration object containing resources, securityContext, extraEnvs
  - configMapName: name of the ConfigMap containing wd.yaml
  - mode: "postanalytics" or "controller" - determines ports and volume mounts
*/}}
{{- define "nginx-ingress.wallarm.wdContainer" -}}
- name: wd
  image: {{ .context.Values.config.images.helper.repository }}:{{ .context.Values.config.images.helper.tag }}
  imagePullPolicy: {{ .context.Values.config.images.helper.pullPolicy }}
  args: ["/opt/wallarm/usr/bin/wd", "--config", "/etc/wallarm/wd.yaml"]
  env:
  {{- include "wallarm.credentials" .context | nindent 2 }}
  - name: WALLARM_NODE_NAME
    valueFrom:
      fieldRef:
        fieldPath: metadata.name
  - name: WALLARM_SYNCNODE_OWNER
    value: www-data
  - name: WALLARM_SYNCNODE_GROUP
    value: www-data
  - name: WALLARM_LABELS
    value: "group={{ .context.Values.config.wallarm.api.nodeGroup }}"
{{- if eq .mode "postanalytics" }}
  - name: SLAB_ALLOC_ARENA
    value: "{{ .context.Values.postanalytics.arena }}"
  - name: WALLARM_WSTORE__SERVICE__ADDRESS
    value: "{{ .context.Values.postanalytics.serviceAddress }}"
  - name: WALLARM_WSTORE__SERVICE__PROTOCOL
    value: "{{ .context.Values.postanalytics.serviceProtocol }}"
  - name: WALLARM_WSTORE__METRICS__LISTEN_ADDRESS
    value: "{{ .context.Values.postanalytics.metrics.listenAddress }}"
  - name: WALLARM_WSTORE__METRICS__PROTOCOL
    value: "{{ .context.Values.postanalytics.metrics.protocol }}"
  {{- if .context.Values.postanalytics.tls.enabled }}
  {{- include "ingress-nginx.wallarmWstoreTlsVariables" .context | nindent 2 }}
  {{- end }}
{{- end }}
{{- if eq .mode "controller" }}
{{- if .context.Values.config.apiFirewall.enabled }}
  - name: APIFW_SPECIFICATION_UPDATE_PERIOD
    value: "{{ .context.Values.config.apiFirewall.config.specificationUpdatePeriod }}"
  - name: API_MODE_UNKNOWN_PARAMETERS_DETECTION
    value: "{{ .context.Values.config.apiFirewall.config.unknownParametersDetection }}"
  - name: APIFW_URL
    value: "http://0.0.0.0:{{ .context.Values.config.apiFirewall.config.mainPort }}"
  - name: APIFW_HEALTH_HOST
    value: "0.0.0.0:{{ .context.Values.config.apiFirewall.config.healthPort }}"
  - name: APIFW_LOG_LEVEL
    value: "{{ .context.Values.config.apiFirewall.config.logLevel }}"
  - name: APIFW_LOG_FORMAT
    value: "{{ .context.Values.config.apiFirewall.config.logFormat }}"
  - name: APIFW_MODE
    value: api
  - name: APIFW_READ_TIMEOUT
    value: 5s
  - name: APIFW_WRITE_TIMEOUT
    value: 5s
  - name: APIFW_READ_BUFFER_SIZE
    value: "{{ .context.Values.config.apiFirewall.readBufferSize | int64 }}"
  - name: APIFW_WRITE_BUFFER_SIZE
    value: "{{ .context.Values.config.apiFirewall.writeBufferSize | int64 }}"
  - name: APIFW_MAX_REQUEST_BODY_SIZE
    value: "{{ .context.Values.config.apiFirewall.maxRequestBodySize | int64 }}"
  - name: APIFW_DISABLE_KEEPALIVE
    value: "{{ .context.Values.config.apiFirewall.disableKeepalive }}"
  - name: APIFW_MAX_CONNS_PER_IP
    value: "{{ .context.Values.config.apiFirewall.maxConnectionsPerIp }}"
  - name: APIFW_MAX_REQUESTS_PER_CONN
    value: "{{ .context.Values.config.apiFirewall.maxRequestsPerConnection }}"
  - name: APIFW_API_MODE_MAX_ERRORS_IN_RESPONSE
    value: "{{ .context.Values.config.apiFirewall.maxErrorsInResponse }}"
  - name: APIFW_API_MODE_DEBUG_PATH_DB
    value: "{{ include "wallarm-apifw.path" .context }}/3/wallarm_api.db"
{{- end }}
{{- end }}
  {{- with .wdConfig.extraEnvs }}
    {{- toYaml . | nindent 2 }}
  {{- end }}
  ports:
  - name: wd-metrics
    containerPort: {{ .context.Values.config.wallarm.wd.metricsPort }}
    protocol: TCP
  - name: wd-health
    containerPort: {{ .context.Values.config.wallarm.wd.healthPort }}
    protocol: TCP
{{- if eq .mode "postanalytics" }}
  - name: wstore
    containerPort: {{ include "ingress-nginx.wallarmPostanalyticsPort" .context }}
    protocol: TCP
{{- end }}
  livenessProbe:
    httpGet:
      path: /health
      port: wd-health
    initialDelaySeconds: {{ .wdConfig.livenessProbe.initialDelaySeconds | default 10 }}
    periodSeconds: {{ .wdConfig.livenessProbe.periodSeconds | default 10 }}
    timeoutSeconds: {{ .wdConfig.livenessProbe.timeoutSeconds | default 3 }}
    successThreshold: {{ .wdConfig.livenessProbe.successThreshold | default 1 }}
    failureThreshold: {{ .wdConfig.livenessProbe.failureThreshold | default 3 }}
  readinessProbe:
    httpGet:
      path: /health
      port: wd-health
    initialDelaySeconds: {{ .wdConfig.readinessProbe.initialDelaySeconds | default 5 }}
    periodSeconds: {{ .wdConfig.readinessProbe.periodSeconds | default 10 }}
    timeoutSeconds: {{ .wdConfig.readinessProbe.timeoutSeconds | default 3 }}
    successThreshold: {{ .wdConfig.readinessProbe.successThreshold | default 1 }}
    failureThreshold: {{ .wdConfig.readinessProbe.failureThreshold | default 3 }}
  volumeMounts:
  - name: wd-config
    mountPath: /etc/wallarm/wd.yaml
    subPath: wd.yaml
    readOnly: true
  - name: wallarm
    mountPath: {{ include "wallarm.path" .context }}
  - name: wallarm-acl
    mountPath: {{ include "wallarm-acl.path" .context }}
  - name: wallarm-token
    mountPath: /secrets/wallarm/token
    subPath: {{ include "nginx-ingress.wallarm.tokenSecretKey" .context }}
    readOnly: true
{{- if eq .mode "controller" }}
  - name: wallarm-apifw
    mountPath: {{ include "wallarm-apifw.path" .context }}
{{- end }}
  {{- with .wdConfig.extraVolumeMounts }}
    {{- toYaml . | nindent 2 }}
  {{- end }}
{{- if .wdConfig.securityContext }}
  securityContext:
{{ toYaml .wdConfig.securityContext | indent 4 }}
{{- else }}
  {{ include "nginx-ingress.wallarm.defaultSecurityContext" (dict "context" .context) | nindent 2 }}
{{- end }}
  {{- with .wdConfig.resources }}
  resources:
    {{- toYaml . | nindent 4 }}
  {{- end }}
{{- end }}

{{/*
Wallarm wd volumes for a pod.
Accepts a dict with:
  - context: the root context (.)
  - configMapName: name of the ConfigMap containing wd.yaml
*/}}
{{- define "nginx-ingress.wallarm.wdVolumes" -}}
- name: wd-config
  configMap:
    name: {{ .configMapName }}
- name: wallarm
  emptyDir: {}
- name: wallarm-acl
  emptyDir: {}
{{ include "ingress-nginx.wallarmTokenVolume" .context }}
{{- end }}

{{/*
Wallarm volumes for controller pod (with wd ConfigMap)
*/}}
{{- define "nginx-ingress.wallarm.volumes" -}}
- name: wd-config
  configMap:
    name: {{ include "nginx-ingress.fullname" . }}-wallarm-controller-wd
- name: wallarm
  emptyDir: {}
- name: wallarm-acl
  emptyDir: {}
- name: wallarm-cache
  emptyDir: {}
{{ include "ingress-nginx.wallarmTokenVolume" . }}
- name: wallarm-apifw
  emptyDir: {}
{{- with .Values.controller.wallarm.extraVolumes }}
  {{- toYaml . | nindent 0 }}
{{- end }}
{{- end }}

{{/*
Wallarm volume mounts for main NGINX container
*/}}
{{- define "nginx-ingress.wallarm.volumeMounts" -}}
- name: wallarm
  mountPath: {{ include "wallarm.path" . }}
- name: wallarm-acl
  mountPath: {{ include "wallarm-acl.path" . }}
- name: wallarm-cache
  mountPath: {{ include "wallarm-cache.path" . }}
{{- if .Values.config.apiFirewall.enabled }}
- name: wallarm-apifw
  mountPath: {{ include "wallarm-apifw.path" . }}
{{- end }}
{{- with .Values.controller.wallarm.extraVolumeMounts }}
  {{- toYaml . | nindent 0 }}
{{- end }}
{{- end }}

{{/*
Create a metrics Service for Wallarm components
*/}}
{{- define "nginx-ingress.wallarm.metricsService" -}}
{{- if .metricsConfig.enabled -}}
apiVersion: v1
kind: Service
metadata:
{{- if .metricsConfig.service.annotations }}
  annotations: {{ toYaml .metricsConfig.service.annotations | nindent 4 }}
{{- end }}
  labels:
    {{- include "nginx-ingress.labels" .context | nindent 4 }}
    app.kubernetes.io/component: {{ .componentSelector }}
  {{- if .metricsConfig.service.labels }}
    {{- toYaml .metricsConfig.service.labels | nindent 4 }}
  {{- end }}
  name: {{ include "nginx-ingress.fullname" .context }}-{{ .serviceSuffix }}-metrics
  namespace: {{ .context.Release.Namespace }}
spec:
  type: {{ .metricsConfig.service.type }}
{{- if .metricsConfig.service.clusterIP }}
  clusterIP: {{ .metricsConfig.service.clusterIP }}
{{- end }}
{{- if .metricsConfig.service.externalIPs }}
  externalIPs: {{ toYaml .metricsConfig.service.externalIPs | nindent 4 }}
{{- end }}
{{- if .metricsConfig.service.loadBalancerIP }}
  loadBalancerIP: {{ .metricsConfig.service.loadBalancerIP }}
{{- end }}
{{- if .metricsConfig.service.loadBalancerSourceRanges }}
  loadBalancerSourceRanges: {{ toYaml .metricsConfig.service.loadBalancerSourceRanges | nindent 4 }}
{{- end }}
{{- if .metricsConfig.service.externalTrafficPolicy }}
  externalTrafficPolicy: {{ .metricsConfig.service.externalTrafficPolicy }}
{{- end }}
  ports:
    - name: {{ .metricsConfig.portName }}
      port: {{ .metricsConfig.service.servicePort }}
      protocol: TCP
      targetPort: {{ .metricsConfig.portName }}
    {{- $setNodePorts := (or (eq .metricsConfig.service.type "NodePort") (eq .metricsConfig.service.type "LoadBalancer")) }}
    {{- if (and $setNodePorts (not (empty .metricsConfig.service.nodePort))) }}
      nodePort: {{ .metricsConfig.service.nodePort }}
    {{- end }}
  selector:
    {{- include "nginx-ingress.selectorLabels" .context | nindent 4 }}
    app.kubernetes.io/component: {{ .componentSelector }}
{{- end }}
{{- end -}}

{{/*
Create a ServiceMonitor for Wallarm components
*/}}
{{- define "nginx-ingress.wallarm.serviceMonitor" -}}
{{- if and .metricsConfig.enabled .metricsConfig.serviceMonitor.enabled -}}
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: {{ include "nginx-ingress.fullname" .context }}-{{ .monitorSuffix }}
  {{- if .metricsConfig.serviceMonitor.namespace }}
  namespace: {{ .metricsConfig.serviceMonitor.namespace }}
  {{- else }}
  namespace: {{ .context.Release.Namespace }}
  {{- end }}
  labels:
    {{- include "nginx-ingress.labels" .context | nindent 4 }}
    app.kubernetes.io/component: {{ .componentSelector }}
  {{- if .metricsConfig.serviceMonitor.additionalLabels }}
    {{- toYaml .metricsConfig.serviceMonitor.additionalLabels | nindent 4 }}
  {{- end }}
  {{- if .metricsConfig.serviceMonitor.annotations }}
  annotations:
    {{- toYaml .metricsConfig.serviceMonitor.annotations | nindent 4 }}
  {{- end }}
spec:
  {{- if .metricsConfig.serviceMonitor.namespaceSelector }}
  namespaceSelector:
    {{- toYaml .metricsConfig.serviceMonitor.namespaceSelector | nindent 4 }}
  {{- end }}
  selector:
    matchLabels:
      {{- include "nginx-ingress.selectorLabels" .context | nindent 6 }}
      app.kubernetes.io/component: {{ .componentSelector }}
  endpoints:
  - port: {{ .metricsConfig.portName }}
    path: {{ .metricsConfig.endpointPath | default "/metrics" }}
    interval: {{ .metricsConfig.serviceMonitor.scrapeInterval }}
    {{- if .metricsConfig.serviceMonitor.honorLabels }}
    honorLabels: true
    {{- end }}
    {{- if .metricsConfig.serviceMonitor.relabelings }}
    relabelings: {{ toYaml .metricsConfig.serviceMonitor.relabelings | nindent 4 }}
    {{- end }}
    {{- if .metricsConfig.serviceMonitor.metricRelabelings }}
    metricRelabelings: {{ toYaml .metricsConfig.serviceMonitor.metricRelabelings | nindent 4 }}
    {{- end }}
  {{- if .metricsConfig.serviceMonitor.targetLabels }}
  targetLabels: {{ toYaml .metricsConfig.serviceMonitor.targetLabels | nindent 2 }}
  {{- end }}
{{- end }}
{{- end -}}

{{/*
Wallarm postanalytics name (for component selector)
*/}}
{{- define "nginx-ingress.wallarm.postanalyticsName" -}}
wallarm-postanalytics
{{- end -}}

{{/*
Convert camelCase to kebab‑case
*/}}
{{- define "wallarm.kebabcase" -}}
{{- regexReplaceAll "([a-z0-9])([A-Z])" . "${1}-${2}" | lower -}}
{{- end }}

{{/*
Wcli arguments building — used by wd ConfigMaps to construct wcli command with per-job log levels.
*/}}
{{- define "ingress-nginx.wcli-args" -}}
"-log-level", "{{ .logLevel }}",{{ " " }}
{{- with .commands }}
{{- range $jobName, $jobCfg := . }}
"job:{{ $jobName }}",{{ " " }}
{{- range $key, $val := $jobCfg }}
{{- $flag := include "wallarm.kebabcase" $key -}}
{{- if ne $flag "log-level" }}
  {{- $kind := kindOf $val -}}
  {{- if or (eq $kind "map") (eq $kind "slice") }}
"-{{ $flag }}", {{ $val | toJson | quote }},{{ " " }}
  {{- else }}
"-{{ $flag }}", {{ $val | quote }},{{ " " }}
  {{- end }}
{{- end }}
{{- end }}
"-log-level", "{{ $jobCfg.logLevel | default .logLevel }}",{{ " " }}
{{- end }}
{{- end }}
{{- end -}}

{{- define "ingress-nginx.wallarmWstoreTlsVariables" -}}
- name: WALLARM_WSTORE__SERVICE__TLS__ENABLED
  value: "{{ .Values.postanalytics.tls.enabled }}"
- name: WALLARM_WSTORE__SERVICE__TLS__CERT_FILE
  value: "{{ .Values.postanalytics.tls.certFile }}"
- name: WALLARM_WSTORE__SERVICE__TLS__KEY_FILE
  value: "{{ .Values.postanalytics.tls.keyFile }}"
- name: WALLARM_WSTORE__SERVICE__TLS__CA_CERT_FILE
  value: "{{ .Values.postanalytics.tls.caCertFile }}"
- name: WALLARM_WSTORE__SERVICE__TLS__MUTUAL_TLS__ENABLED
  value: "{{ .Values.postanalytics.tls.mutualTLS.enabled }}"
- name: WALLARM_WSTORE__SERVICE__TLS__MUTUAL_TLS__CLIENT_CA_CERT_FILE
  value: "{{ .Values.postanalytics.tls.mutualTLS.clientCACertFile }}"
{{- end -}}

