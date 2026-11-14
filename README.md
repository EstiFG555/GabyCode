<div align="center">

<img width="1703" height="1012" alt="GabyCode" src="https://github.com/user-attachments/assets/302b5424-e2c6-4fb7-bc44-72aee24452cb" />

  # GabyCode  

  ## Plataforma de Compilación Visual y  Máquina Virtual de Pila para la Automatización de Reglas de Negocio en Entornos de Retail

<img width="1915" height="936" alt="{9C831497-2934-4072-8C60-F3C17914F453}" src="https://github.com/user-attachments/assets/710178b0-5619-4d9d-b768-b91fa512dd68" />

<img width="1920" height="989" alt="{D1812BFC-1970-47DC-9D8D-726D5D974D1B}" src="https://github.com/user-attachments/assets/a7d165ce-2ab7-486c-ba01-a8b64ecb931c" />

</div>

<div aling="left">
  
### Guía Rapida

  - #### Como Instalar

##### Pre-Requisitos

Un pre-requisito para poder ejecutar correctamente toda la plataforma es el tener java instalado en su computadora, de preferencia recomendamos java 26 para el cual proporcionamos el siguiente link para que pueda descargarlo e instalarlo y así no tener problema ejecutando las aplicaciones desarrolladas en ese lenguaje.

