#!/bin/bash
# Builds the EKS cluster and deploys everything. Takes ~20-25 minutes.
set -euo pipefail
cd "$(dirname "$0")"

CLUSTER=Three-Tier-K8s-EKS-Cluster
REGION=us-east-1

echo "==> 1/5 Creating cluster, nodes and load balancer IAM role (~15-20 min)"
eksctl create cluster -f cluster.yaml
aws eks update-kubeconfig --region $REGION --name $CLUSTER

echo "==> 2/5 Installing AWS Load Balancer Controller"
VPC_ID=$(aws eks describe-cluster --name $CLUSTER --region $REGION --query 'cluster.resourcesVpcConfig.vpcId' --output text)
helm repo add eks https://aws.github.io/eks-charts >/dev/null 2>&1 || true
helm repo update eks
helm upgrade --install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName=$CLUSTER \
  --set serviceAccount.create=false \
  --set serviceAccount.name=aws-load-balancer-controller \
  --set region=$REGION \
  --set vpcId=$VPC_ID
kubectl rollout status deploy/aws-load-balancer-controller -n kube-system --timeout=5m

echo "==> 3/5 Installing Argo CD"
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
kubectl apply -n argocd --server-side -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
kubectl patch svc argocd-server -n argocd -p '{"spec": {"type": "LoadBalancer"}}'
kubectl rollout status deploy/argocd-server -n argocd --timeout=5m

echo "==> 4/5 Deploying the app (database, backend, frontend, ingress)"
kubectl apply -f argocd-apps.yaml

echo "==> 5/5 Waiting for the app load balancer address"
ALB=""
for i in $(seq 1 60); do
  ALB=$(kubectl get ingress mainlb -n three-tier -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || true)
  [ -n "$ALB" ] && break
  sleep 10
done
ARGO=$(kubectl get svc argocd-server -n argocd -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
ARGO_PASS=$(kubectl get secret argocd-initial-admin-secret -n argocd -o jsonpath='{.data.password}' | base64 -d)

echo ""
echo "================ DONE ================"
echo "Update DNS (DigitalOcean): 3tier-devops  CNAME  ${ALB:-<not ready yet, run: kubectl get ingress -n three-tier>}"
echo "Argo CD:   https://$ARGO   (user: admin  password: $ARGO_PASS)"
echo "App:       http://3tier-devops.princethedev.com   (after DNS update, give it a few minutes)"
