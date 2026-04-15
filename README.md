# Proyecto Final: Generador de Paquetes Ethernet en Verilog
Este repositorio contiene los archivos fuente en Verilog para el proyecto de la materia de **Redes Computacionales**. El objetivo es diseñar e implementar un generador de tráfico de red desde cero en hardware, utilizando una FPGA **Arty A7 100T** para enviar mensajes UDP ("HELLO") capturables en una PC mediante **Wireshark**.

## 🚀 Objetivo del Proyecto
A diferencia de un sistema basado en software, aquí no contamos con un Sistema Operativo que gestione la pila de protocolos. Cada bit de las cabeceras de red debe ser construido manualmente en Verilog y enviado al chip físico (PHY) a través de la interfaz **MII (Media Independent Interface)**.
