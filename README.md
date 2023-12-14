This Helm chart deploys the [vertica-kafka-scheduler](https://github.com/vertica/vertica-containers/tree/main/vertica-kafka-scheduler) with two modes:
- **initializer**: Configuration mode. Starts a container so that you can `exec` into it and configure it.
- **launcher**: Launch mode. Launches the vkconfig scheduler. Starts a container that calls `vkconfig launch` automatically. Run this mode after you configure the container in `initializer` mode.

## Install the charts

Add the charts to your repo and install the Helm chart. The following `helm install` command uses the `image.tag` [parameter](#parameters) to install version 24.1.0:

```shell
$ helm repo add vertica-charts https://vertica.github.io/charts
$ helm repo update
$ helm install vkscheduler vertica-charts/vertica-kafka-scheduler \ 
    --set "image.tag=24.1.0"
```

## Sample manifests

The following dropdowns provide sample manifests for a Kafka cluster, VerticaDB operator and custom resource (CR), and vkconfig scheduler. These manifests are applied in [Usage](#usage) to demonstrate how a simple deployment:

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
  <summary>vdb-op-cr.yaml</summary>

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

## Usage

The following sections deploy a Kafka cluster and a VerticaDB operator and CR on Kubernetes. Then, they show you how to configure Vertica to consume data from Kafka by setting up the necessary tables and configuring the scheduler. Finally, you launch the scheduler and send data on the command line to test the implementation.

### Deploy the manifests

Apply manifests on Kubernetes to create a Kafka cluster, VerticaDB operator, and VerticaDB CR:

1. Create a namespace. The following command creates a namespace named `kafka`:
   ```shell
   kubectl create namespace kafka
   ```
1. Create the Kafka custom resource. Apply the [kafka-cluster.yaml](#sample-manifests) manifest:
   ```shell
   kubectl apply -f kafka-cluster.yaml
   ```
  
2. Deploy the VerticaDB operator and custom resource. The [vdb-op-cr.yaml](#sample-manifests) manifest deploys version 12.0.3:
   ```shell
   kubectl apply -f vdb-op-cr.yaml
   ```

### Set up Vertica

Create tables and resources so that Vertica can consume data from a Kafka topic:
  
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

### Create a Kafka topic

Start the Kafka service, and create a Kafka topic that the scheduler can consume data from:

1. Open a new shell and start the Kafka producer:
   ```shell
   kubectl -namespace kafka run kafka-producer -ti --image=quay.io/strimzi/kafka:0.38.0-kafka-3.6.0 --rm=true --restart=Never -- bash
   ```
1. Create the Kafka topic that the scheduler subscribes to:
   ```shell
   bin/kafka-console-producer.sh --bootstrap-server my-cluster-kafka-bootstrap.kafka:9092 --topic KafkaTopic1
   ```

### Configure the scheduler

Deploy the scheduler container in initializer mode, and configure the scheduler to consume data from the [Kafka topic](#create-a-kafka-topic):

1. Deploy the [vertica-kafka-scheduler Helm chart](#sample-manifests). This manifest has `initializerEnabled` set to `true` so you can configure the vkconfig container before you launch the scheduler:
   ```shell
   kubectl apply -f vertica-kafka-scheduler.yaml
   ```

1. Use `kubectl exec` to get a shell in the initializer pod:
   ```shell
   kubectl exec -namespace main -it vk1-vertica-kafka-scheduler-initializer -- bash
   ```
1.  Set configuration options for the scheduler. For descriptions of each of the following options, see [vkconfig script options](https://docs.vertica.com/23.4.x/en/kafka-integration/vkconfig-script-options/):
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

<dl>
  <dt>affinity</dt>
    <dd>Applies <a href="https://kubernetes.io/docs/concepts/scheduling-eviction/assign-pod-node/#affinity-and-anti-affinity">affinity rules</a> that constrain the scheduler to specific nodes.</dd>

  <dt>conf.configMapName</dt>
    <dd>Name of the <a href="https://kubernetes.io/docs/concepts/configuration/configmap/">ConfigMap</a> to use and optionally generate. If omitted, the chart picks a suitable default.</dd>

  <dt>conf.content</dt>
    <dd>Set of key-value pairs in the generated ConfigMap. If <code>conf.generate</code> is <code>false</code>, this setting is ignored.</dd>

  <dt>conf.generate</dt>
    <dd>When set to <code>true</code>, the Helm chart controls the creation of the <code>vkconfig.conf</code> ConfigMap.</dd>
    <dd><b>Default</b>: <code>true</code></dd>

  <dt>fullNameOverride</dt>
    <dd>Gives the Helm chart full control over the name of the objects that get created. This takes precedence over <code>nameOverride</code>.</dd>

  <dt>initializerEnabled</dt>
    <dd>When set to <code>true</code>, the initializer pod is created. This can be used to run any setup tasks needed.</dd>
    <dd><b>Default</b>: <code>true</code></dd>

  <dt>image.pullPolicy</dt>
    <dd>How often Kubernetes pulls the image for an object. For details, see <a href="https://kubernetes.io/docs/concepts/containers/images/#updating-images">Updating Images</a> in the Kubernetes documentation.</dd>
    <dd><b>Default</b>: <code>IfNotPresent</code></dd>

  <dt>image.repository</dt>
    <dd>The image repository and name that contains the Vertica Kafka Scheduler.</dd>
    <dd><b>Default</b>: <code>vertica/kafka-scheduler</code></dd>

  <dt>image.tag</dt>
    <dd>Version of the Vertica Kafka Scheduler. This setting must match the version of the Vertica server that the scheduler connects to.</dd>
    <dd><b>Default</b>: Helm chart's <code>appVersion</code></dd>

  <dt>imagePullSecrets</dt>
    <dd>List of <a href="https://kubernetes.io/docs/concepts/configuration/secret/">Secrets</a> that contain the required credentials to pull the image.</dd>

  <dt>launcherEnabled</dt>
    <dd>When set to <code>true</code>, the Helm chart creates the launch deployment. Enable this setting after you configure the scheduler options in the container.</dd>
    <dd><b>Default</b>: <code>true</code></dd>

  <dt>jvmOpts</dt>
    <dd>Values to assign to the <code>VKCONFIG_JVM_OPTS</code> environment variable in the pods.

  > **NOTE**
  > You can omit most truststore and keystore settings because they are set by <code>tls.*</code> parameters.</dd>

  <dt>nameOverride</dt>
    <dd>Controls the name of the objects that get created. This is combined with the Helm chart release to form the name.</dd>

  <dt>nodeSelector</dt>
    <dd><a href="https://kubernetes.io/docs/concepts/scheduling-eviction/assign-pod-node/#nodeselector">nodeSelector</a> that controls where the pod is scheduled.</dd>

  <dt>podAnnotations</dt>
    <dd><a href="https://kubernetes.io/docs/concepts/overview/working-with-objects/annotations/">Annotations</a> that you want to attach to the pods.</dd>

  <dt>podSecurityContext</dt>
    <dd><a href="https://kubernetes.io/docs/tasks/configure-pod-container/security-context/">Security context</a> for the pods.</dd>

  <dt>replicaCount</dt>
    <dd>Number of launch pods that the chart deploys.</dd>
    <dd><b>Default</b>: 1</dd>

  <dt>resources</dt>
    <dd>Host resources to use for the pod.</dd>

  <dt>securityContext</dt>
    <dd><a href="https://kubernetes.io/docs/tasks/configure-pod-container/security-context/">Security context</a> for the container in the pod.</dd>

  <dt>serviceAccount.annotations</dt>
    <dd>Annotations to attach to the <a href="https://kubernetes.io/docs/concepts/security/service-accounts/">ServiceAccount</a>.</dd>

  <dt>serviceAccount.create</dt>
    <dd>When set to <code>true</code>, a <a href="https://kubernetes.io/docs/concepts/security/service-accounts/">ServiceAccount</a> is created as part of the deployment.</dd>
    <dd><b>Default</b>: true</dd>

  <dt>serviceAccount.name</dt>
    <dd>Name of the <a href="https://kubernetes.io/docs/concepts/security/service-accounts/">service account</a>. If this parameter is not set and <code>serviceAccount.create</code> is set to <code>true</code>, a name is generated using the fullname template.</dd>

  <dt>tls.enabled</dt>
    <dd>When set to <code>true</code>, the scheduler is set up for TLS authentication.</dd>
    <dd><b>Default</b>: <code>false</code></dd>

  <dt>tls.keyStoreMountPath</dt>
    <dd>Directory name where the keystore is mounted in the pod. This setting controls the name of the keystore within the pod. The full path to the keystore is constructed by combining this parameter and <code>tls.keyStoreSecretKey</code>.</dd>

  <dt>tls.keyStorePassword</dt>
    <dd>Password that protects the keystore. If this setting is omitted, then no password is used.</dd>

  <dt>tls.keyStoreSecretKey</dt>
    <dd>Key within <code>tls.keyStoreSecretName</code> that is used as the keystore file name. This setting and <code>tls.keyStoreMountPath</code> form the full path to the key in the pod.</dd>

  <dt>tls.keyStoreSecretName</dt>
    <dd>Name of an existing <a href="https://kubernetes.io/docs/concepts/configuration/secret/">Secret</a> that contains the keystore. If this setting is omitted, no keystore information is included.</dd>

  <dt>tls.trustStoreMountPath</dt>
    <dd>Directory name where the truststore is mounted in the pod. This setting controls the name of the truststore within the pod. The full path to the truststore is constructed by combining this parameter with <code>tls.trustStoreSecretKey</code>.</dd>

  <dt>tls.trustStorePassword</dt>
    <dd>Password that protects the truststore. If this setting is omitted, then no password is used.</dd>

  <dt>tls.trustStoreSecretKey</dt>
    <dd>Key within <code>tls.trustStoreSecretName</code> that is used as the truststore file name. This is used with <code>tls.trustStoreMountPath</code> to form the full path to the key in the pod.</dd>

  <dt>tls.trustStoreSecretName</dt>
    <dd>Name of an existing <a href="https://kubernetes.io/docs/concepts/configuration/secret/">Secret</a> that contains the truststore. If this setting is omitted, then no truststore information is included.</dd>

  <dt>tolerations</dt>
    <dd>Applies <a href="https://kubernetes.io/docs/concepts/scheduling-eviction/taint-and-toleration/">tolerations</a> that control where the pod is scheduled.</dd>
</dl>
