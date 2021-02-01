# Kubernetes Node Packer Template
This folder contains a packer template that builds a Kubernetes node. The resulting image contains the following:
- `kubelet`, `kubeadm` and `kubectl`
- The container runtime `cri-o`

## Building the Image
Build the image using the following command:
```shell
packer build -var version=v1.19.0 -var token=<Hetzner Cloud Token> .
```
Build images containing newer versions of Kubernetes by changing the version number.

## Caveats
In production clusters you probably want to create your own images. This image has some notable caveats:
- No automatic updates of system components.
- No secure SSH configuration (i.e. root access and password authentication remain enabled)
- No debugging tools (`crictl`)

Many clusters also use specialized distributions such as Flatcar Linux for the nodes so take this packer template for
what it is: An example to get you started.
