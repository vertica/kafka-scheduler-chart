This helm chart will deploy the vertica kafka scheduler. It will deploy the vertica/vertica-kafka-scheduler in two modes: initializer and launcher. When deployed as the initializer it will run the container so that you can exec into it and do your setup. When deployed as the launcher, the container will automatically call 'vkconfig launch'. This is expected to be done once everything has been setup.

| Parameter Name | Description | Default Value |
|----------------|-------------|---------------|
| affinity | Affinity to use with the pods to control where it is scheduled | |
| conf.configMapName | The name of the ConfigMap to use and optionally generate. If omitted, the chart will pick a suitable default. | |
| conf.content | Set of key/values pairs that will be included in the generated ConfigMap. This is ignored if conf.generate is false. | |
| conf.generate | If true, the helm chart will control creation of the vkconfig.conf ConfigMap. | true |
| fullNameOverride | Gives full controls over the name of the objects that get created. This takes precedence over nameOverride. | |
| initializerEnabled | If true, the initializer pod is created. This can be used to run any setup tasks needed. | true |
| image.pullPolicy | The pull policy to use for the image | IfNotPresent |
| image.repository | The image repository and name that contains the Vertica Kafka Scheduler | vertica/kafka-scheduler |
| image.tag | The tag corresponds to the version to use. The version of the Vertica Kafka Scheduler must match version of the Vertica server you are connecting to | Defaults to the charts appVersion |
| imagePullSecrets | A list of Secret's that are needed to be able to pull the image | |
| launcherEnabled | If true, the launch deployment is created. This should only be enabled once everything has been setup. | true |
| jvmOpts | Values to assign to the VKCONFIG_JVM_OPTS environment variable in the pods. You can omit most trustrtore/keystore settings as they are controlled by tls.* | |
| nameOverride | Controls the name of the objects that get created. This is combined with the helm chart release to form the name | |
| nodeSelector | A node selector to use with the pod to control where it is scheduled | |
| podAnnotations | Annotations to attach to the pods | |
| podSecurityContext | A PodSecurityContext to use for the pods | |
| replicaCount | If you want more than one launch pod deployed set this to a value greater than 1. | 1 |
| resourecs | Resources to use with the pod | |
| securityContext | A SecurityContext to use for the container in the pod | |
| serviceAccount.annotations | Annotations to attach to the ServiceAccount | |
| serviceAccount.create | If true, a ServiceAccount is created as part of the deployment | true |
| serviceAccount.name | Name of the service account. If not set and create is true, a name is generated using the fullname template | |
| tls.enabled | If true, we setup with the assumption that TLS authentication will be used. | false |
| tls.keyStoreMountPath | Directory name where the keystore will be mounted in the pod | |
| tls.keyStorePassword | The password to use along with the keystore | |
| tls.keyStoreSecretKey | A key within the tls.keyStoreSecretName that will be used as the keystore file name. If this is omitted, then no keystore information is included. | |
| tls.keyStoreSecretName | Name of an existing Secret that contains the keystore | |
| tls.trustStoreMountPath | Directory name where the truststore will be mounted in the pod | |
| tls.trustStoreSecretKey | A key within tls.trustStoreSecretName that will be used as the truststore file name | |
| tls.trustStoreSecretName | Name of an existing Secret that contains the truststore. If this is omitted, then no truststore information is included. | |
| tolerations | Tolerations to use with the pods to control where it is scheduled | |
