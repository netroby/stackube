#!/bin/bash
# Copyright (c) 2017 OpenStack Foundation.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

#
# Dependencies:
#
# - ``KUBERNETES_API_PUBLIC_IP`` 
# - ``CLUSTER_CIDR``, ``CLUSTER_GATEWAY``,
# - ``KEYSTONE_ADMIN_URL``  must be defined
#

programDir=`dirname $0`
programDir=$(readlink -f $programDir)
parentDir="$(dirname $programDir)"
programDirBaseName=$(basename $programDir)

set -o errexit
set -o nounset
set -o pipefail
set -x


## install stackube addons
kubectl -n kube-system delete deployment kube-dns
kubectl -n kube-system delete daemonset kube-proxy

source /etc/stackube/openstack/admin-openrc.sh
netList=`openstack network list --long -f value`
public_network=$(echo "${netList}" | grep External | grep ' public_1 ' | awk '{print $1}')
[ "${public_network}" ]
nnn=`echo "${public_network}" | wc -l`
[ $nnn -eq 1 ]

cinderKeyring=`cat /var/lib/stackube/ceph/ceph_mon_config/ceph.client.cinder.keyring`
keyring=`echo "${cinderKeyring}" | grep 'key = ' | awk -F\ \=\  '{print $2}'`
[ "${keyring}" ]

cat > ${programDir}/stackube-configmap.yaml <<EOF
kind: ConfigMap
apiVersion: v1
metadata:
  name: stackube-config
  namespace: kube-system
data:
  auth-url: "${KEYSTONE_ADMIN_URL}"
  username: "admin"
  password: "${OS_PASSWORD}"
  tenant-name: "admin"
  region: "RegionOne"
  ext-net-id: "${public_network}"
  plugin-name: "ovs"
  integration-bridge: "br-int"
  user-cidr: "${CLUSTER_CIDR}"
  user-gateway: "${CLUSTER_GATEWAY}"
  kubernetes-host: "${KUBERNETES_API_PUBLIC_IP}"
  kubernetes-port: "6443"
  keyring: "${keyring}"
EOF
kubectl create -f ${programDir}/stackube-configmap.yaml 
kubectl create -f ${programDir}/../../deployment/stackube.yaml
kubectl create -f ${programDir}/../../deployment/stackube-proxy.yaml
kubectl create -f ${programDir}/../../deployment/flexvolume/flexvolume-ds.yaml




exit 0