Descargar Java 26: [Link a la página](https://www.oracle.com/java/technologies/javase/jdk26-archive-downloads.html)

##### Instalación de la plataforma

En caso no posea el ".rar" conteniendo todas las partes de la plataforma puede obtenerlas a travez del siguiente link: [Obtener rar](https://drive.google.com/drive/folders/1loRUMhCi8QVhOQVt2q1I-mdm_avvlk7M?usp=sharing)

Una vez obtenido el rar correspondiente a su plataforma, lo siguiente que debe hacer es simplemente descomprimirlo en una carpeta vacia. Esto le generará una carpeta llamada "GabyCode" la cual contendrá 3 carpetas correspondientes a las distintas partes/modulos de la plataforma:

  * compilador-gráfico
  * GabyCodeCompilador
  * JVMGabi

Cada una de estas carpetas contienen tanto el código fuente como el ejecutable final de cada parte que es lo que realmente le interesa.

##### Obtención de los ejecutables finales

  Con toda la plataforma ya descomprimida del rar y en su pc lo siguiente que queda es localizar y facilitar el acceso a los ejecutables.

  Primero iniciaremos con el ejecutable del IDE de programación, para acceder al ejecutable simplemente abra la carpeta de "compilador-gráfico" dentro encontrará varios archivos, pero el de importancia es el que tiene de nombre "IDE_GabyCode" el tipo del archivo dependerá de su sistema operativo (x86_64 si usa linux). Opcionalmente también se provee un acceso directo apenas se descomprime la carpeta.

  Segundo tendremos que localizar el ejecutable del simulador de la Despensa que incluye la Maquina Virtual y también se encarga de vincular la pipeline entre los JSON generados por la IDE con el compilador y el propio entorno de ejecución de la VM. Para acceder a este archivo ejecutable simplemente abra la carpeta JVMGabi y dentro encontrará un archivo con nombre "JVMGabi-2.0 Linux Ready" el cual al ejecutar desplegará todo el entorno de la simulación.
      
  - #### Orden de Ejecución

  A la hora de intentar escribir sus propios programas y probarlos el orden de ejecución necesario para lograr esto con exito es el siguiente:

  Ejecutar el IDE, escribir su programa y compilarlo.

  Luego ejecutar JVMGabi, dentro del programa presionar el botón de compilar JSON desde Godot Ahora. Una vez compilado correctamente para poder ver como se ejecuta solo es necesario presionar el botón que dispara el evento que su código está esperando para funcionar, esto generará un mensaje en consola con la ejecución correcta o no del programa.

  - #### Como Ejecutar Pruebas

      - ##### Caso N°1. Cierre y Registro de Venta.

      Para lograr ejecutar correctamente el primer caso lo prueba lo que hay que hacer es lo siguiente:

      1. Ejecutar el IDE.
      2. Darle al boton de "Cargar Programa JSON...".
      3. Una vez en la ventana de exploración de archivos, abrimos la carperta de "programas".
      4. Dentro de la carpeta encontraremos el archivo "Cierre_y_Finalización_de_Venta.json", lo seleccionamos y abrimos.
      5. Una vez abierto el código y siendo visible en el IDE, presionamos el botón de compilar o tocamos la tecla Enter.
      6. Con el código ya compilado lo siguiente en la lista es ejecutar el entorno simulado de ejecución de JVMGabi.
      7. Una vez dentro de JVMGabi presionamos el botón de "Compilar JSON desde Godot Ahora", el cual compilará a bytecode el JSON que generamos y subscribirá a el evento correspondiente el ByteCode generado, de modo que cuando el evento se dispare el código que generamos será ejecutado.
      8. Por ultimo para ejecutar este caso de prueba en particular disparamos el evento de cierre de vente presionando el botón "Disparar Finalizar Venta con Carrito Seleccionado", esto hará que el código se ejecute, y debería poder verse en la consola del programa los logs y la correcta ejecución del mismo.

      - ##### Caso N°2. Se acerca navidad.

      1. Ejecutar el IDE.
      2. Darle al boton de "Cargar Programa JSON...".
      3. Una vez en la ventana de exploración de archivos, abrimos la carperta de "programas".
      4. Dentro de la carpeta encontraremos el archivo "Rutina_Navidad.json", lo seleccionamos y abrimos.
      5. Una vez abierto el código y siendo visible en el IDE, presionamos el botón de compilar o tocamos la tecla Enter.
      6. Con el código ya compilado lo siguiente en la lista es ejecutar el entorno simulado de ejecución de JVMGabi.
      7. Una vez dentro de JVMGabi presionamos el botón de "Compilar JSON desde Godot Ahora", el cual compilará a bytecode el JSON que generamos y subscribirá a el evento correspondiente el ByteCode generado, de modo que cuando el evento se dispare el código que generamos será ejecutado.
      8. Por ultimo para ejecutar este caso de prueba en particular disparamos el evento de cierre de vente presionando el botón "Disparar Evento Navidad con Lista de ID's", esto hará que el código se ejecute, y debería poder verse en la consola del programa los logs y la correcta ejecución del mismo.

      - ##### Caso N°3. Aplicar descuento a producto escaneado.

      1. Ejecutar el IDE.
      2. Darle al boton de "Cargar Programa JSON...".
      3. Una vez en la ventana de exploración de archivos, abrimos la carperta de "programas".
      4. Dentro de la carpeta encontraremos el archivo "Ejemplo_Aplicar_descuento_especifico.json", lo seleccionamos y abrimos.
      5. Una vez abierto el código y siendo visible en el IDE, presionamos el botón de compilar o tocamos la tecla Enter.
      6. Con el código ya compilado lo siguiente en la lista es ejecutar el entorno simulado de ejecución de JVMGabi.
      7. Una vez dentro de JVMGabi presionamos el botón de "Compilar JSON desde Godot Ahora", el cual compilará a bytecode el JSON que generamos y subscribirá a el evento correspondiente el ByteCode generado, de modo que cuando el evento se dispare el código que generamos será ejecutado.
      8. Por ultimo para ejecutar este caso de prueba en particular disparamos el evento de cierre de vente presionando el botón "Disparar Escaneo con Producto Elegido", esto hará que el código se ejecute, y debería poder verse en la consola del programa los logs y la correcta ejecución del mismo.

      - ##### Caso N°4. Aplicar descuento potencial.

      1. Ejecutar el IDE.
      2. Darle al boton de "Cargar Programa JSON...".
      3. Una vez en la ventana de exploración de archivos, abrimos la carperta de "programas".
      4. Dentro de la carpeta encontraremos el archivo "Descuento_Potencial.json", lo seleccionamos y abrimos.
      5. Una vez abierto el código y siendo visible en el IDE, presionamos el botón de compilar o tocamos la tecla Enter.
      6. Con el código ya compilado lo siguiente en la lista es ejecutar el entorno simulado de ejecución de JVMGabi.
      7. Una vez dentro de JVMGabi presionamos el botón de "Compilar JSON desde Godot Ahora", el cual compilará a bytecode el JSON que generamos y subscribirá a el evento correspondiente el ByteCode generado, de modo que cuando el evento se dispare el código que generamos será ejecutado.
      8. Por ultimo para ejecutar este caso de prueba en particular disparamos el evento de cierre de vente presionando el botón "Disparar Escaneo con Producto Elegido", esto hará que el código se ejecute, y debería poder verse en la consola del programa los logs y la correcta ejecución del mismo.

  - #### Consideraciones y pruebas de error

    Como podrá haber observado luego de ejecutar todos los casos de prueba planificados que utilizan cada uno los diversos elementos propios del lenguaje de programación desarrollado probando que todas sus funcionalidades planificadas inicaialmente han sido implementadas de manera funcional. Una cuestión que podría interesarle es leer la sección de Limitaciones dentro del trabajo de investigación adjunto para poder ver que no puede hacer la plataforma y el lenguaje, ahora si aún así le interesa puede intentar jugar con los limites de la implementación actual y testear los pequeños controles de errores que existen actualmente, y principalmente en JVMGabi y la simulación del entorno de ejecución, esto está provisto por medio de los campos editables, dentro del programa que simulador, con los cuales puede llegar a introducir ID's no existentes, productos con caracteristicas especiales, cambiar los elementos seleccionados para cerrar una compra, etc. El punto final de esto es que pueda ver la existencia de un control de errores a tiempo de ejecución con respecto a llamadas a funciones con parametros insuficientes, fallas en la vinculación de variables traidas al ambito local por los eventos (Esto debido al como solo existe un unico archivo con ByteCode en todo momento), y parametros nulos.

    Si bien la mayoría gestión de errores se encuentra principalmente concentrado dentro de la parte más dinámica de la plataforma como lo es la VM y el entorno de ejecución, también existen pequeños controles de errores dentro de la IDE que permite escribir el código que será posteriormente ejecutado como lo es el mecanismo de relleno con 0 de valores nulos para prevenir fallos de compilación, esto obviamente derivado con la interactividad que permite la introducción de valores literales ingresados por teclado, lo cuales son mucho más dificiles de controlar de manera activa (siguiendo nuestro paradigma de correct by construction) dado que empeoran drasticamente la facilidad de uso del usuario. Un mecanismo más atado a esta desición de diseño es la de truncar los valores a su maxima representación numerica soportada por los tipos de datos primitivos de Godot, esto debido a que el campo de introducción de los literales del usuario es un campo que devuelve un string el cual luego debe ser casteado a su correcta representación numerica, este metodo trae consigo el hecho de permitir ingresar números más grandes que los soportados, requiriendo así de este mecanismo para la prevención de errores de compilación.
    
</div>
