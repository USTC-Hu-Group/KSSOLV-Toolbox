"""Small Kubernetes REST client and fixed, unprivileged tenant specifications."""
import base64
import hashlib
import json
import os
from pathlib import Path
import re
import secrets
import ssl
from urllib.error import HTTPError
from urllib.request import Request, urlopen


class APIError(RuntimeError):
    def __init__(self, status):
        self.status = status
        super().__init__(f"Kubernetes API returned HTTP {status}")


def tenant_namespace(uid):
    if not re.fullmatch(r"[a-f0-9]{24}", uid):
        raise ValueError("Invalid tenant identity")
    return "kssolv-u-" + uid


def tenant_resources(uid, password, config):
    namespace = tenant_namespace(uid)
    labels = {"app.kubernetes.io/managed-by": "kssolv-portal", "kssolv-user": uid}
    def resource(api, kind, name, **fields):
        return dict(apiVersion=api, kind=kind,
                    metadata=dict(name=name, namespace=namespace, labels=labels), **fields)
    basic = "runtime:{SHA}" + base64.b64encode(hashlib.sha1(password.encode()).digest()).decode() + "\n"
    # This high-entropy machine credential is independent of the user's password.
    secret = resource("v1", "Secret", "runtime-access", type="Opaque",
                      stringData={"htpasswd": basic})
    pvc = resource("v1", "PersistentVolumeClaim", "data", spec={
        "accessModes": ["ReadWriteOnce"],
        "storageClassName": config["storage_class"],
        "resources": {"requests": {"storage": config["storage"]}}})
    service = resource("v1", "Service", "runtime", spec={
        "selector": labels, "ports": [{"port": 8080, "targetPort": 8080}]})
    security = {"runAsUser": 10001, "runAsGroup": 10001, "runAsNonRoot": True,
                "fsGroup": 10001, "seccompProfile": {"type": "RuntimeDefault"}}
    container = {
        "name": "runtime", "image": config["runtime_image"], "imagePullPolicy": config["pull_policy"],
        "ports": [{"containerPort": 8080}],
        "env": [{"name": "AGREE_TO_MATLAB_RUNTIME_LICENSE", "value": "yes"},
                {"name": "KSSOLV_RESOURCE_SCOPE", "value": "pod"},
                {"name": "KSSOLV_ALLOCATED_CPU_MILLICORES", "valueFrom": {"resourceFieldRef": {
                    "containerName": "runtime", "resource": "limits.cpu", "divisor": "1m"}}},
                {"name": "KSSOLV_ALLOCATED_MEMORY_BYTES", "valueFrom": {"resourceFieldRef": {
                    "containerName": "runtime", "resource": "limits.memory", "divisor": "1"}}},
                {"name": "KSSOLV_AUTH_FILE", "value": "/run/secrets/runtime/htpasswd"}],
        "securityContext": {"allowPrivilegeEscalation": False, "readOnlyRootFilesystem": True,
                            "capabilities": {"drop": ["ALL"]}},
        "resources": {"requests": {"cpu": config["cpu"], "memory": config["memory"], "ephemeral-storage": "1Gi"},
                      "limits": {"cpu": config["cpu"], "memory": config["memory"],
                                 "ephemeral-storage": "8Gi"}},
        "volumeMounts": [{"name": "data", "mountPath": "/data"},
                         {"name": "tmp", "mountPath": "/tmp"},
                         {"name": "shm", "mountPath": "/dev/shm"},
                         {"name": "access", "mountPath": "/run/secrets/runtime", "readOnly": True}],
        "startupProbe": {"httpGet": {"path": "/healthz", "port": 8080},
                         "periodSeconds": 5, "failureThreshold": 90},
        "readinessProbe": {"httpGet": {"path": "/healthz", "port": 8080}, "periodSeconds": 5},
        "livenessProbe": {"httpGet": {"path": "/healthz", "port": 8080},
                          "periodSeconds": 15, "failureThreshold": 3}}
    deployment = resource("apps/v1", "Deployment", "runtime", spec={
        "replicas": 1, "strategy": {"type": "Recreate"}, "selector": {"matchLabels": labels},
        "template": {"metadata": {"labels": labels}, "spec": {
            "automountServiceAccountToken": False, "securityContext": security,
            "terminationGracePeriodSeconds": 25, "containers": [container],
            "volumes": [{"name": "data", "persistentVolumeClaim": {"claimName": "data"}},
                        {"name": "tmp", "emptyDir": {"medium": "Memory", "sizeLimit": "4Gi"}},
                        {"name": "shm", "emptyDir": {"medium": "Memory", "sizeLimit": "512Mi"}},
                        {"name": "access", "secret": {"secretName": "runtime-access", "defaultMode": 0o440}}]}}})
    system = {"kubernetes.io/metadata.name": config["system_namespace"]}
    policy = resource("networking.k8s.io/v1", "NetworkPolicy", "tenant-isolation", spec={
        "podSelector": {}, "policyTypes": ["Ingress", "Egress"],
        "ingress": [{"from": [{"namespaceSelector": {"matchLabels": system},
                               "podSelector": {"matchLabels": {"app": "kssolv-portal"}}}],
                     "ports": [{"protocol": "TCP", "port": 8080}]}],
        "egress": [
            {"to": [{"namespaceSelector": {"matchLabels": {"kubernetes.io/metadata.name": "kube-system"}},
                     "podSelector": {"matchLabels": {"k8s-app": "kube-dns"}}}],
             "ports": [{"protocol": "UDP", "port": 53}, {"protocol": "TCP", "port": 53}]},
            {"to": [{"ipBlock": {"cidr": "0.0.0.0/0", "except": [
                "0.0.0.0/8", "10.0.0.0/8", "100.64.0.0/10", "127.0.0.0/8", "169.254.0.0/16",
                "172.16.0.0/12", "192.168.0.0/16", "224.0.0.0/4", "240.0.0.0/4"]}}],
             "ports": [{"protocol": "TCP", "port": 80}, {"protocol": "TCP", "port": 443}]}]})
    quota = resource("v1", "ResourceQuota", "tenant", spec={"hard": {
        "pods": "1", "persistentvolumeclaims": "1", "requests.storage": config["storage"],
        "limits.cpu": config["cpu"], "limits.memory": config["memory"]}})
    return namespace, [quota, policy, secret, pvc, service, deployment]


