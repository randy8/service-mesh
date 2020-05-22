#!/usr/bin/env bash

# create config file for openssl
cat > cert.cfg << EOF
[ req ]
req_extensions     = req_ext
distinguished_name = req_distinguished_name
prompt             = no

[req_distinguished_name]
commonName=$WC

[req_ext]
subjectAltName   = @alt_names

[alt_names]
DNS.1  = $WC
DNS.2  = *.$WC
EOF

# create cert and private key
openssl req -x509 -config cert.cfg -extensions req_ext -nodes -days 730 -newkey rsa:2048 -sha256 -keyout tls.key -out tls.crt

# create secret
oc create secret tls istio-ingressgateway-certs --cert tls.crt --key tls.key -n $SMCP_NS

# restart istio ingress gateway pod
oc patch deployment istio-ingressgateway -p '{"spec":{"template":{"metadata":{"annotations":{"kubectl.kubernetes.io/restartedAt": "'`date +%FT%T%z`'"}}}}}' -n $SMCP_NS 

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
    - "*.$WC"
EOF

# create wildcard gateway
oc create -f wildcard-gateway.yml -n $SMCP_NS
