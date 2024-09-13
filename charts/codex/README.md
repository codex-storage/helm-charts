# Codex Helm Chart

 1. [Description](#description)
 2. [Installation](#installation)
 3. [Deployment strategies](#deployment-strategies)
     - [Knows issues](#knows-issues)
     - [Prettify](#prettify)
 4. [Development](#development)
 5. [To do](#to-do)


## Description

 Codex is a decentralized data storage platform that provides exceptionally strong censorship resistance and durability guarantees.

 Chart will install Codex in Kubernetes and make nodes publicly accessible in the Internet or just for in-cluster testing. For more information please read [Deployment strategies](#deployment-strategies).


## Installation

 > **Note:** Please read [Deployment strategies](#deployment-strategies) before the installation.

 1. Create a namespace
    ```shell
    kubectl create namespace codex-ns
    ```

 2. Create secrets if we would like to pass sensitive data

    Create `codex-eth-provider` secret, a common one for all Codex instances
    ```shell
    secret='apiVersion: v1
    kind: Secret
    metadata:
      name: codex-eth-provider
      namespace: codex-ns
      labels:
        name: codex
    type: Opaque
    stringData:
      CODEX_ETH_PROVIDER: https://mainnet.infura.io/v3/YOUR-API-KEY
    '

    echo $secret | kubectl create -f -
    ```

    Generate ethereum key pair for each replica
    ```shell
    docker run --rm gochain/web3 account create
    ```

    Create `codex-eth-private-key` secret, a common one with separate key for each Codex instance
    ```shell
    secret='apiVersion: v1
    kind: Secret
    metadata:
      name: codex-eth-private-key
      namespace: codex-ns
      labels:
        name: codex
    type: Opaque
    stringData:
      CODEX_ETH_PRIVATE_KEY-1-1: 0x...
      CODEX_ETH_PRIVATE_KEY-2-1: 0x...
    '

    echo $secret | kubectl create -f -
    ```
    > **Note:** Please note, key name should contain Pod index, like `-1-1`, `-2-1` in case of multiple replicas or single replica with `statefulSet.prettify=false` and `-1` in case of single replica.

 3. Create a `codex-api-basic-auth` secret if we would like to expose Codex API via [Ingress NGINX Controller](https://kubernetes.github.io/ingress-nginx/) protected by [basic authentication](https://kubernetes.github.io/ingress-nginx/examples/auth/basic/)
    ```shell
    docker run --rm httpd htpasswd -bnB <username> <password>
    ```
    ```shell
    secret='apiVersion: v1
    kind: Secret
    metadata:
      name: codex-api-basic-auth
      namespace: codex-ns
      labels:
        name: codex-api-basic-auth
    type: Opaque
    stringData:
      auth: >-
        auth file content
    '

    echo $secret | kubectl create -f -
    ```

 4. Refer to the created secrets in the `values.yaml`
    <details>
    <summary>values.yaml</summary>

    ```yaml
    # Replica
    replica:
      count: 2

    # StatefulSet
    statefulSet:
      ordinalsStart: 1

    # Service account
    serviceAccount:
      create: true
      rbac:
        create: true

    # Codex
    codex:
      # In case we would like to pass more than one bootstrap node
      args:
      - codex
      - persistence
      - prover
      - --bootstrap-node=spr:xxx
      - --bootstrap-node=spr:yyy
      env:
        CODEX_LOG_LEVEL: TRACE
        CODEX_METRICS: true
        CODEX_METRICS_ADDRESS: 0.0.0.0
        CODEX_METRICS_PORT: 8008
        CODEX_DATA_DIR: /data
        CODEX_API_BINDADDR: 0.0.0.0
        CODEX_API_PORT: 8080
        CODEX_STORAGE_QUOTA: 18gb
        CODEX_BLOCK_TTL: 1d
        CODEX_BLOCK_MI: 10m
        CODEX_BLOCK_MN: 1000
        # port values will be set dynamically for each replica, base on data from service.transport
        CODEX_LISTEN_ADDRS: /ip4/0.0.0.0/tcp/8070
        CODEX_DISC_IP: 0.0.0.0
        # port value will be set dynamically for each replica, base on data from service.discovery
        CODEX_DISC_PORT: 8090
        # In case of single SPR, you can set it via var
        # CODEX_BOOTSTRAP: "spr:xxx"
        CODEX_MARKETPLACE_ADDRESS: 0x1234567890123456789012345678901234567890
        # file name will be used as a secret name to be mounted to the specified path
        # unique key from `codex-eth-private-key` secret will be used to mach the unique Pod name
        CODEX_ETH_PRIVATE_KEY: /opt/codex-eth-private-key
      extraEnv:
        - name: CODEX_ETH_PROVIDER
          valueFrom:
            secretKeyRef:
              name: codex-eth-provider
              key: CODEX_ETH_PROVIDER

    # Pod ports
    ports:
      api:
        enabled: true
        name: api
        containerPort: 8080
      metrics:
        enabled: true
        name: metrics
        containerPort: 8008
      transport:
        enabled: true
        name: libp2p
        containerPort: 8070
      discovery:
        enabled: true
        name: discovery
        containerPort: 8090

    # Service
    service:
      type:
        - service
        - nodeport
      api:
        enabled: true
        port: 8080
      metrics:
        enabled: true
        name: metrics
        port: 8008
      transport:
        enabled: true
        # 30000-32767
        nodePort: 30500
        nodePortOffset: 10
      discovery:
        # 30000-32767
        enabled: true
        nodePort: 30600
        nodePortOffset: 10

    # Ingress
    ingress:
      enabled: true
      class: nginx
      annotations:
        cert-manager.io/cluster-issuer: "letsencrypt-staging"
        nginx.ingress.kubernetes.io/use-regex: "true"
        nginx.ingress.kubernetes.io/rewrite-target: /$2
        nginx.ingress.kubernetes.io/auth-type: basic
        nginx.ingress.kubernetes.io/auth-secret: codex-api-basic-auth
        nginx.ingress.kubernetes.io/auth-realm: 'Authentication Required - Private Area'
      tls:
        - secretName: api-domain-tld
          hosts:
            - api.domain.tld
      hosts:
        - host: api.domain.tld
          paths:
            - path: /storage
              rewritePath: (/|$)(.*)
              pathType: Prefix
              podName: node

    # Persistence
    persistence:
      enabled: true
      name: data
      size: 20Gi
      retentionPolicy:
        whenDeleted: Delete
    ```
    </details>

    Review and update all settings and pay attention to `codex.env`, `service` and `ingress`. You also may consider to skip the values which [defaults](values.yaml) suit your needs.

 5. Install helm chart
    ```shell
    helm install -f values.yaml -n codex-ns codex ./codex
    ```

 6. Check that your Codex nodes up and running and accessible via Ingress
    ```shell
    # Pods
    kubectl get pods -n codex-ns

    # API
    # storage/node-1
    # storage/node-2

    curl -s -k -u username:password https://api.domain.tld/storage/node-1/api/codex/v1/debug/info | jq -r
    ```

 7. If we need more replicas, we should
    - Update secrets with the keys for new replicas
    - Update values.yaml with required number of replicas - `replica.count`
    - Upgrade release


## Deployment strategies

 For P2P communication, Codex require that transport and discovery ports be accessible for direct connection. In that way we may consider two deployment strategies
 - Private - Codex is accessible only inside the Kubernetes cluster
 - Public - Codex is accessible to any nodes in the Internet

 **Private**

 For private deployment, Codex Pods should announce their private IP's and TCP ports. Because every Pod has unique IP, all Pods can use same TCP/UDP ports which will be directly accessible by other Pods.

 [Name resolution](https://github.com/libp2p/specs/blob/master/addressing/README.md#ip-and-name-resolution) is not yet supported and we can't use [headless service](https://kubernetes.io/docs/concepts/services-networking/service/#headless-services) for P2P communications.

 This type of deployment is mostly useful for in-cluster testing.

 **Public**

 For Public deployment, Codex Pods should announce Public IP of the Kubernetes workers node on which they are running and TCP/UDP ports should be unique, because [NodePort](https://kubernetes.io/docs/concepts/services-networking/service/#type-nodeport) is shared across all nodes in the cluster. This leads to some limitation in case we would like to use a single [StatefulSet](https://kubernetes.io/docs/concepts/workloads/controllers/statefulset/) with replicas > 1, because there is no native way in Kubernetes to assign dynamically Pods TCP/UDP ports per replica.

**Single replica**
 - Single StatefulSet is created and by default with index in the name
 - `ClusterIP` service is used for API and Metrics ports
 - In case of the **Public deployment** type, additionally, `NodePort` service will be created
 - App configuration is done only using `values.yaml` and secrets

**Multiple replicas**
 - **Private deployment**
   - Multiple StatefulSets are created to set unique TCP/UDP Pods ports
   - A separate `ClusterIP` service is created for every Pod API and Metrics ports
   - P2P communication is done directly via Pods IPs
   - App configuration is done using `values.yaml` and secrets

 - **Public deployment**
   - Multiple StatefulSets are created to set unique TCP/UDP Pods ports
   - A separate `ClusterIP` service is created for every Pod API and Metrics ports
   - `NodePort` service is created for every Pod with unique TCP/UDP ports
   - App configuration is done using `values.yaml` and secrets
   - Init container `init-env` is used to pass node `ExternalIP` to Codex container

  Variables, which would be assigned via `init-env` init container will be omitted at StatefulSet level
  ```shell
  # P2P
  CODEX_NAT=<ExternalIP>
  ```
  And to check their values, it would be required to look in to `init-env` Pod logs or Codex Pod files located in `/opt/env` folder
  ```shell
  # init-env container
  kubectl logs -n codex -c init-env codex-1-1

  # Codex container
  kubectl exec -it -n codex-ns -c codex codex-1-1 -- bash -c "cat /opt/env/*"
  ```

  Unique data is passed via ConfigMap/Secrets
  ```shell
  # ConfigMap/Secrets
  CODEX_ETH_PROVIDER=<https://mainnet.infura.io/v3/...>
  CODEX_ETH_PRIVATE_KEY=<0x...>
  CODEX_MARKETPLACE_ADDRESS=<0x...>
  ```
  And we can use a single secrets with unique keys per Pod or multiple secrets with unique name per Pod and refer to the Pod by `-replica_index-pod_index`. This string should be added to the `values.yaml` and will be replaced by Helm with the Pod index. Please see [Installation](#installation) for an example.

> **Note:** Keep in mind, we do not have configuration option to define **Private**/**Public deployment** type and it is defined by the service type we use - `service = private` / `service + nodeport = public`.


### Knows issues
 1. We can deploy just one replica per installation in case of `NodePort`, because
    - In Kubernetes, we can't set different settings for replicas in StatefulSet
    - Even if we can workaround that by passing environment variables via `init-env` container, Pods ports, in the manifest, also should be unique because Codex has `--listen-addrs` and `--disc-port` for P2P communication and they should be same as `NodePort` and unique for every Pod

    We can workaround that by passing unique TCP/UDP ports using init container and port forwarder sidecar and we will consider to implement that later.

    Even if we can use a single StatefulSet for **Private deployment** with `init-env` container to pass unique sensitive data, it was decided to follow same approach as we use for **Public** one. We may consider to change that later.

    This is why, for now, we have an option `replica.count` to generate multiple StatefulSets with unique settings.

 2. When we deploy multiple nodes using single installation, multiple StatefulSets will be created. During release upgrade all of them will be upgraded/restarted almost simultaneously.

 3. Codex erasure codding is working on the main app thread and it results of the failed liveness/readiness probes. This is why we have big values by default for these probes.


### Prettify

 Because we are forced to deploy multiple StatefulSets with unique settings, we add a replica index to their names. As a result we will get names which contains additionally Pod index and this is why we've introduced `prettify` key to the StatefulSet, Service and Ingress and `ordinalsStart` for StatefulSet which affect how these names will looks like.

| Object      | Accept `prettify`  | Single                | Single, `prettify` | Multiple                                       | Multiple, `prettify`                       | Single --> Multiple               |
| ----------- | ------------------ | --------------------- | ------------------ | ---------------------------------------------- | ------------------------------------------ | --------------------------------- |
| StatefulSet | :white_check_mark: | `codex-1`             | `codex`            | `codex-1`<br>`codex-2`                         | `codex-1`<br>`codex-2`                     | Destructive in case of `prettify` |
| Pod         | :x:                | `codex-1-1`           | `codex-1`          | `codex-1-1` <br> `codex-2-1`                   | `codex-1-1` <br> `codex-2-1`               | Destructive in case of `prettify` |
| PVC         | :x:                | `data-codex-1-1`      | `data-codex-1`     | `data-codex-1-1` <br> `data-codex-2-1`         | `data-codex-1-1` <br> `data-codex-2-1`     | Destructive in case of `prettify` |
| Service     | :white_check_mark: | `codex-1-1-nodeport`  | `codex-nodeport`   | `codex-1-1-nodeport` <br> `codex-2-1-nodeport` | `codex-1-nodeport` <br> `codex-2-nodeport` | Non destructive                   |
| Ingress     | :white_check_mark: | `/codex-1-1`          | `/codex`           | `/codex-1-1` <br> `/codex-2-1`                 | `/codex-1` <br> `/codex-2`                 | Non destructive                   |


The idea is to make endpoint appropriate to the StatefulSet name by removing Pod index in case of multiple StatefulSets.

For StatefulSet, `prettify=false` by default, in order to be able to add more replicas without destroying the fist one. With that value, a replica index will be added to the the StatefulSet, even if `replica=1`. If you would like to run just a single replica and have a name without that index, you should set `statefulSet.prettify=false`.


## Development

```shell
# Render chart templates
helm template codex-bootstrap codex -n codex-ns --debug

# Specific template
helm template codex-bootstrap codex -n codex-ns --debug -s templates/service.yaml

# Examine a chart for possible issues
helm lint codex

# Check the manifest
helm install codex --dry-run codex --namespace codex-ns
helm install codex --dry-run=server codex --namespace codex-ns
```


## To do
 1. Make code more reusable.
 2. Check options to deploy a separate Bootstrap node and get its SPR automatically and pass it to Storage nodes, to setup a local fully working environment.
 3. Consider to use a single StatefulSet for **Private deployment** with the help of `init-env`.
 4. Consider to add a port forwarder as a sidecar to implement single StatefulSet configuration with the help of `init-env` for **Public deployment**.
 5. Consider to add an option to use Deployment instead of StatefulSet.
