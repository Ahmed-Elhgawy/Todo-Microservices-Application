#!/bin/bash
kubeadm join 10.0.100.163:6443 --token owfbw2.93m399q66vpnx82v --discovery-token-ca-cert-hash sha256:58613512a0b0f4499ff665fe979b75d942fe09eb7279992b7fafc8a3671dab62  --node-name worker
