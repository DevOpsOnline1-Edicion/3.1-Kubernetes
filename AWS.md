# AWS KUBERNETES... EKS VS KOPS

![](https://i.imgur.com/OYkCLbK.png)

Existen tres métodos para ejecutar Kubernetes en AWS: 

* configurar manualmente todo en instancias EC2, 
* usar Kops para administrar su clúster
* Amazon EKS para administrar su clúster. 

Administrar un clúster de Kubernetes en AWS sin ninguna herramienta es un proceso complicado que no se recomienda para la mayoría de los administradores, por lo que nos centraremos en usar EKS o Kops. Comparamos las características de configuración, administración y seguridad del clúster para Kops y EKS para determinar qué solución debe usar.



## ¿Qué es AWS EKS?
![](https://i.imgur.com/gEOap4h.png)


Si piensas que EKS es un acrónimo de "Elastic Kubernetes Service", estas en un error. El nombre completo es en realidad Amazon Elastic Container Service para Kubernetes, esto es facil obviarlo ya que solo Amazon lo usa, y a veces la abstraccion es tal que realmente no sabemos lo que implica utilizar dicho servicio.

Amazon EKS se puso a disposición en general en junio de 2018 y se describe como un "servicio Kubernetes altamente disponible, escalable y seguro". Este tipo de descripción en el espacio de Kubernetes puede hacerle creer que puede tener una configuración de clúster de Kubernetes con un solo clic, y nuevamente se equivocaría. En cambio, EKS gestiona completamente solo el plano de control de Kubernetes (nodos maestros, etcd, servidor api), por una tarifa plana de uso de $ 0.20 por hora o ~ $ 145 por mes. (coste aproximadamente un 30% superior al coste de disponer de los mismos recursos en un uso libre). La principal desventaja de esto es que no tiene acceso a los nodos maestros y no puede realizar ninguna modificación en el plano de control.


## ¿ Qué es KOPS ?

![](https://i.imgur.com/p0m5RZM.png)

Kubernetes Operations (kops) es una herramienta de CLI para "Instalación, actualizaciones y administración de K8s de grado de producción". Kops ha estado presente desde finales de 2016, mucho antes de que EKS existiera.

Kops simplifica significativamente la configuración y administración del clúster de Kubernetes en comparación con la configuración manual de los nodos maestro y trabajador. Administra Route53, AutoScaling Groups, ELBs para el servidor api, grupos de seguridad, master bootstrapping, bootstrapping de nodos y actualizaciones sucesivas a su clúster. Dado que kops es una herramienta de código abierto, es de uso completamente gratuito, pero usted es responsable de pagar y mantener la infraestructura subyacente creada por kops para administrar su clúster de Kubernetes.




# Configuración de un clúster de Kubernetes

El primer punto a tener en cuenta al evaluar las soluciones de Kubernetes en AWS y el coste de configurar un clúster de Kubernetes que funcione con cada opción

## Configurar un clúster de Kubernetes con EKS

Configurar un clúster con EKS es bastante complicado y tiene algunos requisitos previos. Debe configurar y usar la AWS CLI y aws-iam-authenticator para autenticarse en su clúster, por lo que hay algunos complejidades generales al configurar los permisos y usuarios de IAM. Dado que EKS en realidad no crea nodos de trabajo automáticamente con su clúster EKS, también debe administrar ese proceso.

Amazon proporciona instrucciones y plantillas de CloudFormation que pueden lograr esto, pero algunas de ellas pueden tener que modificarse para que funcionen con sus requisitos específicos, como volúmenes raíz encriptados o nodos en ejecución en subredes privadas. 

Si prefiere usar terraform sobre CloudFormation para la administración de la infraestructura, puede usar el [módulo eks](https://registry.terraform.io/modules/terraform-aws-modules/eks/aws/2.3.1) para configurar su clúster. 

Para usar este módulo, ya debe tener una VPC y subredes configuradas para EKS, que también se puede hacer usando terraform . Este módulo incluye muchas opciones para crear nodos de trabajo y también puede actualizar opcionalmente sus archivos kubeconfig para que funcionen con aws-iam-authenticator. 

Parte de la documentación en el módulo está incompleta, y es necesario rescribir partes para configurar completamente los workers a tu especificación. Sin embargo, una vez que la configuración de terraform sea correcta, terraform generará un kubeconfig que funcionara con aws-iam-authenticator sin tener que copiar y pegar valores desde la consola de AWS. A continuación se muestra un ejemplo de configuración de terraform que crea un clúster EKS con varias opciones establecidas.

```
provider "aws" {
  region  = "us-east-1"
  version = "2.3.0"
}

module "eks_k8s1" {
  source  = "terraform-aws-modules/eks/aws"
  version = "2.3.1"

  cluster_version = "1.12"

  cluster_name = "k8s"
  Vpc_id = "vpc-00000000"

  subnets = ["subnet-00000001", "subnet-000000002", "subnet-000000003"]

  cluster_endpoint_private_access = "true"
  cluster_endpoint_public_access  = "true"

  write_kubeconfig      = true
  config_output_path    = "/.kube/"
  manage_aws_auth       = true
  write_aws_auth_config = true

  map_users = [
    {
      user_arn = "arn:aws:iam::12345678901:user/user1"
      username = "user1"
      group    = "system:masters"
    },
  ]

  worker_groups = [
    {
      name                 = "workers"
      instance_type        = "t2.large"
      asg_min_size         = 3
      asg_desired_capacity = 3
      asg_max_size         = 3
      root_volume_size     = 100
      root_volume_type     = "gp2"
      ami_id               = "ami-0000000000"
      ebs_optimized     = false
      key_name          = "all"
      enable_monitoring = false
    },
  ]

  tags = {
    Cluster = "k8s"
  }
}
```


El método para configurar EKS que funcione mejor para tu realidad es probablemente el más cercano a lo que ya estes usando. Si estás intentando configurar EKS en una VPC existente, use cualquier herramienta que ya esté utilizando para administrar su VPC. Al usar EKS en una nueva VPC, CloudFormation o Terraform son excelentes opciones para administrar todos los recursos relacionados.

## Configurar un clúster de Kubernetes en Kops

Kops es una herramienta CLI y debe instalarse en su máquina local junto con kubectl . 

Hacer que un clúster se ejecute es tan simple como ejecutar 

`kops create cluster`

comando con todas las opciones necesarias. Kops administrará la mayoría de los recursos de AWS necesarios para ejecutar un clúster de Kubernetes y trabajará con una VPC nueva o existente. A diferencia de EKS, kops creará sus nodos maestros también como instancias EC2, puedes acceder a esos nodos directamente y realizar modificaciones. Con acceso a los nodos maestros, puedes elegir qué capa de red usar, elegir el tamaño de las instancias maestras y supervisar directamente los nodos maestros. También tienes la opción de configurar un clúster con un solo maestro, lo que puede ser deseable para entornos de desarrollo y prueba donde no se requiere alta disponibilidad. Kops también admite la generación de configuraciones de terraform para sus recursos en lugar de crearlos directamente, lo cual es una buena característica si usas terraform.

A continuación se muestra un comando de ejemplo para crear un clúster con 3 maestros y 3 trabajadores en una nueva VPC.


```
kops create cluster \
  --cloud aws \
  --dns public \
  --dns-zone ${ROUTE53_ZONE} \
  --topology private \
  --networking weave \
  --associate-public-ip=false \
  --encrypt-etcd-storage \
  --network-cidr 10.2.0.0/16 \
  --image ${AMI_ID} \
  --kubernetes-version 1.10.11 \
  --master-size t2.medium \
  --master-count 3 \
  --master-zones us-east-1a,us-east-1b,us-east-1d \
  --master-volume-size 64 \
  --zones us-east-1a,us-east-1b,us-east-1d \
  --node-size t2.large \
  --node-count 3 \
  --node-volume-size 128 \
  --ssh-access 10.0.0.0/16 \
  ${CLUSTER_NAME}
```


### GANADOR KOPS

Encontramos que Kops es la forma más rápida de ejecutar un clúster completamente funcional en una nueva VPC. Es una herramienta creada específicamente por Kubernetes en la comunidad de AWS, y funciona muy bien para hacer esto.

EKS, por otro lado, sigue siendo un servicio relativamente nuevo para AWS, y hay muchas molestias adicionales para que todo funcione con IAM, administrar nodos de workers y configurar la VPC. Herramientas como CloudFormation y Terraform facilitan la configuración de EKS, pero claramente no es un problema completamente resuelto en este momento.



# ADMINISTRAR UN CLUSTER

La configuración del clúster es un evento que sucede rara vez. Una vez puesto en marcha nuestro clúster, como norma general no efectuaremos tareas de administracion del mismo habitualmente. 

Tal vez, tras evaluar implantar una solución que pueda afectar una parte crítica de su infraestructura Kubernetes, o considerar asuntos cómo es escalar los nodos, realizar actualizaciones del clúster o integrarse con otros servicios en el futuro.


## Administrar un clúster de Kubernetes con EKS

El esfuerzo adicional requerido para configurar EKS usando CloudFormation o Terraform vale la pena cuando se trata del mantenimiento del clúster. EKS tiene una forma prescrita para actualizar la versión de Kubernetes del plano de control con una interrupción mínima. Sus nodos de trabajo se pueden actualizar utilizando una AMI más nueva para la nueva versión de Kubernetes, creando un nuevo grupo de trabajadores y luego migrando su carga de trabajo a los nuevos nodos. El proceso de mover pods a nuevos nodos se describe en otra de nuestras publicaciones de blog aquí . Ampliar su clúster con EKS es tan simple como agregar más nodos de trabajo. Dado que el plano de control está completamente administrado, no tiene que preocuparse por agregar o actualizar los tamaños maestros cuando el clúster se hace más grande.

Un área que EKS carece de escalabilidad es la forma en que maneja las redes. En la mayoría de las configuraciones de Kubernetes, los pods vivirán en una red virtual dentro de su clúster de Kubernetes que solo es visible desde dentro del clúster. Con EKS, los pods comparten la misma red que la VPC en la que se creó el clúster. Esto significa que cada pod toma una dirección IP privada en las subredes que usó para crear el clúster, y cada nodo de trabajo tiene que conectar múltiples interfaces de red a administrar estas IP.

![](https://i.imgur.com/VgBSvSL.png)


Al usar la red VPC directamente en lugar de una red virtualizada, puede encontrarse con varios problemas. Por un lado, cualquier cosa en la VPC estará en la misma red que sus pods, por lo que debe confiar en los grupos de seguridad de VPC si desea restringir el acceso a sus pods. 

Otras soluciones incluyen ejecutar su clúster en una VPC separada o instalar [Calico](https://docs.aws.amazon.com/eks/latest/userguide/calico.html) para implementar la segmentación de la red. Otro problema que puede encontrar es la dirección IP por ENI y ENI por límites de instanciaen EC2. En mis configuraciones de ejemplo anteriores, utilicé instancias t2.large que están limitadas a 3 ENI y 12 IP por ENI, para un total de 36 direcciones IP. Si bien es poco probable que intente ejecutar 36 pods en un t2.large, si su carga de trabajo consta de muchos contenedores pequeños, puede encontrarse con este problema. Por último, también estará limitado por la cantidad de direcciones IP en las subredes que utilizó para el clúster EKS. Por ejemplo, si su clúster se creó usando / 24 subredes en 3 zonas, estaría limitado a alrededor de 750 ips totales en su clúster (dependiendo de qué más sea su VPC), creando un posible cuello de botella en el futuro que será difícil para arreglar si de repente te quedas sin direcciones IP mientras escalas.

Dejando a un lado las consideraciones de red, en realidad es bastante fácil realizar las tareas de mantenimiento más comunes. Puede agregar workers aumentando el tamaño de su AutoScaling Group, reemplazando workers usando kubectl drain y luego terminando la instancia EC2, y realice la mayoría de las actualizaciones con poca interrupción en el clúster.



## Administrar un clúster de Kubernetes con KOPS

Su experiencia en la administración de un clúster de Kops dependerá en gran medida de cómo y cuándo necesite escalar, y de qué otras herramientas use para administrar los recursos de AWS. 

He gestionado un clúster de producción en Kops durante casi 2 años, y he tenido que pasar por importantes actualizaciones de Kubernetes, cambiar los tipos de nodos de workers y reemplazar los nodos de workers muertos en varias ocasiones.

Lo que aprendí al usar kops es que kops es realmente genial para crear un clúster rápidamente, pero solo está bien para administrarlo más tarde. 

Un punto débil es que debe hacer mucho trabajo de base para actualizar y reemplazar los nodos maestros para las nuevas versiones de Kubernetes. Cuando se descubrió la vulnerabilidad CVE-2018-1002105 en 2018, me encontré actualizando varias versiones principales de Kubernetes en menos de un día.

Resultó mucho más fácil crear un nuevo clúster en una nueva VPC con kops que actualizar los nodos maestro y de datos uno por uno para múltiples versiones de Kubernetes. 

He realizado cambios importantes en el clúster de producción varias veces usando este método sin ninguna interrupción del servicio, y lo recomendaría en lugar de usar la edición Kops. 

Tengo un poco de configuración separada en terraform para administrar nuestra conexión de emparejamiento primaria ELB y VPC para hacer posibles estos reemplazos de clúster, pero este método proporciona más tranquilidad de que no puedo cometer un error o romper alguna funcionalidad en una nueva versión de Kubernetes. 

También he notado en general que kops está un poco más atrás en las versiones de Kubernetes que el equipo de EKS, lo que se convertirá en una mayor responsabilidad cuando se encuentre la próxima vulnerabilidad importante.

Para las tareas cotidianas de agregar, reemplazar y actualizar nodos de trabajo, kops es muy similar a EKS. AWS está haciendo la mayor parte del trabajo pesado con AutoScaling Groups en ambos casos, y puede usar el mismo proceso descrito en esta publicación de blog para mantener la estabilidad del clúster mientras realiza cambios en los nodos de trabajo.

## Ganador EKS

El mantenimiento típico del clúster es muy similar con EKS y kops. Esto tiene sentido dado que la mayoría de las veces trabajará con los nodos de trabajo, y se gestionan de manera muy similar en ambas soluciones. Cuando se trata de actualizar la versión de Kubernetes, descubrí que EKS es mucho más fácil de trabajar que kops porque AWS maneja las partes difíciles de la actualización por usted. Deben tenerse en cuenta las preocupaciones de redes con EKS, especialmente al crear su clúster. Solo asegúrese de estar utilizando tipos de instancias y tamaños de subred en los que su clúster pueda crecer fácilmente.

# Seguridad en Kubernetes

![](https://i.imgur.com/CnDHcy2.png)

La seguridad debería ser una preocupación principal para todos los administradores de Kubernetes. A medida que el ecosistema de Kubernetes madure, se encontrarán más vulnerabilidades. 

La velocidad a la que encontramos nuevos problemas de seguridad con Kubernetes está aumentando , y este problema no puede ser ignorado. 

En esta evaluación de seguridad de EKS y KOPS, pondremos el foco en 3 áreas:

¿Quién es responsable de la seguridad?
¿Qué tan fácil es aplicar parches de seguridad?
El nivel de seguridad predeterminado que ofrece cada solución

## Asegurar un clúster de Kubernetes con EKS

EKS se beneficia del modelo de responsabilidad compartida de Amazon EKS, lo que significa que no está solo para asegurarse de que el plano de control de su clúster Kubernetes sea seguro. Esto es ideal para Kubernetes porque se beneficiará de la experiencia en seguridad de AWS en una plataforma que todavía es relativamente nueva. También obtiene el beneficio del soporte de AWS para EKS si tiene problemas con el propio plano de control.

En la sección anterior, cubrí lo fácil que es aplicar las actualizaciones de Kubernetes en EKS. Este es otro gran punto para EKS ya que las actualizaciones de seguridad pueden ser urgentes y no desea cometer errores. El equipo de Amazon EKS está buscando activamente problemas de seguridad y probablemente tendrá la próxima versión parcheada de Kubernetes lista muy rápidamente cuando se descubra la próxima vulnerabilidad.

De forma predeterminada, los clústeres de EKS se configuran con acceso limitado de administrador a través de IAM. La administración de permisos de clúster con IAM es más intuitiva para muchos usuarios de AWS, ya que también están usando IAM para otros servicios de AWS. También es relativamente fácil configurar EKS con volúmenes raíz encriptados y redes privadas. Como su cuenta de AWS no tiene acceso de raíz a los nodos maestros para su clúster, tiene una capa adicional de protección. En otras configuraciones, sería fácil abrir accidentalmente sus nodos maestros al acceso SSH desde Internet público, pero con EKS ni siquiera es posible.

## Asegurar un cluster de Kubernetes con KOPS

Como kops tiene un alcance limitado para administrar solo la infraestructura necesaria para ejecutar Kubernetes, la seguridad de su clúster depende casi exclusivamente de usted. Los clústeres de Kops aún se benefician del Modelo de responsabilidad compartida de Amazon en lo que respecta a EC2 y otros servicios, pero sin el beneficio de experiencia adicional en seguridad o soporte con el propio avión de control de Kubernetes. Por otro lado, la comunidad kops es muy activa en el canal Slack #kops-users y probablemente obtendrá una respuesta decente en la mayoría de las preguntas sobre kops allí.

Las actualizaciones con kops no son difíciles, pero tampoco son simples. La actualización de las principales versiones de Kubernetes implica muchos pasos manuales para actualizar los maestros y los nodos, pero AutoScaling todavía hace la mayor parte del trabajo. Kops tiende a retrasarse un poco en el soporte para las nuevas versiones de Kubernetes. Esto no significa que no pueda usar versiones más nuevas, pero no se garantiza que la herramienta kops funcione con las versiones más recientes.

Los clústeres de Kubernetes creados con kops se configuran de manera muy similar a EKS. Las redes privadas, los volúmenes raíz encriptados y los controles de grupo de seguridad se incluyen en la mayoría de los clústeres básicos de Kops. Como tiene control sobre los nodos maestros, también puede aumentar aún más la seguridad allí utilizando cualquier herramienta a su disposición. También puede configurar la autenticación IAM similar a EKS, pero el método de autorización predeterminado para un administrador de clúster incluye un usuario con una contraseña y certificados.

