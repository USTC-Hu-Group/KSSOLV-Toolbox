#!/usr/bin/env python3
"""Build/deploy the portal without Helm, pip, generated native code or JVM."""
import argparse
import hashlib
import ipaddress
import json
import os
from pathlib import Path
import re
import secrets
import subprocess
import sys
from urllib.parse import urlsplit
sys.path.insert(0, str(Path(__file__).resolve().parents[2] / 'server' / 'portal'))
from profiles import profiles
from manuals import build_context


def manifests(config, portal_image):
    config_json = json.dumps(config, sort_keys=True)
    config_checksum = hashlib.sha256(config_json.encode()).hexdigest()
    config_name = 'portal-config-' + config_checksum[:32]
    namespace = config["system_namespace"]
    labels = {"app.kubernetes.io/managed-by": "kssolv-portal"}
    def obj(api, kind, name, namespaced=True, **fields):
        metadata = {"name": name, "labels": labels}
        if namespaced: metadata["namespace"] = namespace
        return dict(apiVersion=api, kind=kind, metadata=metadata, **fields)
    return [
        obj("v1", "Namespace", namespace, False),
        obj("v1", "ServiceAccount", "portal"),
        obj("rbac.authorization.k8s.io/v1", "ClusterRole", "kssolv-portal-controller", False, rules=[
            {"apiGroups": [""], "resources": ["namespaces"], "verbs": ["get", "create"]},
            {"apiGroups": [""], "resources": ["secrets", "services"], "verbs": ["create"]},
            {"apiGroups": [""], "resources": ["persistentvolumeclaims"], "verbs": ["get", "create"]},
            {"apiGroups": [""], "resources": ["pods"], "verbs": ["list"]},
            {"apiGroups": [""], "resources": ["resourcequotas"], "verbs": ["create", "patch"]},
            {"apiGroups": ["apps"], "resources": ["deployments"], "verbs": ["get", "create", "patch"]},
            {"apiGroups": ["apps"], "resources": ["deployments/scale"], "verbs": ["patch"]},
            {"apiGroups": ["networking.k8s.io"], "resources": ["networkpolicies"], "verbs": ["create", "patch"]}]),
        obj("rbac.authorization.k8s.io/v1", "ClusterRoleBinding", "kssolv-portal-controller", False,
            roleRef={"apiGroup": "rbac.authorization.k8s.io", "kind": "ClusterRole", "name": "kssolv-portal-controller"},
            subjects=[{"kind": "ServiceAccount", "name": "portal", "namespace": namespace}]),
        obj("v1", "ConfigMap", config_name, immutable=True, data={"config.json": config_json}),
        obj("v1", "PersistentVolumeClaim", "accounts", spec={"accessModes": ["ReadWriteOnce"],
            "storageClassName": config["storage_class"], "resources": {"requests": {"storage": "1Gi"}}}),
        obj("apps/v1", "Deployment", "portal", spec={"replicas": 1, "strategy": {"type": "Recreate"},
            "selector": {"matchLabels": {"app": "kssolv-portal"}}, "template": {
                "metadata": {"labels": {"app": "kssolv-portal"}, "annotations": {
                    "checksum/config": config_checksum}}, "spec": {
                    "serviceAccountName": "portal", "securityContext": {"runAsUser": 10001, "runAsGroup": 10001,
                        "runAsNonRoot": True, "fsGroup": 10001, "seccompProfile": {"type": "RuntimeDefault"}},
                    "containers": [{"name": "portal", "image": portal_image, "imagePullPolicy": config["pull_policy"],
                        "ports": [{"containerPort": 8080}], "env": [{"name": "REGISTRATION_CODE", "valueFrom": {
                            "secretKeyRef": {"name": "registration", "key": "code"}}}, {"name":"KSSOLV_ADMIN_BRIDGE_TOKEN","valueFrom":{"secretKeyRef":{"name":"admin-bridge","key":"token","optional":True}}}],
                        "securityContext": {"allowPrivilegeEscalation": False, "readOnlyRootFilesystem": True,
                            "capabilities": {"drop": ["ALL"]}},
                        "resources": {"requests": {"cpu": "100m", "memory": "128Mi"},
                                      "limits": {"cpu": "2", "memory": "1Gi"}},
                        "volumeMounts": [{"name": "data", "mountPath": "/data"}, {"name": "tmp", "mountPath": "/tmp"},
                                         {"name": "config", "mountPath": "/etc/kssolv", "readOnly": True}],
                        "readinessProbe": {"httpGet": {"path": "/healthz", "port": 8080}, "periodSeconds": 5},
                        "livenessProbe": {"httpGet": {"path": "/healthz", "port": 8080}, "initialDelaySeconds": 15,
                                          "periodSeconds": 15, "failureThreshold": 3}}],
                    "volumes": [{"name": "data", "persistentVolumeClaim": {"claimName": "accounts"}},
                                {"name": "tmp", "emptyDir": {"sizeLimit": "1Gi"}},
                                {"name": "config", "configMap": {"name": config_name}}]}}}),
        obj("v1", "Service", "portal", spec={"type": "NodePort", "selector": {"app": "kssolv-portal"},
            "ports": [{"name": "http", "port": 8080, "targetPort": 8080, "nodePort": config["node_port"]}]})]


