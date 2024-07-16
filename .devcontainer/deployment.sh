#!/usr/bin/env bash

kubectl create namespace boot-camp-app
kubectl create namespace dynatrace

sed -i "s,API_TOKEN_TO_REPLACE,$DT_OPERATOR_TOKEN," /workspaces/$RepositoryName/dynatrace/dynakube.yaml 
sed -i "s,DATA_INGEST_TOKEN_TO_REPLACE,$DT_DATAINGEST_TOKEN," /workspaces/$RepositoryName/dynatrace/dynakube.yaml  
sed -i "s,TENANT_URL_TO_REPLACE,$DT_URL," /workspaces/$RepositoryName/dynatrace/dynakube.yaml

helm install dynatrace-operator oci://public.ecr.aws/dynatrace/dynatrace-operator \
    --create-namespace \
    --namespace dynatrace \
    --atomic

# Create secret for OneAgent to use
kubectl -n dynatrace create secret generic bootcamp \
  --from-literal=apiToken=$DT_OPERATOR_TOKEN \
  --from-literal=dataIngestToken=$DT_DATAINGEST_TOKEN

# Install full stack cloud native K8s agent
kubectl apply -f /workspaces/$RepositoryName/dynatrace/dynakube.yaml
#sed -i "s,CLUSTER_NAME_TO_REPLACE,bootcamp-dt-demo,"  /workspaces/$RepositoryName/dynatrace/dynakube.yaml

#clusterName=`kubectl config view --minify -o jsonpath='{.clusters[].name}'`
#sed -i "s,{ENTER_YOUR_CLUSTER_NAME},$clusterName,"  /workspaces/$RepositoryName/dynatrace/values.yaml
#sed -i "s,{ENTER_YOUR_INGEST_TOKEN},$DT_LOG_INGEST_TOKEN,"  /workspaces/$RepositoryName/dynatrace/values.yaml

#Extract the tenant name from DT_URL variable
#tenantName=`echo $DT_URL | awk -F "[:,.]" '{print $2}' | cut -c3-`
#sed -i "s,{your-environment-id},$tenantName,"  /workspaces/$RepositoryName/dynatrace/values.yaml

# Deploy Dynatrace
#kubectl -n dynatrace create secret generic dynakube --from-literal="apiToken=$DT_OPERATOR_TOKEN" --from-literal="dataIngestToken=$DT_DATAINGEST_TOKEN"

#wget -O /workspaces/$RepositoryName/dynatrace/kubernetes.yaml https://github.com/Dynatrace/dynatrace-operator/releases/download/v0.15.0/kubernetes.yaml
#wget -O /workspaces/$RepositoryName/dynatrace/kubernetes-csi.yaml https://github.com/Dynatrace/dynatrace-operator/releases/download/v0.15.0/kubernetes-csi.yaml
#sed -i "s,cpu: 300m,cpu: 100m," /workspaces/$RepositoryName/dynatrace/kubernetes.yaml
#sed -i "s,cpu: 300m,cpu: 100m," /workspaces/$RepositoryName/dynatrace/kubernetes-csi.yaml
# Shrink resource utilisation to work on GitHub codespaces (ie. a small environment)
# Apply (slightly) customised manifests
#kubectl apply -f /workspaces/$RepositoryName/dynatrace/kubernetes.yaml
#kubectl apply -f /workspaces/$RepositoryName/dynatrace/kubernetes-csi.yaml
#kubectl -n dynatrace wait pod --for=condition=ready --selector=app.kubernetes.io/name=dynatrace-operator,app.kubernetes.io/component=webhook --timeout=300s
#kubectl -n dynatrace apply -f /workspaces/$RepositoryName/dynatrace/dynakube.yaml

kubectl create secret generic dynatrace-otelcol-dt-api-credentials \
  --from-literal=DT_ENDPOINT=$DT_URL \
  --from-literal=DT_API_TOKEN=$DT_DATAINGEST_TOKEN

helm repo add open-telemetry https://open-telemetry.github.io/opentelemetry-helm-charts
helm repo update
helm upgrade -i dynatrace-collector open-telemetry/opentelemetry-collector -f collector-values.yaml --wait

#install fluentbit for log ingestion
#helm repo add fluent https://fluent.github.io/helm-charts
#helm repo update
#helm install fluent-bit fluent/fluent-bit -f /workspaces/$RepositoryName/dynatrace/values.yaml --create-namespace --namespace dynatrace-fluent-bit

kubectl apply -f deployment/deployment.yaml -n boot-camp-app

# Wait for Dynatrace to be ready
kubectl -n dynatrace wait --for=condition=Ready pod --all --timeout=10m

# Wait for boot-camp-app  application to be ready
kubectl -n boot-camp-app wait --for=condition=Ready pod --all --timeout=10m
