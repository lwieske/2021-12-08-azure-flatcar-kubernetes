#!/usr/bin/env bash

set -x

LOCATION=germanywestcentral

RESOURCE_GROUP=AZURE_FLATCAR_KUBERNETES
VM_NAME=CONTROLLER_NODE_AZURE_VM
VM_IMAGE=kinvolk:flatcar-container-linux-free:stable-gen2:latest
ADMIN_USERNAME=core

set +x
SUBSCRIPTION=$(az account show --query "id" -o tsv)
set -x

echo ${SUBSCRIPTION}

set +x
echo "################################################################################"
echo "### Location Frankfurt"
echo "################################################################################"
set -x

az account list-locations | \
    jq --arg LOCATION $LOCATION -r '.[] | select(.name==$LOCATION)'

set +x
echo "################################################################################"
echo "### Latest Free Kinvolk Flatcar Container Linux for Hypervisor 2"
echo "################################################################################"
set -x

az vm image show \
    --location ${LOCATION} \
    --urn ${VM_IMAGE}

az vm image terms show \
    --publish kinvolk \
    --offer flatcar-container-linux-free \
    --plan stable-gen2
az vm image terms accept \
    --publish kinvolk \
    --offer flatcar-container-linux-free \
    --plan stable-gen2

az group create \
    --name ${RESOURCE_GROUP} \
    --location ${LOCATION}

az vm create \
    --resource-group ${RESOURCE_GROUP} \
    --name ${VM_NAME} \
    --image ${VM_IMAGE} \
    --size Standard_B2s \
    --public-ip-sku Standard \
    --admin-username ${ADMIN_USERNAME} \
    --generate-ssh-keys \
    --no-wait

az vm wait \
    --resource-group ${RESOURCE_GROUP} \
    --name ${VM_NAME} \
    --created

VM_PUBLIC_IP=`az vm list-ip-addresses \
    --resource-group ${RESOURCE_GROUP} \
    --name ${VM_NAME} \
    --query "[].virtualMachine.network.publicIpAddresses[0].ipAddress" \
    --output tsv`

echo "ssh -o StrictHostKeyChecking=no core@${VM_PUBLIC_IP} -tt"

sleep 60

# set +x
# SSH_READY=''
# while [ ! $SSH_READY ]; do
#     echo "### Waiting 10 seconds for SSH"
#     sleep 10
#     set +e
#     OUT=$(ssh -o ConnectTimeout=1 -o StrictHostKeyChecking=no -o BatchMode=yes core@${VM_PUBLIC_IP} 2>&1 | grep 'Permission denied' )
#     [[ $? = 0 ]] && SSH_READY='ready'
#     set -e
# done
# set -x

ssh -o StrictHostKeyChecking=no core@${VM_PUBLIC_IP} -tt <<EOF
set -x
pushd /tmp
curl -sSL \
https://github.com/containerd/containerd/releases/download/v1.5.8/cri-containerd-cni-1.5.8-linux-amd64.tar.gz | \
tar -C . -xz
sudo cp -r etc/cni /etc
sudo cp -r opt/cni /opt
rm -rf etc opt usr
popd
sleep 20
exit
EOF

ssh -o StrictHostKeyChecking=no core@${VM_PUBLIC_IP} -tt <<EOF
set -x
pushd /tmp
curl -sSL --remote-name-all \
https://storage.googleapis.com/kubernetes-release/release/v1.23.0/bin/linux/amd64/{kubeadm,kubectl,kubelet}
sudo cp kube* /opt/bin
sudo chmod ugo+x /opt/bin/kube*
rm kube*
popd
sleep 20
exit
EOF

ssh -o StrictHostKeyChecking=no core@${VM_PUBLIC_IP} -tt <<EOF
set -x
pushd /tmp
cat /etc/systemd/system/containerd.service | \
    sed 's:/sbin/modprobe:/usr/sbin/modprobe:g' | \
    sed 's:/usr/local/bin/containerd:/opt/bin/containerd:g' \
    >containerd.service   
# sudo cp containerd.service /etc/systemd/system/
cat >kubelet.service <<KUBELETEOF
[Unit]
Description=Kubernetes Kubelet
Documentation=https://github.com/kubernetes/kubernetes
After=containerd.service
Requires=containerd.service
[Service]
ExecStart=/opt/bin/kubelet --v=2 --container-runtime=remote --container-runtime-endpoint=unix:///run/containerd/containerd.sock
Restart=on-failure
RestartSec=5
[Install]
WantedBy=multi-user.target
KUBELETEOF
sudo cp kubelet.service   /etc/systemd/system
rm kubeadm-flags.env kubelet.service
popd
sleep 20
exit
EOF

# cat >kubeadm-flags.env <<KUBEADMFLAGSEOF
# KUBELET_KUBEADM_ARGS="--container-runtime=remote --container-runtime-endpoint=/run/containerd/containerd.sock"
# KUBEADMFLAGSEOF
# sudo cp kubeadm-flags.env /var/lib/kubelet/kubeadm-flags.env

ssh -o StrictHostKeyChecking=no core@${VM_PUBLIC_IP} -tt <<EOF
set -x
sudo systemctl daemon-reload
sleep 3
sudo systemctl --now enable containerd
sudo systemctl --now enable kubelet
sleep 3
systemctl is-active containerd
systemctl is-active kubelet
sleep 20
exit
EOF

ssh -o StrictHostKeyChecking=no core@${VM_PUBLIC_IP} -tt <<EOF
set -x
kubeadm version
sleep 20
exit
EOF

# ssh -o StrictHostKeyChecking=no core@${VM_PUBLIC_IP} -tt <<EOF
# set -x
# sudo kubeadm init --upload-certs
# sleep 20
# EOF

az group delete \
    --name ${RESOURCE_GROUP} \
    --no-wait \
    --yes

sleep 20