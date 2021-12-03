# Desplegando con Kops

## Instalacion de Kops 

Kops es sencillamente un ejecutable, podemos descargarlo y ejecutarlo o configurar nuestro sistema para tenerlo disponible en cualquier parte del mismo. Kops requiere kubectl y aws-cli con credenciales suficientes para comunicarse con los servicios de AWS.

En Linux es posible instalarlo desde snap, aunque esto generará algunos problemas con el acceso a la aplicacion de edicion por defecto y con la ruta de archivos dentro del volumen snap.

```
sudo snap install kops --classic
```


Tambien podriamos despelgar un contenedor Docker con todo el software necesario.
https://hub.docker.com/r/sigursoft/kops.aws/dockerfile

Sin embargo lo mas sencillo y menos problemático será seguir las siguientes instrucciones.

#### Previamente [instalamos Kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl/) 

##### Linux

```
curl -LO https://github.com/kubernetes/kops/releases/download/$(curl -s https://api.github.com/repos/kubernetes/kops/releases/latest | grep tag_name | cut -d '"' -f 4)/kops-linux-amd64
chmod +x kops-linux-amd64
sudo mv kops-linux-amd64 /usr/local/bin/kops
```


##### Windows
Get kops-windows-amd64 from our releases.
Rename kops-windows-amd64 to kops.exe and store it in a preferred path.
Make sure the path you chose is added to your Path environment variable.

##### OSx HomeBriew

brew update && brew install kops



## Desplegando en AWS

Todos las instrucciones estan probadas y funcionan con AWS CLI 1.X y no han sido probadas con AWS CLI 2.X que segun lo indicado en el siguiente articulo de la documentación sufre incompatibilidades de migración: 
https://docs.aws.amazon.com/es_es/cli/latest/userguide/welcome-versions.html

Podemos usar AWS-CLI en cualquier version en contenedores docker

'
docker run --rm -it amazon/aws-cli:latest --version
'




Damos por hecho que hemos instalado previamente Kops y Kubectl.



Para preparar correctamente la cuenta de AWS para kops, requerimos que instale las herramientas de AWS CLI y que tenga credenciales de API para una cuenta que tenga los permisos para crear una nueva cuenta de IAM para kops más adelante en la guía.


