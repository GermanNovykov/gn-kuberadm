#!/bin/bash

# Check if the hostname is "master-node"
if [ "$(uname -n)" == "master-node" ]; then
    # Commands specific to master node
    echo "Running on master-node"

    # Create the "monitoring" namespace
    kubectl create namespace monitoring

    # Apply monitoring configurations
    kubectl apply -f /vagrant/combined
    kubectl apply -f /vagrant/kubernetes-prometheus
    kubectl apply -f /vagrant/kube-state-metrics-configs
    kubectl apply -f /vagrant/kubernetes-node-exporter
    kubectl apply -f /vagrant/kubernetes-grafana
else
    # Commands for other nodes
    echo "Not running on master-node"
fi