#!/usr/bin/env bash

# create config file for openssl
cat > cert.cfg << EOF
[ req ]
req_extensions     = req_ext
distinguished_name = req_distinguished_name
prompt             = no

[req_distinguished_name]
commonName=apps.cluster-8d9a.8d9a.sandbox629.opentlc.com

[req_ext]
subjectAltName   = @alt_names

[alt_names]
DNS.1  = apps.cluster-8d9a.8d9a.sandbox629.opentlc.com
DNS.2  = *.apps.cluster-8d9a.8d9a.sandbox629.opentlc.com
EOF

# create cert and private key
openssl req -x509 -config cert.cfg -extensions req_ext -nodes -days 730 -newkey rsa:2048 -sha256 -keyout tls.key -out tls.crt

# create secret
oc create secret tls istio-ingressgateway-certs --cert tls.crt --key tls.key -n bookretail-istio-system

# restart istio ingress gateway pod
oc patch deployment istio-ingressgateway -p '{"spec":{"template":{"metadata":{"annotations":{"kubectl.kubernetes.io/restartedAt": "'`date +%FT%T%z`'"}}}}}' -n bookretail-istio-system

# define the wildcard gateway
cat > wildcard-gateway.yml << EOF
apiVersion: networking.istio.io/v1alpha3
kind: Gateway
metadata:
  name: bookinfo-wildcard-gateway
spec:
  selector:
    istio: ingressgateway # use istio default controller
  servers:
  - port:
      number: 443
      name: https
      protocol: HTTPS
    tls:
      mode: SIMPLE
      privateKey: /etc/istio/ingressgateway-certs/tls.key
      serverCertificate: /etc/istio/ingressgateway-certs/tls.crt
    hosts:
    - "*.apps.cluster-8d9a.8d9a.sandbox629.opentlc.com"
EOF

# create wildcard gateway
oc create -f wildcard-gateway.yml -n bookretail-istio-system

####################################################################
# create virtualservice
cat > virtualservice.yml << EOF  
---
apiVersion: networking.istio.io/v1alpha3
kind: VirtualService
metadata:
  name: productpage-virtualservice
spec:
  hosts:
  - productpage.bookinfo.apps.cluster-8d9a.8d9a.sandbox629.opentlc.com
  gateways:
  - bookinfo-wildcard-gateway.bookretail-istio-system.svc.cluster.local
  http:
  - match:
    - uri:
        prefix: /
    route:
    - destination:
        port:
          number: 9080
        host: productpage.bookinfo.svc.cluster.local
EOF

oc create -f virtualservice.yml -n bookinfo

# create policies
for i in details productpage ratings reviews
do
cat > $i-policy.yml << EOF 
---
apiVersion: authentication.istio.io/v1alpha1
kind: Policy
metadata:
  name: $i-policy
spec:
  peers:
  - mtls:
      mode: STRICT
  targets:
  - name: reviews
EOF
oc create -f $i-policy.yml -n bookinfo
done

# create destinationrule
for i in details productpage ratings reviews
do
cat > $i-destination-rule.yml << EOF 
---
apiVersion: networking.istio.io/v1alpha3
kind: DestinationRule
metadata:
  name: $i-destination-rule
spec:
  host: $i.bookinfo.svc.cluster.local
  trafficPolicy:
    tls:
      mode: ISTIO_MUTUAL
EOF
oc create -f  $i-destination-rule.yml -n bookinfo
done

# create route 
cat > service-gateway.yml << EOF 
---
apiVersion: route.openshift.io/v1
kind: Route
metadata:
  annotations:
    openshift.io/host.generated: 'true'
  labels:
    app: productpage
  name: productpage-route
spec:
  host: productpage.bookinfo.apps.cluster-8d9a.8d9a.sandbox629.opentlc.com
  port:
    targetPort: https
  tls:
    termination: passthrough
  to:
    kind: Service
    name: istio-ingressgateway
    weight: 100
  wildcardPolicy: None
EOF

oc create -f service-gateway.yml -n bookretail-istio-system