def parse_args(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--context", required=True, help="Explicit kubectl context; never changes the user's default context")
    parser.add_argument("--origin", default=os.environ.get("KSSOLV_PUBLIC_ORIGIN", "http://kssolv-k8s.localhost:18130"),
                        help="Public origin without a path; defaults to KSSOLV_PUBLIC_ORIGIN or the localhost test origin")
    parser.add_argument("--tenant-domain", default=os.environ.get("KSSOLV_TENANT_DOMAIN"),
                        help="Tenant DNS suffix without '*.'; defaults to KSSOLV_TENANT_DOMAIN or the portal hostname")
    parser.add_argument("--trusted-proxy", action="append", default=[], metavar="CIDR",
                        help="Trusted TLS edge address/CIDR as seen by portal nginx; repeat for multiple proxies")
    parser.add_argument("--runtime-image", default="kssolv-toolbox:files-browser")
    parser.add_argument("--portal-image", default="kssolv-portal:20261018-15")
    parser.add_argument("--profile-config",type=Path,help="JSON object with small, medium and large CPU/memory sizes")
    parser.add_argument("--storage-class", default="standard")
    parser.add_argument("--storage", default="20Gi")
    parser.add_argument("--cpu", default="4")
    parser.add_argument("--memory", default="52Gi")
    parser.add_argument("--idle-seconds", type=int, default=1800)
    parser.add_argument("--max-running", type=int, default=2)
    parser.add_argument("--max-users", type=int, default=100)
    parser.add_argument("--node-port", type=int, default=30088)
    parser.add_argument("--secrets-dir", type=Path, required=True, help="Private directory outside the repository")
    parser.add_argument("--build", action="store_true")
    parser.add_argument("--manual-zh", type=Path, help="Optional Chinese PDF; omit to use the latest GitHub Release")
    parser.add_argument("--manual-en", type=Path, help="Optional English PDF; omit to use the latest GitHub Release")
    parser.add_argument("--kind-cluster", help="Optionally load both images into an existing kind cluster")
    parser.add_argument("--accept-runtime-license", action="store_true")
    parser.add_argument("--wait", action="store_true")
    args = parser.parse_args(argv)
    origin = urlsplit(args.origin)
    if (origin.scheme not in ("http", "https") or not re.fullmatch(r"[a-z0-9][a-z0-9.-]*", origin.hostname or "")
            or origin.path or origin.query or origin.fragment or origin.username):
        parser.error("Use an http(s) origin with a DNS hostname and no path")
    if origin.scheme == "http" and not origin.hostname.endswith(".localhost"):
        parser.error("Public password authentication requires HTTPS; .localhost may use an SSH tunnel")
    if args.tenant_domain and not re.fullmatch(r'[a-z0-9][a-z0-9.-]*',args.tenant_domain):
        parser.error('Tenant domain must be a trusted DNS hostname without a scheme or port')
    try:
        args.trusted_proxy = [str(ipaddress.ip_network(value, strict=False)) for value in args.trusted_proxy]
    except ValueError:
        parser.error('--trusted-proxy requires an IP address or CIDR, never a hostname')
    if not args.accept_runtime_license: parser.error("Review the MathWorks Runtime license and pass --accept-runtime-license")
    if args.idle_seconds < 30 or args.max_running < 1 or args.max_users < 1 or not 30000 <= args.node_port <= 32767:
        parser.error("Invalid capacity, idle timeout or NodePort")
    for value in (args.runtime_image, args.portal_image):
        if value.endswith(":latest") or ":" not in value: parser.error("Use a versioned image tag or digest")
    return args


def portal_config(args):
    sizes=profiles({"workspace_profiles":json.loads(args.profile_config.read_text())} if args.profile_config else {})
    return {"workspace_profiles":sizes,"origin": args.origin, "tenant_domain": args.tenant_domain or urlsplit(args.origin).hostname,
            "trusted_proxies": args.trusted_proxy,
            "runtime_image": args.runtime_image, "system_namespace": "kssolv-system",
            "pull_policy": "IfNotPresent", "storage_class": args.storage_class, "storage": args.storage,
            "cpu": args.cpu, "memory": args.memory, "idle_seconds": args.idle_seconds,
            "sweep_seconds": 10, "max_running": args.max_running, "max_users": args.max_users,
            "node_port": args.node_port, "runtime_license_accepted": True}


def main():
    args = parse_args()
    root = Path(__file__).resolve().parent
    secret_dir = args.secrets_dir.expanduser().resolve()
    repository = root.parent.parent if root.name == "k8s" and root.parent.name == "scripts" else root
    if secret_dir == repository or repository in secret_dir.parents:
        raise SystemExit("--secrets-dir must be outside the repository")
    secret_dir.mkdir(parents=True, exist_ok=True, mode=0o700)
    secret_dir.chmod(0o700)
    invitation = secret_dir / "registration-code"
    if not invitation.exists():
        invitation.write_text(secrets.token_urlsafe(32))
    invitation.chmod(0o600)
    if len(invitation.read_text().strip()) < 24: raise SystemExit("Registration code is too short")
    config = portal_config(args)
    if args.build:
        with build_context(root, args.manual_zh, args.manual_en) as context:
            subprocess.run(["docker", "build", "--build-arg", "BASE_IMAGE=" + args.runtime_image,
                            "-t", args.portal_image, str(context)], check=True)
    if args.kind_cluster:
        subprocess.run(["kind", "load", "docker-image", "--name", args.kind_cluster,
                        args.runtime_image, args.portal_image], check=True)
    kubectl = ["kubectl", "--context", args.context]
    resources = manifests(config, args.portal_image)
    # Preserve existing namespaces/roles belonging to other applications.
    for kind, name in [("namespace", "kssolv-system"), ("clusterrole", "kssolv-portal-controller"),
                       ("clusterrolebinding", "kssolv-portal-controller")]:
        probe = subprocess.run(kubectl + ["get", kind, name, "--ignore-not-found", "-o", "json"],
                               text=True, capture_output=True, check=True)
        if probe.stdout.strip() and json.loads(probe.stdout)["metadata"].get("labels", {}).get("app.kubernetes.io/managed-by") != "kssolv-portal":
            raise SystemExit(f"Refusing to modify existing {kind}/{name} owned by another application")
    def apply(items):
        subprocess.run(kubectl + ["apply", "-f", "-"],
                       input=json.dumps({"apiVersion": "v1", "kind": "List", "items": items}), text=True, check=True)
    apply(resources[:1])
    # Do not use kubectl apply for Secrets: its last-applied annotation retains the plaintext input.
    secret = subprocess.run(kubectl + ["-n", "kssolv-system", "create", "secret", "generic", "registration",
                            "--from-file=code=" + str(invitation), "--dry-run=client", "-o", "json"],
                            capture_output=True, text=True, check=True)
    exists = subprocess.run(kubectl + ["-n", "kssolv-system", "get", "secret", "registration", "--ignore-not-found", "-o", "name"],
                            capture_output=True, text=True, check=True)
    if not exists.stdout.strip():
        subprocess.run(kubectl + ["create", "-f", "-"], input=secret.stdout, text=True, check=True)
    else:
        import base64
        actual = json.loads(subprocess.check_output(kubectl + ["-n", "kssolv-system", "get", "secret", "registration", "-o", "json"]))
        if base64.b64decode(actual["data"]["code"]).decode() != invitation.read_text().strip():
            raise SystemExit("Existing cluster invitation differs; restore the existing private invitation file before redeploying")
    apply(resources[1:])
    if args.wait:
        subprocess.run(kubectl + ["-n", "kssolv-system", "rollout", "status", "deployment/portal", "--timeout=180s"], check=True)
    print("Portal:", args.origin + '/online')
    print("Private invitation file:", invitation)
    print("Idle timeout:", args.idle_seconds, "seconds; saved tenant volumes are retained.")


if __name__ == "__main__": main()