Una vez que haya instalado las herramientas de [AWS CLI](https://aws.amazon.com/cli/) y haya configurado correctamente su sistema para usar los métodos oficiales de AWS de registro de credenciales de seguridad como se define aquí, estaremos listos para ejecutar kops, ya que usa Go AWS SDK.


#### configurando el usuario de AWS

Para manejar servicios dentro de AWS, crearemos un usuario de IAM dedicado para kops. Este usuario requiere credenciales de API. 

Crearemos un usuario con las siguientes credenciales en la consola de AWS.

```
AmazonEC2FullAccess
AmazonRoute53FullAccess
AmazonS3FullAccess
IAMFullAccess
AmazonVPCFullAccess
```
Tambien podremos crear el usuario para kops a traves de la consola con aws-cli mediante las siguientes instrucciones

```
aws iam create-group --group-name kops

aws iam attach-group-policy --policy-arn arn:aws:iam::aws:policy/AmazonEC2FullAccess --group-name kops
aws iam attach-group-policy --policy-arn arn:aws:iam::aws:policy/AmazonRoute53FullAccess --group-name kops
aws iam attach-group-policy --policy-arn arn:aws:iam::aws:policy/AmazonS3FullAccess --group-name kops
aws iam attach-group-policy --policy-arn arn:aws:iam::aws:policy/IAMFullAccess --group-name kops
aws iam attach-group-policy --policy-arn arn:aws:iam::aws:policy/AmazonVPCFullAccess --group-name kops

aws iam create-user --user-name kops

aws iam add-user-to-group --user-name kops --group-name kops

aws iam create-access-key --user-name kops
```

Para poder realizar esta práctica todos ( la creación y configuración de usuario y permisos ), bien podriamos añadir a nuestro usuario el grupo kops, añadir los permisos al usuario o crear un usuario kops con nombres sufijados cada uno de nosotros.

En su defecto podremos usar todos el usuario ya creado "kops"


### Configurar DNS

Para construir un clúster de Kubernetes con kops, necesitamos prepararnos en algún lugar para construir los registros DNS requeridos. Hay tres escenarios a continuación y debe elegir el que mejor se adapte a su situación de AWS

#### Escenario 1a: Hemos comprado o registrado el dominio en AWS

Si compramos el dominio con AWS, entonces ya tenemos la zona alojada en Route53. Si queremos usar este dominio, no necesitamos configurar mas.

En este ejemplo, tenemos ejemplo.com, sus registros para Kubernetes se verían como etcd-us-east-1c.internal.clustername.example.com

#### Escenario 1b: Hemos registrado un subdominio en AWS

En este escenario, queremos contener todos los registros de kubernetes en un subdominio de un dominio que alojamos en Route53. 

Esto requiere crear una segunda zona alojada en route53 y luego configurar la delegación de ruta a la nueva zona.

En este ejemplo,tenemos example.com y sus registros para Kubernetes se verían como etcd-us-east-1c.internal.clustername.subdomain.example.com

###### Copiar los servidores NS del SUBDOMINIO hasta el dominio PADRE en Route53

* Cree el subdominio y anote sus servidores de nombres SUBDOMAIN
    * para poder desarrollar esta practica usaremos todos un subdominio del dominio devopsgeekshubsacademy.click. correctamente registrado en el NS de AWS.
```
    {
    "HostedZones": [
        {
            "Id": "/hostedzone/Z0955646BOEFS38543P",
            "Name": "devopsgeekshubsacademy.click.",
            "CallerReference": "RISWorkflow-RD:573265ce-dbf4-4173-8c63-16c43d23e90f",
            "Config": {
                "Comment": "HostedZone created by Route53 Registrar",
                "PrivateZone": false
            },
            "ResourceRecordSetCount": 2
        }
    ]
}
```

* creamos el subdominio y obtenemos los nameservers del mismo para la nueva zona creada


```
ID=$(uuidgen) && aws route53 create-hosted-zone --name subdomain.devopsgeekshubsacademy.click. --caller-reference $ID | \
    jq .DelegationSet.NameServers
```

*  una vez configurada la zona del subdominio también podemos obtener los valores


Obtener el ID de zona alojada
```
HZC=$(aws route53 list-hosted-zones | jq -r '.HostedZones[] | select(.Name=="subdomain.devopsgeekshubsacademy.click.") | .Id' | tee /dev/stderr)

```

Obtener los nameservers del subdominio

```
aws route53 get-hosted-zone --id $HZC | jq .DelegationSet.NameServers
```

Obtenemos el Id de zona del dominio padre

```
aws route53 list-hosted-zones | jq '.HostedZones[] | select(.Name=="devopsgeekshubsacademy.click.") | .Id'
```

Creamos un nuevo fichero los valores de nuestro subdominio

```
{
  "Comment": "Create a subdomain NS record in the parent domain",
  "Changes": [
    {
      "Action": "CREATE",
      "ResourceRecordSet": {
        "Name": "subdomain.devopsgeekshubsacademy.click",
        "Type": "NS",
        "TTL": 300,
        "ResourceRecords": [
          {
            "Value": "ns-1.awsdns-1.co.uk"
          },
          {
            "Value": "ns-2.awsdns-2.org"
          },
          {
            "Value": "ns-3.awsdns-3.com"
          },
          {
            "Value": "ns-4.awsdns-4.net"
          }
        ]
      }
    }
  ]
}
```

* Aplicamos la configuracion de NS para el subdominio en la zona DNS del padre.

```
aws route53 change-resource-record-sets --hosted-zone-id <parent-zone-id> --change-batch file://subdomain.json
```

> Ahora el tráfico hacia *.subdominio.devopsgeekshubsacademy.click se enrutará a la zona alojada del subdominio correcto en Route53.


#### Escenario 2: Configurar Route53 para un dominio comprado en otro registrador.

Debemos transferirlo o configurarlo para usar los servidores NS de AWS Route53 
https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/domain-transfer-to-route-53.html

#### Escenario 3: Configurar un subdominio para clusters en Route53, dejando el dominio en otro registrador.

Es necesario configurar los servidores NS para el subdominio en el registrador si este lo permite, de lo contrario deberemos transferir o usar los servidores NS de Route53 para el dominio completo. Configurando en Route53 todas las zonas DNS.


### Configurando DNS Publico/Privado ( Kops 1.5 + )

Por defecto, se supone que los registros NS están disponibles públicamente. Si necesitamos registros DNS privados, debemos modificar los comandos que ejecutamos en adelante.

```
kops create cluster --dns private subdomain.geekshubsacademy.click
```

> Comprobamos que nos pide la configuración de S3 ... que veremos mas adelante.

Si nuestra configuracion es mixta Publico/Privada debemos usar el flag --dns-zone

```
kops create cluster --dns private --dns-zone ZABCDEFG $NAME
```

#### Testeando el DNS

Ahora deberíamos poder explorar el  dominio (o subdominio) y ver los Servidores de nombres de AWS en el otro lado mediate "dig", ( respetar tiempos de propagación )


```
dig ns subdomain.devopsgeekshubsacademy.click

```

#### Almacenar el estado del Cluster

Para almacenar el estado de su clúster y la representación de su clúster, necesitamos crear un bucket S3 dedicado para que kops pueda usarlo.

Este bucket se convertirá en la fuente de datos para nuestra configuración de nuestro clúster. 

Llamaremos a un bucket de ejemplo como ejemplo-com-state-store, pero cada uno debe agregar un prefijo o imponer un nombre personalizado ya que los nombres de depósito deben ser únicos y estar disponibles.


Se Recomienda mantener la creación de este buckeet en us-east-1, de lo contrario se requerirá más trabajo de configuración y la zona de almacenamiento es irrelevante para el funcionamiento.

```
aws s3api create-bucket --bucket prefix-example-com-state-store --region us-east-1
```

Recomendamos añadir versionad al bucket S3 en caso de que necesite revertir o recuperar un estado anterior.

```
aws s3api put-bucket-versioning --bucket prefix-example-com-state-store  --versioning-configuration Status=Enabled

```

La información sobre la ubicación del bucket de estado del clúster debe establecerse en cada operacion de kops cli
https://kops.sigs.k8s.io/state/

#### cifrado del almacen de estado

kops admite el cifrado de bucket predeterminado para cifrar su estado en un S3. De esta manera, el cifrado del lado del servidor predeterminado establecido para su bucket también se usará para el estado kops. Es posible que desee utilizar esta función de AWS, por ejemplo, para cifrar fácilmente cada objeto escrito de manera predeterminada o cuando necesite usar claves de cifrado específicas (KMS, CMK) por razones de cumplimiento.

Si su depósito S3 tiene una configuración de cifrado predeterminada, kops la usará de manera transpaarente.

```
aws s3api put-bucket-encryption --bucket prefix-example-com-state-store --server-side-encryption-configuration '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"}}]}'

```


## VAMOS A CREAR NUESTRO CLUSTER

#### Preparando el entorno local

¡Estamos listos para comenzar a crear nuestro primer clúster! Primero configuremos algunas variables de entorno para facilitar el proceso.

```
export NAME=myfirstcluster.example.com
export KOPS_STATE_STORE=s3://prefix-example-com-state-store
```

> Nota: si no queremos usar variables de entorno. Siempre podemos definir los valores utilizando los flags –name y –state en cada sentencia.


### Creando la configuración.

Tendremos que tener en cuenta qué zonas de disponibilidad están disponibles para nosotros. En este ejemplo, implementaremos nuestro clúster en la región eu-west-1.

`aws ec2 describe-availability-zones --region eu-west-1`

A continuación se muestra un comando de creación de clúster. Utilizaremos el ejemplo más básico posible, ya veremos casos mas complejos en alta disponibilidad.
https://kops.sigs.k8s.io/operations/high_availability/#advanced-example


El siguiente comando generará una configuración de clúster, pero no comenzará a compilar. 


```
kops create cluster \
    --zones=us-west-2a \
    ${NAME}
```

Todas las instancias creadas por kops se construirán dentro de ASG (Auto Scaling Groups), lo que significa que cada instancia será monitoreada y reconstruida automáticamente por AWS si sufre alguna caida.


### Configurando el cluster.

Ahora que tenemos una configuración de clúster, podemos ver cada aspecto que define nuestro clúster editando la descripción.

`kops edit cluster ${NAME}`

esto abre el editor por defecto y le permite editar la configuración. La configuración se carga desde el bucket S3 que creamos anteriormente y se actualiza automáticamente cuando guardamos y salimos del editor.

### Construyendo el cluster

Ahora damos el paso final de construir realmente el clúster. Esto llevará un tiempo. Una vez que finalice, tendrá que esperar más tiempo mientras las instancias arrancadas terminan de descargar los componentes de Kubernetes y alcanzan un estado "listo".

```
kops update cluster ${NAME} --yes
```

### Obtener credenciales del cluster

```
kops export kubecfg ${NAME} --admin
```

### Accediendo al Cluster

¿Recuerdas cuando instalaste kubectl antes? 
¡La configuración para el clúster se generó automáticamente y se escribió en ~ / .kube / config!

Por esto ya podremos acceder al cluster desde kubectl

```
kubectl get nodes
```

lista de nodos que deben coincidir con la bandera --zones definida anteriormente. Esta es ua gran señal de que su clúster de Kubernetes está en línea y funcionando.


Kops también se entrega con una práctica herramienta de validación que se puede ejecutar para garantizar que su clúster funcione como se espera.

```
kops validate cluster --wait 10m
```
Podemo ver todos los componentes del sistema desplegados hasta ahora con el siguiente comando.


```
kubectl -n kube-system get po

```


### Destruyendo el cluster

```
kops delete cluster --name ${NAME} --yes

```


## DESLPEGAR ALGUNOS COMPONENTES BASICOS

* Web UI

https://kubernetes.io/docs/tasks/access-application-cluster/web-ui-dashboard/#deploying-the-dashboard-ui

https://github.com/kubernetes/dashboard

* Kubernetes Metrics Server

https://github.com/kubernetes-sigs/metrics-server


* Weave Scope

https://www.weave.works/docs/scope/latest/installing/#k8s


### NETWORKS



* port-forward

Realizamos un mapeo de puertos mediante un port forward a traves del api de Kubernetes y de Kubectl de modo que si tenemos acceso a la nube de K8S con las credenciales adecuadas podremos acceder desde localhost practicamente a cualquier puerto de cualquier componente desplegado en K8s

```
# a un pod por name

kubectl port-forward redis-master-765d459796-258hz 7000:6379

#  a un pod por name 

kubectl port-forward pods/redis-master-765d459796-258hz 7000:6379

# al deployment por name 

kubectl port-forward deployment/redis-master 7000:6379

# al replicaset por name

kubectl port-forward replicaset/redis-master 7000:6379

# al servicio por name 

kubectl port-forward service/redis-master 7000:6379

```


* LoadBalancer

Es la manera de conectar un servicio a internet de manera accesible, esto genera un balanceador de carga en el proveedor de infraestructura con los costes aplicados a este servicio como puerta de entrada

![](https://i.imgur.com/FAzFtMQ.png)

* NodePort

Ocupamos un puerto real en el nodo de K8s donde se accede al servicio, esto implica que no podemos usar dos veces el mismo puerto o que no podamos desplegar servicios expuestos a internet en su puerto natural.  

![](https://i.imgur.com/KFTPTJS.png)

* Ingress

![](https://i.imgur.com/Ti5p4Y7.png)



### Nginx Ingress Controller

