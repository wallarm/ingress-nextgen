//go:build helmunit

package test

import (
	"os"
	"path/filepath"
	"regexp"
	"sort"
	"strings"
	"testing"

	"github.com/gkampitakis/go-snaps/snaps"
	"github.com/gruntwork-io/terratest/modules/helm"
	"github.com/gruntwork-io/terratest/modules/k8s"
	"gopkg.in/yaml.v3"
)

// chartMeta holds the version fields from Chart.yaml that change on every release.
type chartMeta struct {
	Version    string `yaml:"version"`
	AppVersion string `yaml:"appVersion"`
}

// readChartMeta reads Chart.yaml and returns its version fields.
func readChartMeta(t *testing.T, chartPath string) chartMeta {
	t.Helper()
	data, err := os.ReadFile(filepath.Join(chartPath, "Chart.yaml"))
	if err != nil {
		t.Fatalf("failed to read Chart.yaml: %v", err)
	}
	var meta chartMeta
	if err := yaml.Unmarshal(data, &meta); err != nil {
		t.Fatalf("failed to parse Chart.yaml: %v", err)
	}
	return meta
}

// checksumAnnotationRE matches pod-template `checksum/<name>: <sha256>` annotations
// (e.g. checksum/wd-config, checksum/token) whose hash changes on any tweak to the
// hashed template — the underlying ConfigMap/Secret content is in the snapshot
// already, so the hash adds no coverage.
var checksumAnnotationRE = regexp.MustCompile(`(checksum/[a-zA-Z0-9_.-]+:\s+)[a-f0-9]{64}`)

// sanitize normalizes volatile fields in helm-rendered output so snapshots don't
// churn on every version bump or template edit:
//   - chart/app versions are replaced with CHART_VERSION / APP_VERSION placeholders
//     (word-boundary matched to avoid touching unrelated substrings like "7.0.0"
//     inside "127.0.0.1")
//   - checksum/* pod-template annotation hashes are replaced with SHA256
//
// When one version string is a prefix of the other (e.g. chart 7.0.0 and
// appVersion 7.0.0-rc1, where `\b` matches at the `-`), the longer match is
// substituted first so the shorter one cannot truncate it into a corrupted
// placeholder like "CHART_VERSION-rc1".
func sanitize(output string, meta chartMeta) string {
	type repl struct{ value, placeholder string }
	repls := []repl{
		{meta.Version, "CHART_VERSION"},
		{meta.AppVersion, "APP_VERSION"},
	}
	sort.SliceStable(repls, func(i, j int) bool {
		return len(repls[i].value) > len(repls[j].value)
	})
	for _, r := range repls {
		if r.value == "" {
			continue
		}
		re := regexp.MustCompile(`(?:^|(?:\b))` + regexp.QuoteMeta(r.value) + `(?:\b|$)`)
		output = re.ReplaceAllString(output, r.placeholder)
	}
	output = checksumAnnotationRE.ReplaceAllString(output, "${1}SHA256")
	return output
}

func TestMain(m *testing.M) {
	code := m.Run()

	// After all tests have run `go-snaps` will sort snapshots
	snaps.Clean(m, snaps.CleanOpts{Sort: true})

	os.Exit(code)
}

