---
marp: true
---

<!-- _class: invert -->

## Azure Flatcar + Kubernetes [v1.23.0]

* Towards Multi-Cloud: implement K8S with Flatcar on Microsoft Azure.

* Yesterday evening (December 7, 2021), Kubernetes v1.23.0 was released.

---

## Azure Locations

```
az account list-locations | \
    jq --arg LOCATION germanywestcentral -r '.[] | select(.name==$LOCATION)'
[
  ...
  {
    "displayName": "Germany West Central",
    "id": "/subscriptions/11111111-1111-1111-1111-111111111111/locations/germanywestcentral",
    "metadata": {
      "geographyGroup": "Europe",
      "latitude": "50.110924",
      "longitude": "8.682127",
      "pairedRegion": [
        {
          "id": "/subscriptions/11111111-1111-1111-1111-111111111111/locations/germanynorth",
          "name": "germanynorth",
          "subscriptionId": null
        }
      ],
      "physicalLocation": "Frankfurt",
      "regionCategory": "Recommended",
      "regionType": "Physical"
    },
    "name": "germanywestcentral",
    "regionalDisplayName": "(Europe) Germany West Central",
    "subscriptionId": null
  }
  ...
]
```

* Microsoft Azure offers a convenient way to find out details of the chosen location ...

---

## Finding and Licensing The Flatcar Image

* This demo builds on the *Latest Free Kinvolk Flatcar Container Linux for Hypervisor 2*

* Microsoft for some images requires its users tp accept license terms ...

* The URN looks like sp ... *kinvolk:flatcar-container-linux-free:stable-gen2:latest*

```
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
```

---

## Azure Resource Groups

```
az group create \
    --name ${RESOURCE_GROUP} \
    --location ${LOCATION}
```

---

## Azure VMs

* AWS calls them instance(s), Azure calls them vm(s); its virtual compute.

* Standard_B2s = 2 vCPUs and 4GB vRAM; overall, AWS AND AZ pricing is similar.

```
az vm create \
    --resource-group ${RESOURCE_GROUP} \
    --name ${VM_NAME} \
    --image ${VM_IMAGE} \
    --size Standard_B2s \
    --public-ip-sku Standard \
    --admin-username ${ADMIN_USERNAME} \
    --generate-ssh-keys \
    --no-wait
```

---

## Azure Networking

* Azure offers rich networking capabilities in general.

* But assigning a public IP to a VM is as simple as:

```
    --public-ip-sku Standard
```

* Finding the assigned public IP for ssh login goes like so:

```
VM_PUBLIC_IP=`az vm list-ip-addresses \
    --resource-group ${RESOURCE_GROUP} \
    --name ${VM_NAME} \
    --query "[].virtualMachine.network.publicIpAddresses[0].ipAddress" \
    --output tsv`
```

---

<!-- _class: invert -->

## Azure Flatcar

* AWS Flatcar has the following already set up ...

  * kubeadm, kubectl, kubelet and

  * cni-plugins

* Azure Flatcar does not have the following already set up ...

  * kubeadm, kubectl, kubelet and

  * cni-plugins

---

<!-- _class: invert -->

## Azure Flatcar (II)

* There is an 

* So, for running *kubeadm init*, we have to install and configure

  * kubeadm, kubectl, kubelet and

  * cni-plugins



---

## Azure Flatcar (III)

* The Kubernetes binaries kubeadm, kubectl, kubelet can be downloaded ...

```
https://storage.googleapis.com/kubernetes-release/release/v1.23.0/bin/linux/amd64/{kubeadm,kubectl,kubelet}
```

* In addition, the CNI plugin binaries can be extracted from here ... 

```
https://github.com/containerd/containerd/releases/download/v1.5.8/cri-containerd-cni-1.5.8-linux-amd64.tar.gz
```

* This large targz ball contains a CNI configuration file */etc/cni/net.d/10-containerd-net.conflist*

---

## Azure Flatcar (IV)

* Another chance to install CNI plugins is by using the much smaller tarball ...

```
https://github.com/containernetworking/plugins/releases/download/v1.0.1/cni-plugins-linux-amd64-v1.0.1.tgz
```

---

## Azure Flatcar (V)

* For a successful configuration, kubelet has to be integrated as a systemd unit.

* So, we habe to generate/adapt as systemd unit files.

  * containerd.service 

  * kubelet.service

* For now, kubelet does not sucessfully start up.

---

<!-- _class: invert -->

## Further Actions

* The problem is not really related to the new Kubernetes version v1.23.0.

* It seems to be more related to the tight integration of docker/containerd.

  * Uninstalling docker/containerd packages is not an option.

    * Flatcar has no package management at all.

  * Building an own containerd installation/configuration is difficult.
  
    * Flatcar accesses major parts of the filesystem in read-only mode.