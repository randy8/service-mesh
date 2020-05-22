#!/usr/bin/env bash

# install service mesh member roll
cat > service-mesh-member-roll.yml << EOF
---
apiVersion: maistra.io/v1
kind: ServiceMeshMemberRoll
metadata:
  name: default
  namespace: $SMCP_NS
spec:
  members:
  - bookinfo
EOF

oc apply -f service-mesh-member-roll.yml -n $SMCP_NS

# auto-injection annotation for all deployments
for i in $(oc get deployment -n $PROJ | grep -v NAME | awk '{print $1}') 
do 
    oc patch deployment $i -p "{\"spec\": { \"template\": { \"metadata\": { \"annotations\": { \"sidecar.istio.io/inject\": \"true\"}}}}}" -n $PROJ
done