// An example of how to verify the rendered template object of a Helm Chart given various inputs.
func TestHelmNICTemplate(t *testing.T) {
	t.Parallel()

	tests := map[string]struct {
		valuesFile  string
		releaseName string
		namespace   string
	}{
		"default values file": {
			valuesFile:  "",
			releaseName: "default",
			namespace:   "default",
		},
		"deployment-hpa": {
			valuesFile:  "testdata/deployment-hpa.yaml",
			releaseName: "deployment-hpa",
			namespace:   "default",
		},
		"deployment-hpa-no-create": {
			valuesFile:  "testdata/deployment-hpa-no-create.yaml",
			releaseName: "deployment-hpa-no-create",
			namespace:   "default",
		},
		"daemonset": {
			valuesFile:  "testdata/daemonset.yaml",
			releaseName: "daemonset",
			namespace:   "default",
		},
		"daemonset-readonly": {
			valuesFile:  "testdata/daemonset-readonly.yaml",
			releaseName: "daemonset-readonly",
			namespace:   "default",
		},
		"namespace": {
			valuesFile:  "",
			releaseName: "namespace",
			namespace:   "nginx-ingress",
		},
		"plus": {
			valuesFile:  "testdata/plus.yaml",
			releaseName: "plus",
			namespace:   "default",
		},
		"plus-debug": {
			valuesFile:  "testdata/plus-debug.yaml",
			releaseName: "plus-debug",
			namespace:   "default",
		},
		"plus-mgmt": {
			valuesFile:  "testdata/plus-mgmt.yaml",
			releaseName: "plus-mgmt",
			namespace:   "default",
		},
		"plus-mgmt-custom-endpoint": {
			valuesFile:  "testdata/plus-mgmt-custom-endpoint.yaml",
			releaseName: "plus-mgmt-custom-endpoint",
			namespace:   "default",
		},
		"plus-mgmt-proxy-host": {
			valuesFile:  "testdata/plus-mgmt-proxy-host.yaml",
			releaseName: "plus-mgmt-proxy-host",
			namespace:   "default",
		},
		"plus-mgmt-proxy-host-auth": {
			valuesFile:  "testdata/plus-mgmt-proxy-host-auth.yaml",
			releaseName: "plus-mgmt-proxy-host-auth",
			namespace:   "default",
		},
		"ingressClass": {
			valuesFile:  "testdata/ingress-class.yaml",
			releaseName: "ingress-class",
			namespace:   "default",
		},
		"globalConfig": {
			valuesFile:  "testdata/global-configuration.yaml",
			releaseName: "global-configuration",
			namespace:   "gc",
		},
		"globalConfigCustomName": {
			valuesFile:  "testdata/global-config-custom-name.yaml",
			releaseName: "global-config-custom-name",
			namespace:   "default",
		},
		"customResources": {
			valuesFile:  "testdata/custom-resources.yaml",
			releaseName: "custom-resources",
			namespace:   "custom-resources",
		},
		"appProtectWAF": {
			valuesFile:  "testdata/app-protect-waf.yaml",
			releaseName: "appprotect-waf",
			namespace:   "appprotect-waf",
		},
		"appProtectWAFV5": {
			valuesFile:  "testdata/app-protect-wafv5.yaml",
			releaseName: "appprotect-wafv5",
			namespace:   "appprotect-wafv5",
		},
		"appProtectDOS": {
			valuesFile:  "testdata/app-protect-dos.yaml",
			releaseName: "appprotect-dos",
			namespace:   "appprotect-dos",
		},
		"ossAgentV3": {
			valuesFile:  "testdata/oss-agentv3.yaml",
			releaseName: "oss-agent",
			namespace:   "default",
		},
		"plusAgentV3": {
			valuesFile:  "testdata/plus-agentv3.yaml",
			releaseName: "plus-agent",
			namespace:   "default",
		},
		"plusAgentV3All": {
			valuesFile:  "testdata/plus-agentv3-all.yaml",
			releaseName: "plus-agent-all",
			namespace:   "custom",
		},
		"appProtectWAFV5AgentV2": {
			valuesFile:  "testdata/app-protect-wafv5-agentv2.yaml",
			releaseName: "app-protect-wafv5-agentv2",
			namespace:   "default",
		},
		"appProtectWAFV5AgentV3": {
			valuesFile:  "testdata/app-protect-wafv5-agentv3.yaml",
			releaseName: "app-protect-wafv5-agentv3",
			namespace:   "default",
		},
		"appProtectWAFV4AgentV2": {
			valuesFile:  "testdata/app-protect-waf-agentv2.yaml",
			releaseName: "app-protect-waf-agentv2",
			namespace:   "default",
		},
		"appProtectWAFV4AgentV3": {
			valuesFile:  "testdata/app-protect-waf-agentv3.yaml",
			releaseName: "app-protect-waf-agentv3",
			namespace:   "default",
		},
		"startupStatusValid": {
			valuesFile:  "testdata/startupstatus-valid.yaml",
			releaseName: "startupstatus",
			namespace:   "default",
		},
		"wallarmEnabled": {
			valuesFile:  "testdata/wallarm-enabled.yaml",
			releaseName: "wallarm-enabled",
			namespace:   "default",
		},
		"wallarmExistingSecret": {
			valuesFile:  "testdata/wallarm-existing-secret.yaml",
			releaseName: "wallarm-existing-secret",
			namespace:   "default",
		},
		"wallarmUSCloud": {
			valuesFile:  "testdata/wallarm-us-cloud.yaml",
			releaseName: "wallarm-us-cloud",
			namespace:   "default",
		},
		"wallarmFull": {
			valuesFile:  "testdata/wallarm-full.yaml",
			releaseName: "wallarm-full",
			namespace:   "wallarm",
		},
		"loadBalancerClass": {
			valuesFile:  "testdata/service-loadbalancerclass.yaml",
			releaseName: "loadbalancerclass",
			namespace:   "default",
		},
		"listConfigurations": {
			valuesFile:  "testdata/list-configurations.yaml",
			releaseName: "list-configs",
			namespace:   "default",
		},
		"allowEmptyIngressHost": {
			valuesFile:  "testdata/allow-empty-ingress-host.yaml",
			releaseName: "allow-empty-ingress-host",
			namespace:   "default",
		},
	}

	// Path to the helm chart we will test
	helmChartPath, err := filepath.Abs("../nginx-ingress")
	if err != nil {
		t.Fatal("Failed to open helm chart path ../nginx-ingress")
	}

	meta := readChartMeta(t, helmChartPath)

	for testName, tc := range tests {
		t.Run(testName, func(t *testing.T) {
			options := &helm.Options{
				KubectlOptions: k8s.NewKubectlOptions("", "", tc.namespace),
			}

			if tc.valuesFile != "" {
				options.ValuesFiles = []string{tc.valuesFile}
			}

			output := helm.RenderTemplate(t, options, helmChartPath, tc.releaseName, make([]string, 0))
			output = sanitize(output, meta)

			snaps.MatchSnapshot(t, output)
			t.Log(output)
		})
	}
}

