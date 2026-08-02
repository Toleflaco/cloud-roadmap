# ADR-A1: VPC custom en lugar de la default VPC

**Estado:** Aceptada
**Fecha:** 2026-08-02
**Módulo:** AWS (Roadmap Post-Git/Bash)

## Contexto

AWS provee en cada región una "default VPC" ya creada, con subnets, Internet Gateway y route tables configurados de fábrica, pensada para poder lanzar recursos de inmediato sin configurar red. Al empezar a construir la infraestructura del proyecto `task-manager` en AWS hay que decidir si apoyarse en esa default VPC o crear una VPC propia (custom).

El proyecto necesita una separación clara entre recursos expuestos a internet (un futuro balanceador de carga) y recursos que nunca deben ser alcanzables desde internet (base de datos con datos de clientes). El mercado objetivo (banca, consultoras) exige esta separación como estándar.

## Decisión

Crear una **VPC custom** (`task-manage-vpc`, CIDR `10.0.0.0/16`) con un diseño explícito de subnets públicas y privadas repartidas en dos zonas de disponibilidad, y no usar la default VPC para el proyecto. La default VPC se deja intacta pero sin uso.

## Justificación

La default VPC tiene **todas sus subnets configuradas como públicas**: cada una tiene ruta a internet a través del Internet Gateway. Está diseñada bajo el criterio de "arrancar rápido", no "arrancar seguro". Colocar una base de datos en ella la expondría a internet, lo que es inaceptable para datos sensibles.

Una VPC custom permite:

- Definir qué subnets son públicas (ruta `0.0.0.0/0` al IGW) y cuáles privadas (sin esa ruta), materializando la defensa en capas.
- Controlar el rango de direcciones y su segmentación por zona de disponibilidad.
- Reproducir el patrón estándar de arquitectura en la nube que se espera en un entorno profesional, y que además es requisito en banca por motivos de compliance.

El coste de la decisión es bajo: crear la VPC y sus componentes de red (subnets, IGW, route tables) no genera cargo. El único componente de pago (NAT Gateway) se deja deshabilitado.

## Consecuencias

**Positivas.**
- La base de datos y la aplicación pueden ubicarse en subnets privadas, aisladas de internet por diseño.
- La arquitectura es defendible en entrevista y alineada con las prácticas del mercado objetivo.
- Sirve de base limpia para el resto del módulo (EC2, RDS, ECS) y para su posterior reescritura en Terraform.

**Negativas / a tener en cuenta.**
- Requiere configurar la red explícitamente en lugar de heredarla. En esta sesión se usó el asistente "VPC and more" para reducir el esfuerzo manual, con la intención de reescribir la definición en Terraform en la Sesión 5.
- La coexistencia de la default VPC y la custom obliga a filtrar por VPC en las vistas de la consola para no confundir recursos.

## Alternativas consideradas

- **Usar la default VPC.** Descartada: subnets todas públicas, inadecuada para datos sensibles y no representativa de un entorno profesional.
- **VPC custom creada pieza a pieza ("VPC only").** Válida y más didáctica en el "cómo manual", pero descartada por ahora porque la definición manual se hará de forma versionada en Terraform (Sesión 5); el asistente cubre el objetivo de entender los componentes con menor coste de tiempo.
