#!/bin/bash
# Deletes the EKS cluster and everything in it, so it stops costing money. Takes ~15 minutes.
set -uo pipefail
cd "$(dirname "$0")"

CLUSTER=Three-Tier-K8s-EKS-Cluster
REGION=us-east-1

read -p "This DELETES the cluster $CLUSTER. Type 'yes' to continue: " ok
[ "$ok" = "yes" ] || { echo "Cancelled."; exit 1; }

aws eks update-kubeconfig --region $REGION --name $CLUSTER

# Load balancers must go first, otherwise they are left behind and keep billing
echo "==> 1/3 Removing Argo CD apps and load balancers"
kubectl delete applications --all -n argocd --wait=false 2>/dev/null
kubectl delete ingress --all -n three-tier --timeout=5m 2>/dev/null
kubectl delete svc argocd-server -n argocd --timeout=5m 2>/dev/null
sleep 60

echo "==> 2/3 Deleting the cluster (~10-15 min)"
eksctl delete cluster -f cluster.yaml --disable-nodegroup-eviction --wait

echo "==> 3/3 Checking nothing is left"
aws eks list-clusters --region $REGION --output text
aws cloudformation list-stacks --region $REGION \
  --stack-status-filter CREATE_COMPLETE UPDATE_COMPLETE DELETE_FAILED ROLLBACK_COMPLETE \
  --query "StackSummaries[?contains(StackName,'$CLUSTER')].[StackName,StackStatus]" --output text
echo "Done. If anything is listed above, see Troubleshooting in README.md"
