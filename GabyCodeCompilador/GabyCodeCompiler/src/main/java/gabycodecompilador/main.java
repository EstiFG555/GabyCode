/*
 * Click nbfs://nbhost/SystemFileSystem/Templates/Licenses/license-default.txt to change this license
 */
package gabycodecompilador;

import gabycodecompiler.escritor.EscritorBytecode;
import gabycodecompiler.generador.GeneradorBytecode;
import gabycodecompiler.generador.Instruccion;
import gabycodecompiler.lector.LectorJson;
import gabycodecompiler.modelo.Grafo;
import gabycodecompiler.modelo.Nodo;
import gabycodecompiler.semantico.OrdenadorTopologico;
import java.io.File;
import java.util.List;

/**
 *
 * @author facu
 */

/**

Familia Instrucción (OpCode) Argumentos esperados Descripción 

Memoria y Pila 
       
PUSH_LITERAL [Valor] 
Empuja un valor crudo (ej. 10, "Hola") a la cima de la pila. 

LOAD_VAR [Nombre_Variable] 
Lee el valor de una variable de memoria y lo empuja a la pila. 

STORE_VAR [Nombre_Variable] 
Saca el último valor de la pila y lo guarda en la variable. 

Matemáticas y Lógicas

Operaciones OP_ADD, OP_SUB 
Ninguno Saca 2 valores de la pila, los suma/resta y empuja el resultado. 

OP_MUL, OP_DIV 
Ninguno Saca 2 valores de la pila, los multiplica/divide y empuja. 

OP_AND, OP_OR 
Ninguno Saca 2 valores booleanos, evalúa lógicamente y empuja. 

OP_CMP_EQ 
Ninguno Compara si los últimos 2 valores de la pila son iguales. 

OP_CMP_LT, OP_GT 
Ninguno Compara Menor Que (LT) o Mayor Que (GT). 

Control de Flujo 
JUMP [Offset_Bytes] 
Salto incondicional. 
Mueve el puntero de ejecución X bytes. 

JUMP_IF_FALSE [Offset_Bytes] 
Saca un booleano de la pila. Si es False, salta X bytes. 

Host (Dominio) 
CALL_HOST [Nombre_Accion] 
Ejecuta código nativo del motor de Godot (La Despensa). 

Terminación HALT Ninguno Finaliza la ejecución del programa actual.

 */
public class main {

    public static void main(String[] args) {

        // 1. Validar que se pasen las dos rutas requeridas
        if (args.length < 2) {
            System.err.println("Error: Faltan argumentos de línea de comandos.");
            System.out.println("Uso correcto:");
            System.out.println("java -jar CompiladorGabyCode.jar <ruta_archivo_json> <ruta_archivo_bytecode>");
            return;
        }

        String rutaEntradaJson = args[0];
        String rutaSalidaBytecode = args[1];

        System.out.println("-> Archivo de entrada (JSON):   " + rutaEntradaJson);
        System.out.println("-> Archivo de salida (Bytecode): " + rutaSalidaBytecode);
        System.out.println("------------------------------------------");

        // 2. Verificar que el archivo JSON de entrada exista
        File archivoJson = new File(rutaEntradaJson);
        if (!archivoJson.exists()) {
            System.err.println("Error: El archivo de entrada no existe en la ruta especificada: " + rutaEntradaJson);
            return;
        }

        try {
            System.out.println("\n[1/4] Leyendo archivo JSON y cargando el Grafo...\n");

            Grafo grafo = LectorJson.leerGrafo(rutaEntradaJson);

            if (grafo != null && grafo.getNodos() != null) {
                System.out.println("Grafo cargado exitosamente. Nodos encontrados: " + grafo.getNodos().size());
                for (Nodo nodo : grafo.getNodos()) {
                    System.out.println(" - Nodo ID: " + nodo.getId() + " | Tipo: " + nodo.getTipo());
                }
            } else {
                System.err.println("Error: El archivo JSON se leyó pero no se pudieron mapear los nodos.");
            }

            System.out.println("\n[2/4] Validando conexiones y ordenando flujo...\n");
            List<Nodo> nodosOrdenados = OrdenadorTopologico.ordenar(grafo);
            
            System.out.println("-> Secuencia de ejecucion ordenada:");
            for(int i = 0; i < nodosOrdenados.size(); i++){
                Nodo n = nodosOrdenados.get(i);
                System.out.println(" " + (i + 1) + ". Nodo ID " + + n.getId() + " [" + n.getTipo() + " -> " + n.getOperacion() + "]");
            }

            System.out.println("\n[3/4] Generando lista de instrucciones Bytecode...\n");
            List<Instruccion> instrucciones = GeneradorBytecode.generar(nodosOrdenados);

            System.out.println("-> Intrucciones generadas (" + instrucciones.size() + "):");
            for(int i=0; i< instrucciones.size(); i++){
                System.out.println(" {" + String.format("%02d", i) + "] " + instrucciones.get(i).getCodigoOperacion() + " " + instrucciones.get(i).getOperando());
            }
            
            // --- FASE 4: Escritura del archivo de salida ---
            System.out.println("\n[4/4] Guardando resultado en el archivo de salida...\n");
            EscritorBytecode.escribir(instrucciones, rutaSalidaBytecode);

            System.out.println("------------------------------------------");
            System.out.println("¡Proceso completado con éxito!");

        } catch (Exception e) {
            System.err.println("Error crítico durante la compilación: " + e.getMessage());
            e.printStackTrace();
        }
    }
}
