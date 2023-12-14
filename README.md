This Helm chart deploys the [vertica-kafka-scheduler](https://github.com/vertica/vertica-containers/tree/main/vertica-kafka-scheduler) in two modes:
- **initializer**: Configuration mode. Starts a container so that you can `exec` into it and configure it.
- **launcher**: Launch mode. Launches the vkconfig scheduler. Starts a container that calls `vkconfig launch` automatically. Run this mode after you configure the container in `initializer` mode.

## Install the chart 

Add the charts to your repo and install the Helm chart:

```shell
$ helm repo add vertica-charts https://vertica.github.io/charts
$ helm repo update
$ helm install vkscheduler vertica-charts/vertica-kafka-scheduler \ 
    --set "image.tag=24.1.0"
```

## Usage

The following sections use the [Strimzi operator](https://strimzi.io/) to deploy Kafka on Kubernetes.

### Sample manifests 

The following sections create and deploy multiple manifests whose length disrupts the document flow. To improve readability, these resources are available in the following drop downs:

<details>
  <summary>kafka-cluster.yaml (with <a href="https://strimzi.io/">Strimzi operator)</a></summary>

  ```yaml
  apiVersion: kafka.strimzi.io/v1beta2
  kind: Kafka
  metadata:
  
    namespace: kafka
    name: my-cluster
  spec:
    kafka:
      version: 3.6.0
      replicas: 1
      listeners:
        - name: plain
          port: 9092
          type: internal
          tls: false
        - name: tls
          port: 9093
          type: internal
          tls: true
      config:
        offsets.topic.replication.factor: 1
        transaction.state.log.replication.factor: 1
        transaction.state.log.min.isr: 1
        default.replication.factor: 1
        min.insync.replicas: 1
        inter.broker.protocol.version: "3.6"
      storage:
        type: jbod
        volumes:
        - id: 0
          type: persistent-claim
          size: 100Gi
          deleteClaim: false
    zookeeper:
      replicas: 1
      storage:
        type: persistent-claim
        size: 100Gi
        deleteClaim: false
    entityOperator:
      topicOperator: {}
      userOperator: {}
  ```
</details>

<details>
  <summary>vdb-operator-cr.yaml</summary>

   ```yaml
   apiVersion: vertica.com/v1
   kind: VerticaDB
   metadata:
     annotations:
       vertica.com/include-uid-in-path: "false"
       vertica.com/vcluster-ops: "false"
     name: vdb-1203
     namespace: main
   spec:
     autoRestartVertica: true
     communal:
       credentialSecret: ""
       endpoint: https://s3.amazonaws.com
       path: s3://<path>/<to>/<s3-bucket>
       region: us-east-1
       s3ServerSideEncryption: ""
     dbName: vertdb
     image: vertica/vertica-k8s:12.0.3-0
     imagePullPolicy: IfNotPresent
     initPolicy: Revive
     licenseSecret: license
     local:
       catalogPath: ""
       dataPath: /data
       depotPath: /depot
       depotVolume: EmptyDir
       requestSize: 10Gi
     nmaTLSSecret: ""
     passwordSecret: passwd
     podSecurityContext:
       fsGroup: 5000
       runAsUser: 5000
     serviceAccountName: vertica
     shardCount: 6
     subclusters:
     - affinity: {}
       name: sc0
       resources: {}
       serviceName: sc0
       serviceType: ClusterIP
       size: 3
       type: primary
     upgradePolicy: Offline
   ```
</details>

<details>
  <summary>vertica-kafka-scheduler.yaml</summary>

  ```yaml
   image:
     repository: vertica/kafka-scheduler
     pullPolicy: IfNotPresent
     tag: 12.0.3
   launcherEnabled: false
   replicaCount: 1
   initializerEnabled: true
   conf:
     generate: true
     content:
       config-schema: Scheduler
       username: dbadmin
       dbport: '5433'
       enable-ssl: 'false'
       password: Vertica!
       dbhost: 10.20.30.40
   tls:
     enabled: false
   serviceAccount:
     create: true
   ```
</details>


### Deploy the manifests

1. Create a namespace. The following command creates a namespace named `kafka`:
   ```shell
   kubectl create namespace kafka
   ```
1. Create the Kafka custom resource. Apply the [kafka-cluster.yaml](#sample-manifests) manifest:
   ```shell
   kubectl apply -f kafka-cluster.yaml
   ```
  
2. Deploy the VerticaDB operator and custom resource. The [vdb-operator-cr.yaml](#sample-manifests) manifest deploys version 12.0.3:
   ```shell
   kubectl apply -f vdb-operator-cr.yaml
   ```

### Set up Vertica
  
1. Create a Vertica database for Kafka messages:
   ```sql
   CREATE FLEX TABLE KafkaFlex();
   ```
1. Create the Kafka user:
   ```sql
   CREATE USER KafkaUser;
   ```
1. Create a resource pool:
   ```sql
   CREATE RESOURCE POOL scheduler_pool PLANNEDCONCURRENCY 1;
   ```

### Set up the scheduler
1. Deploy the [vertica-kafka-scheduler Helm chart](#sample-manifests). 

7. Open a new shell and start the Kafka producer:
   ```shell
   kubectl -namespace kafka run kafka-producer -ti --image=quay.io/strimzi/kafka:0.38.0-kafka-3.6.0 --rm=true --restart=Never -- bash
   ```
8. Create the Kafka topic that the scheduler subscribes to:
   ```shell
   bin/kafka-console-producer.sh --bootstrap-server my-cluster-kafka-bootstrap.kafka:9092 --topic KafkaTopic1
   ```
9. Use `kubectl exec` to get a shell in the initializer pod:
   ```shell
   kubectl exec -namespace main -it vk1-vertica-kafka-scheduler-initializer -- bash
   ```
10. Now, you can set configuration options for the scheduler. For descriptions of each of the following options, see [vkconfig script options](https://docs.vertica.com/23.4.x/en/kafka-integration/vkconfig-script-options/):
    ```shell
    # scheduler options 
    vkconfig scheduler --conf /opt/vertica/packages/kafka/config/vkconfig.conf \
     --frame-duration 00:00:10 \
     --create --operator KafkaUser \
     --eof-timeout-ms 2000 \
     --config-refresh 00:01:00 \
     --new-source-policy START \
     --resource-pool scheduler_pool
    
    # target options 
    vkconfig target --add --conf /opt/vertica/packages/kafka/config/vkconfig.conf \
     --target-schema public \
     --target-table KafkaFlex
    
    # load spec options 
    vkconfig load-spec --add --conf /opt/vertica/packages/kafka/config/vkconfig.conf \
     --load-spec KafkaSpec \
     --parser kafkajsonparser \
     --load-method DIRECT \
     --message-max-bytes 1000000
    
    # cluster options 
    vkconfig cluster --add --conf /opt/vertica/packages/kafka/config/vkconfig.conf \
     --cluster KafkaCluster \
     --hosts my-cluster-kafka-bootstrap.kafka:9092
    
    # source options 
    vkconfig source --add --conf /opt/vertica/packages/kafka/config/vkconfig.conf \
     --cluster KafkaCluster \
     --source KafkaTopic1 \
     --partitions 1
    
    # microbatch options 
    vkconfig microbatch --add --conf /opt/vertica/packages/kafka/config/vkconfig.conf \
     --microbatch KafkaBatch1 \
     --add-source KafkaTopic1 \
     --add-source-cluster KafkaCluster \
     --target-schema public \
     --target-table KafkaFlex \
     --rejection-schema public \
     --rejection-table KafkaFlex_rej \
     --load-spec KafkaSpec
    ```

### Launch the scheduler

After you configure the scheduler options, you can deploy it in launcher mode:

```shell
helm upgrade -namespace main vk1 vertica-charts/vertica-kafka-scheduler \
  --set "launcherEnabled=true"
```

### Testing the deployment 

Now that you have a containerized Kafka cluster and VerticaDB CR running, you can test that the scheduler is automatically sending data from the Kafka producer to Vertica:

1. In the terminal that is running your Kafka producer, send sample JSON data:
   ```shell
   >{"a": 1}
   >{"a": 1000}
   ```

1. In a different terminal, open `vsql` and query the `KafkaFlex` table for the data:
   ```sql
   => SELECT compute_flextable_keys_and_build_view('KafkaFlex');
                                    compute_flextable_keys_and_build_view                    
   --------------------------------------------------------------------------------------------------------
    Please see public.KafkaFlex_keys for updated keys
   The view public.KafkaFlex_view is ready for querying
   (1 row)
    
   => SELECT a from KafkaFlex_view;
    a
   -----
    1
    1000
   (2 rows)
   ```

## Parameters

`affinity` 
: Applies [affinity rules](https://kubernetes.io/docs/concepts/scheduling-eviction/assign-pod-node/#affinity-and-anti-affinity) that constrain the scheduler to specific nodes.

`conf.configMapName`
: Name of the [ConfigMap](https://kubernetes.io/docs/concepts/configuration/configmap/) to use and optionally generate. If omitted, the chart picks a suitable default.

`conf.content`
: Set of key-values pairs in the generated ConfigMap. If `conf.generate` is `false`, this setting is ignored.

`conf.generate`
: When set to `true`, the Helm chart controls the creation of the `vkconfig.conf` ConfigMap.

  **Default**: `true`

`fullNameOverride`
: Gives the Helm chart full control over the name of the objects that get created. This takes precedence over `nameOverride`.

`initializerEnabled`
: When set to `true`, the initializer pod is created. This can be used to run any setup tasks needed.

  **Default**: `true`

`image.pullPolicy`
: How often Kubernetes pulls the image for an object. For details, see [Updating Images](https://kubernetes.io/docs/concepts/containers/images/#updating-images) in the Kubernetes documentation.

  **Default**: `IfNotPresent`

`image.repository`
: The image repository and name that contains the Vertica Kafka Scheduler.

  **Default**: `vertica/kafka-scheduler`

`image.tag`
: Version of the Vertica Kafka Scheduler. This setting must match the version of the Vertica server that the scheduler connects to.

  **Default**: Helm chart's `appVersion`

`imagePullSecrets`
: List of [Secrets](https://kubernetes.io/docs/concepts/configuration/secret/) that contain the required credentials to pull the image.

`launcherEnabled`
: When set to `true`, the Helm chart creates the launch deployment. Enable this setting after you configure the container in initializer mode.

  **Default**: `true`

`jvmOpts`
: Values to assign to the `VKCONFIG_JVM_OPTS` environment variable in the pods.

  > **NOTE**
  > You can omit most truststore and keystore settings because they are set by `tls.*` parameters.

`nameOverride`
: Controls the name of the objects that get created. This is combined with the Helm chart release to form the name.

`nodeSelector`
: [nodeSelector](https://kubernetes.io/docs/concepts/scheduling-eviction/assign-pod-node/#nodeselector) that controls where the pod is scheduled.

`podAnnotations`
: [Annotations](https://kubernetes.io/docs/concepts/overview/working-with-objects/annotations/) that you want to attach to the pods.

`podSecurityContext`
: [Security context](https://kubernetes.io/docs/tasks/configure-pod-container/security-context/) for the pods.

`replicaCount`
: Number of launch pods that the chart deploys.

  **Default**: 1

`resources`
: Host resources to use for the pod.

`securityContext`
: [Security context](https://kubernetes.io/docs/tasks/configure-pod-container/security-context/) for the container in the pod.

`serviceAccount.annotations`
: Annotations to attach to the [ServiceAccount](https://kubernetes.io/docs/concepts/security/service-accounts/).

`serviceAccount.create`
: When set to `true`, a [ServiceAccount](https://kubernetes.io/docs/concepts/security/service-accounts/) is created as part of the deployment.

  **Default**: `true`

`serviceAccount.name`
: Name of the [service account](https://kubernetes.io/docs/concepts/security/service-accounts/). If this parameter is not set and `serviceAccount.create` is set to `true`, a name is generated using the fullname template.

`tls.enabled`
: When set to `true`, the scheduler is set up for TLS authentication.

  **Default**: `false`

`tls.keyStoreMountPath`
: Directory name where the keystore is mounted in the pod. This setting controls the name of the keystore within the pod. The full path to the keystore is constructed by combining this parameter and `tls.keyStoreSecretKey`.


`tls.keyStorePassword`
: Password that protects the keystore. If this setting is omitted, then no password is used.

`tls.keyStoreSecretKey`
: Key within `tls.keyStoreSecretName` that is used as the keystore file name. This setting and `tls.keyStoreMountPath` form the full path to the key in the pod.

`tls.keyStoreSecretName`
: Name of an existing [Secret](https://kubernetes.io/docs/concepts/configuration/secret/) that contains the keystore. If this setting is omitted, no keystore information is included.

> included where?

`tls.trustStoreMountPath`
: Directory name where the truststore is mounted in the pod. This setting controls the name of the truststore within the pod. The full path to the truststore is constructed by combining this parameter with `tls.trustStoreSecretKey`.

`tls.trustStorePassword`
: Password that protects the truststore. If this setting is omitted, then no password is used.

`tls.trustStoreSecretKey`
: Key within `tls.trustStoreSecretName` that is used as the truststore file name. This is used with `tls.trustStoreMountPath` to form the full path to the key in the pod.

`tls.trustStoreSecretName`
: Name of an existing [Secret](https://kubernetes.io/docs/concepts/configuration/secret/) that contains the truststore. If this setting is omitted, then no truststore information is included.

`tolerations`
: Applies [tolerations](https://kubernetes.io/docs/concepts/scheduling-eviction/taint-and-toleration/) that control where the pod is scheduled.