// Test for negative cases where helm template rendering should fail
func TestHelmNICTemplateNegative(t *testing.T) {
	t.Parallel()

	negativeTests := map[string]struct {
		valuesFile        string
		releaseName       string
		namespace         string
		expectedErrorMsgs []string
	}{
		"startupStatusInvalid": {
			valuesFile:        "testdata/startupstatus-invalid.yaml",
			releaseName:       "startupstatus-invalid",
			namespace:         "default",
			expectedErrorMsgs: []string{"missing properties 'port', 'path'"},
		},
		"globalConfigInvalidFormat": {
			valuesFile:        "testdata/global-config-invalid-format.yaml",
			releaseName:       "global-config-invalid-format",
			namespace:         "default",
			expectedErrorMsgs: []string{"globalConfiguration.customName must contain exactly one '/' separator in namespace/name format (e.g., \"my-namespace/my-global-config\")"},
		},
		"globalConfigMultipleSlashes": {
			valuesFile:        "testdata/global-config-multiple-slashes.yaml",
			releaseName:       "global-config-multiple-slashes",
			namespace:         "default",
			expectedErrorMsgs: []string{"globalConfiguration.customName must contain exactly one '/' separator in namespace/name format (e.g., \"my-namespace/my-global-config\")"},
		},
		"globalConfigEmptyName": {
			valuesFile:        "testdata/global-config-empty-name.yaml",
			releaseName:       "global-config-empty-name",
			namespace:         "default",
			expectedErrorMsgs: []string{"globalConfiguration.customName namespace and name parts cannot be empty (e.g., \"my-namespace/my-global-config\")"},
		},
		"wallarmMissingToken": {
			valuesFile:        "testdata/wallarm-missing-token.yaml",
			releaseName:       "wallarm-missing-token",
			namespace:         "default",
			expectedErrorMsgs: []string{"config.wallarm.api.token is required"},
		},
	}

	// Path to the helm chart we will test
	helmChartPath, err := filepath.Abs("../nginx-ingress")
	if err != nil {
		t.Fatal("Failed to open helm chart path ../nginx-ingress")
	}

	for testName, tc := range negativeTests {
		t.Run(testName, func(t *testing.T) {
			options := &helm.Options{
				KubectlOptions: k8s.NewKubectlOptions("", "", tc.namespace),
			}

			if tc.valuesFile != "" {
				options.ValuesFiles = []string{tc.valuesFile}
			}
			_, err := helm.RenderTemplateE(t, options, helmChartPath, tc.releaseName, make([]string, 0))

			if err == nil {
				t.Fatalf("Expected helm template to fail for invalid configuration, but it succeeded")
			}

			if len(tc.expectedErrorMsgs) > 0 {
				for _, expectedMsg := range tc.expectedErrorMsgs {
					if !strings.Contains(err.Error(), expectedMsg) {
						t.Fatalf("Expected error to contain '%s', but got: %s", expectedMsg, err.Error())
					}
				}
			}

			t.Logf("Expected failure occurred: %s", err.Error())
		})
	}
}

func TestSanitize(t *testing.T) {
	tests := map[string]struct {
		meta chartMeta
		in   string
		want string
	}{
		"both versions independent": {
			meta: chartMeta{Version: "7.0.0", AppVersion: "6.11.0"},
			in:   "chart=7.0.0 app=6.11.0",
			want: "chart=CHART_VERSION app=APP_VERSION",
		},
		"appVersion is prefix-extension of chart version": {
			meta: chartMeta{Version: "7.0.0", AppVersion: "7.0.0-rc1"},
			in:   "image:7.0.0-rc1 chart:7.0.0",
			want: "image:APP_VERSION chart:CHART_VERSION",
		},
		"chart version is prefix-extension of appVersion": {
			meta: chartMeta{Version: "1.2.3-pre", AppVersion: "1.2.3"},
			in:   "v=1.2.3-pre app=1.2.3",
			want: "v=CHART_VERSION app=APP_VERSION",
		},
		"version inside an IP literal is not replaced": {
			meta: chartMeta{Version: "7.0.0", AppVersion: "6.11.0"},
			in:   "127.0.0.1",
			want: "127.0.0.1",
		},
		"checksum annotation hash collapsed": {
			meta: chartMeta{},
			in:   "        checksum/wd-config: " + strings.Repeat("a", 64),
			want: "        checksum/wd-config: SHA256",
		},
		"empty version skipped": {
			meta: chartMeta{Version: "", AppVersion: "1.0.0"},
			in:   "1.0.0",
			want: "APP_VERSION",
		},
	}

	for name, tc := range tests {
		t.Run(name, func(t *testing.T) {
			if got := sanitize(tc.in, tc.meta); got != tc.want {
				t.Errorf("sanitize(%q, %+v)\n  got:  %q\n  want: %q", tc.in, tc.meta, got, tc.want)
			}
		})
	}
}
