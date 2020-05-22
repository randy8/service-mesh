#!/usr/bin/env bash

# install service mesh member roll
cat > service-mesh-member-roll.yaml << EOF
---
apiVersion: maistra.io/v1
kind: ServiceMeshMemberRoll
metadata:
  name: default
  namespace: bookretail-istio-system
spec:
  members:
    # a list of projects joined into the service mesh
    - bookinfo
EOF

oc apply -n bookretail-istio-system -f service-mesh-member-roll.yaml

# auto-injection annotation for all deployments
for deployment in $(oc get deployments -o jsonpath='{.items[*].metadata.name}' -n bookinfo)
do
    oc -n bookinfo patch deployment $deployment -p '{"spec":{"template":{"metadata":{"annotations":{"sidecar.istio.io/inject": "true"}}}}}'
done