class Kubernetes:
    def __init__(self, config):
        self.config = config
        self.token_file = Path("/var/run/secrets/kubernetes.io/serviceaccount/token")
        self.context = ssl.create_default_context(cafile="/var/run/secrets/kubernetes.io/serviceaccount/ca.crt")
        self.base = "https://" + os.environ["KUBERNETES_SERVICE_HOST"] + ":" + os.environ["KUBERNETES_SERVICE_PORT"]

    def request(self, method, path, data=None):
        request = Request(self.base + path, method=method,
                          data=None if data is None else json.dumps(data).encode(),
                          headers={"Authorization": "Bearer " + self.token_file.read_text().strip(),
                                   "Content-Type": "application/merge-patch+json" if method == "PATCH" else "application/json"})
        try:
            with urlopen(request, context=self.context, timeout=12) as response:
                return json.load(response)
        except HTTPError as error:
            raise APIError(error.code) from None

    def ensure(self, uid, password, *, restart=False, resources=None):
        namespace, resources = tenant_resources(uid, password, {**self.config,**(resources or {})})
        if restart:
            # Changing the template guarantees replacement even if scale-down
            # has not yet been observed; the same PVC remains mounted.
            deployment = next(item for item in resources if item['kind'] == 'Deployment')
            deployment['spec']['template']['metadata']['annotations'] = {
                'kssolv-restart': secrets.token_hex(16)}
        path = "/api/v1/namespaces/" + namespace
        try:
            self.request("POST", "/api/v1/namespaces", {
                "apiVersion": "v1", "kind": "Namespace", "metadata": {"name": namespace, "labels": {
                    "app.kubernetes.io/managed-by": "kssolv-portal", "kssolv-user": uid,
                    "pod-security.kubernetes.io/enforce": "restricted",
                    "pod-security.kubernetes.io/enforce-version": "latest"}}})
        except APIError as error:
            if error.status != 409: raise
        existing = self.request("GET", path)
        existing_labels = existing["metadata"].get("labels", {})
        if (existing_labels.get("kssolv-user") != uid
                or existing_labels.get("app.kubernetes.io/managed-by") != "kssolv-portal"):
            raise ValueError("Refusing a namespace not owned by this tenant")
        plurals = {"Secret": "secrets", "Service": "services", "Deployment": "deployments",
                   "PersistentVolumeClaim": "persistentvolumeclaims", "NetworkPolicy": "networkpolicies",
                   "ResourceQuota": "resourcequotas"}
        for item in resources:
            api = item["apiVersion"]
            collection = ("/api/v1" if api == "v1" else "/apis/" + api) + "/namespaces/" + namespace + "/" + plurals[item["kind"]]
            if item["kind"] == "PersistentVolumeClaim":
                # ResourceQuota admission can reject a duplicate POST before
                # Kubernetes checks AlreadyExists. Reuse the existing claim.
                try:
                    claim = self.request("GET", collection + "/data")
                    if claim["metadata"].get("labels", {}).get("kssolv-user") != uid:
                        raise ValueError("Refusing a PVC not owned by this tenant")
                    continue
                except APIError as error:
                    if error.status != 404: raise
            try:
                self.request("POST", collection, item)
            except APIError as error:
                if error.status != 409: raise
                if item["kind"] == "Deployment":
                    self.request("PATCH", collection + "/runtime", {"spec": item["spec"]})
                elif item["kind"] in ("ResourceQuota", "NetworkPolicy"):
                    self.request("PATCH", collection + "/" + item["metadata"]["name"], {"spec": item["spec"]})

    def stop(self, uid):
        try:
            self.request("PATCH", "/apis/apps/v1/namespaces/" + tenant_namespace(uid) + "/deployments/runtime/scale",
                         {"spec": {"replicas": 0}})
        except APIError as error:
            if error.status != 404: raise

    def ready(self, uid):
        try:
            item = self.request("GET", "/apis/apps/v1/namespaces/" + tenant_namespace(uid) + "/deployments/runtime")
        except APIError as error:
            if error.status == 404: return False
            raise
        status = item.get("status", {})
        return (item["spec"]["replicas"] == 1 and status.get("availableReplicas", 0) == 1
                and status.get("updatedReplicas", 0) == 1
                and status.get("observedGeneration", 0) >= item["metadata"]["generation"])

    def instance(self, uid):
        selector = "app.kubernetes.io%2Fmanaged-by%3Dkssolv-portal%2Ckssolv-user%3D" + uid
        try:
            items = self.request("GET", "/api/v1/namespaces/" + tenant_namespace(uid)
                                 + "/pods?labelSelector=" + selector).get("items", [])
        except APIError as error:
            if error.status == 404: return ""
            raise
        identities = []
        for pod in items:
            if pod["metadata"].get("deletionTimestamp"): continue
            for container in pod.get("status", {}).get("containerStatuses", []):
                if (container["name"] == "runtime" and container.get("ready")
                        and container.get("state", {}).get("running") is not None
                        and container.get("containerID")):
                    identity = pod["metadata"]["uid"] + "/" + container["containerID"]
                    identities.append(hashlib.sha256(identity.encode()).hexdigest())
        return identities[0] if len(identities) == 1 else ""
